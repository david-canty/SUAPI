import Vapor
import Fluent
import Authentication
import Mailgun
import OneSignal

enum PaymentMethod: String {
    case bacs = "bacs"
    case schoolBill = "schoolBill"
    case card = "card"
}

enum OrderStatus: String {
    case ordered = "Ordered"
    case awaitingStock = "Awaiting Stock"
    case readyForCollection = "Ready for Collection"
    case awaitingPayment = "Awaiting Payment"
    case complete = "Complete"
    case cancellationRequested = "Cancellation Requested"
    case cancelled = "Cancelled"
    case returnRequested = "Return Requested"
    case returned = "Returned"
}

struct SUOrderController: RouteCollection {

    func boot(router: Router) throws {

        // Orders
        let ordersRoutes = router.grouped("api", "orders")
        ordersRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in

            jwtProtectedGroup.post(use: createHandler)
            jwtProtectedGroup.post(SUOrder.parameter, "cancel", use: cancelOrderHandler)
        }
        
        let ordersAuthSessionRoutes = ordersRoutes.grouped(SUUser.authSessionsMiddleware())
        let ordersRedirectProtectedGroup = ordersAuthSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        ordersRedirectProtectedGroup.patch(SUOrder.parameter, "status", use: updateOrderStatusHandler)
        ordersRedirectProtectedGroup.delete(SUOrder.parameter, use: deleteOrderHandler)
        
        // Order Items
        let orderItemsRoutes = router.grouped("api", "order-items")
        orderItemsRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in
            
            jwtProtectedGroup.post(OrderItemCancelReturnData.self, at: SUOrderItem.parameter, "cancel-return", use: cancelReturnOrderItemHandler)
        }
        
        let orderItemsAuthSessionRoutes = orderItemsRoutes.grouped(SUUser.authSessionsMiddleware())
        let orderItemsRedirectProtectedGroup = orderItemsAuthSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        orderItemsRedirectProtectedGroup.patch(SUOrderItem.parameter, "quantity", use: updateOrderItemQuantityHandler)
        orderItemsRedirectProtectedGroup.delete(SUOrderItem.parameter, use: deleteOrderItemHandler)
        
    }

    // Orders
    func createHandler(_ req: Request) throws -> Future<SUOrderInfo> {

        return try req.content.decode(SUOrderPostData.self).flatMap(to: SUOrderInfo.self) { orderData in
            
            guard let customerId = UUID(uuidString: orderData.customerId) else {
                throw Abort(.badRequest, reason: "Customer id missing from order post data")
            }
            
            return SUCustomer.find(customerId, on: req).flatMap(to: SUOrderInfo.self) { customer in
                
                guard let customer = customer else {
                    throw Abort(.badRequest, reason: "Customer not found for order")
                }
                
                return req.transaction(on: .mysql) { conn in
                    
                    let order = SUOrder(customerID: customer.id!,
                                        orderDate: Date(),
                                        orderStatus: OrderStatus.ordered.rawValue,
                                        paymentMethod: orderData.paymentMethod,
                                        chargeId: orderData.chargeId)
                    
                    return order.save(on: conn).flatMap(to: SUOrderInfo.self) { order in
                        
                        var orderItemSaveResults: [Future<SUOrderItem>] = []
                        
                        for orderItemData in orderData.orderItems {
                            
                            guard let itemID = UUID(uuidString: orderItemData.itemID),
                                let sizeID = UUID(uuidString: orderItemData.sizeID) else {
                                    throw Abort(.badRequest, reason: "Invalid order item size id or item id")
                            }
                            
                            let quantity = orderItemData.quantity
                            
                            let orderItem = SUOrderItem(orderID: order.id!, itemID: itemID, sizeID: sizeID, quantity: quantity)
                            
                            orderItemSaveResults.append(orderItem.save(on: conn))
                        }
                        
                        return orderItemSaveResults.flatten(on: conn).map(to: SUOrderInfo.self) { orderItems in
                            
                            return SUOrderInfo(customer: customer, order: order, orderItems: orderItems)
                        }
                    }
                }
            }
        }
    }
    
    func cancelOrderHandler(_ req: Request) throws -> Future<SUOrder> {
        
        return try req.parameters.next(SUOrder.self).flatMap { order in
            
            return try self.sendCancelOrderAdminEmail(forOrder: order, on: req).flatMap { response in
            
                order.orderStatus = OrderStatus.cancellationRequested.rawValue
                order.timestamp = Date()
                return order.update(on: req)
            }
        }
    }
    
    func getOrderItemDetails(for orderItems: [SUOrderItem], on req: Request) -> EventLoopFuture<[CancelOrderItemDetails]> {
        
        return orderItems.compactMap { orderItem in
            
            return SUShopItem.find(orderItem.itemID, on: req).flatMap(to: CancelOrderItemDetails.self) { item in
                
                return SUSize.find(orderItem.sizeID, on: req).map(to: CancelOrderItemDetails.self) { size in
                    
                    let quantity = orderItem.quantity
                    
                    let orderItemTotal = item!.itemPrice * Double(quantity)
                    let formatter = NumberFormatter()
                    formatter.numberStyle = .currency
                    formatter.currencySymbol = "£"
                    let formattedTotal = formatter.string(from: orderItemTotal as NSNumber)
                    
                    return CancelOrderItemDetails(item: item!, size: size!, quantity: quantity, formattedTotal: formattedTotal!)
                }
            }
        }.flatten(on: req)
    }

    func getTotal(forOrder order: SUOrder, on req: Request) throws -> EventLoopFuture<Double> {
        
        return try order.orderItems.query(on: req).all().flatMap(to: Double.self) { orderItems in
            
            return orderItems.compactMap { orderItem in
                
                return SUShopItem.find(orderItem.itemID, on: req).map(to: Double.self) { item in
                    
                    return item!.itemPrice * Double(orderItem.quantity)
                }
                
                }.map(to: Double.self, on: req) { orderItemTotals in
                    
                    return orderItemTotals.reduce(0.0, +)
            }
        }
    }
    
    func sendCancelOrderAdminEmail(forOrder order: SUOrder, on req: Request) throws -> Future<Response> {
        
        return try flatMap(order.customer.get(on: req), order.orderItems.query(on: req).all()) { customer, orderItems in
            
            self.getOrderItemDetails(for: orderItems, on: req).flatMap { orderItemDetails in
                
                try self.getTotal(forOrder: order, on: req).flatMap { orderTotal in
                    
                    let formatter = NumberFormatter()
                    formatter.numberStyle = .currency
                    formatter.currencySymbol = "£"
                    let formattedOrderTotal = formatter.string(from: orderTotal as NSNumber)
                    
                    let itemCount = orderItems.reduce(0) { return $0 + Int($1.quantity) }
                    
                    let context = CancelOrderEmailContext(order: order, customer: customer, orderItemDetails: orderItemDetails, itemCount: itemCount, formattedOrderTotal: formattedOrderTotal!)
                    
                    return try req.view().render("Emails/cancelOrderEmail", context).flatMap { view in
                        
                        let content = String(data: view.data, encoding: .utf8)
                        
                        let message = Mailgun.Message(from: customer.email,
                                                      to: "david.canty@icloud.com",
                                                      subject: "RHS Uniform - Cancel Order",
                                                      text: "",
                                                      html: content)
                        
                        let mailgun = try req.make(Mailgun.self)
                        return try mailgun.send(message, on: req)
                    }
                }
            }
        }
    }
                
    func updateOrderStatusHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self, req.parameters.next(SUOrder.self), req.content.decode(OrderStatusData.self)) { order, orderStatusData in
            
            guard let newOrderStatus = OrderStatus(rawValue: orderStatusData.orderStatus) else {
                throw Abort(.badRequest, reason: "Invalid order status")
            }
            
            if order.orderStatus != newOrderStatus.rawValue {
                
                order.timestamp = Date()
                order.orderStatus = newOrderStatus.rawValue
                
                return order.update(on: req).flatMap { order in
                    
                    let paddedOrderId = String(format: "%06d", try order.requireID())
                    
                    switch newOrderStatus {
                        
                    case OrderStatus.ordered:
                        
                        return req.future(HTTPStatus.ok)
                        
                    case OrderStatus.awaitingStock:
                        
                        let messageTitle = "Order - Awaiting Stock"
                        let messageBody = "Order no \(paddedOrderId) has been received and is awaiting stock."
                        return try self.sendAPNS(withTitle: messageTitle, body: messageBody, forOrder: order, on: req)
                        
                    case OrderStatus.readyForCollection:
                        
                        let messageTitle = "Order - Ready for Collection"
                        let messageBody = "Order no \(paddedOrderId) is ready for collection."
                        return try self.sendAPNS(withTitle: messageTitle, body: messageBody, forOrder: order, on: req)
                        
                    case OrderStatus.awaitingPayment:
                        
                        let messageTitle = "Order - Awaiting Payment"
                        let messageBody = "Order no \(paddedOrderId) is awaiting payment."
                        return try self.sendAPNS(withTitle: messageTitle, body: messageBody, forOrder: order, on: req)
                        
                    case OrderStatus.complete:
                        
                        let messageTitle = "Order - Complete"
                        let messageBody = "Order no \(paddedOrderId) is complete."
                        return try self.sendAPNS(withTitle: messageTitle, body: messageBody, forOrder: order, on: req)
                        
                    case OrderStatus.cancellationRequested:
                        
                        return req.future(HTTPStatus.ok)
                        
                    case OrderStatus.cancelled:
                        
                        let messageTitle = "Order Cancelled"
                        let messageBody = "Order no \(paddedOrderId) has been cancelled."
                        return try self.sendAPNS(withTitle: messageTitle, body: messageBody, forOrder: order, on: req)
                        
                    case OrderStatus.returnRequested:
                        
                        return req.future(HTTPStatus.ok)
                        
                    case OrderStatus.returned:
                        
                        let messageTitle = "Order Returned"
                        let messageBody = "Order no \(paddedOrderId) has been returned."
                        return try self.sendAPNS(withTitle: messageTitle, body: messageBody, forOrder: order, on: req)
                    }
                }
                
            } else {
            
                return req.future(HTTPStatus.ok)
            }
        }
    }
    
    func sendAPNS(withTitle title: String, body: String, forOrder order: SUOrder, on req: Request) throws -> Future<HTTPStatus> {
        
        return order.customer.get(on: req).flatMap { customer in
            
            if let apnsToken = customer.apnsDeviceToken {
                
                guard let oneSignalAPIKey = Environment.get("ONESIGNAL_API_KEY") else { throw Abort(.internalServerError, reason: "Failed to get ONESIGNAL_API_KEY") }
                guard let oneSignalAppId = Environment.get("ONESIGNAL_APP_ID") else { throw Abort(.internalServerError, reason: "Failed to get ONESIGNAL_APP_ID") }
                
                var notification = OneSignalNotification(title: title, subtitle: nil, body: body, users: nil, iosDeviceTokens: [apnsToken])
                
                notification.setContentAvailable(true)
                //message["orderId"] = String(order.requireID())
                
                let app = OneSignalApp(apiKey: oneSignalAPIKey, appId: oneSignalAppId)
                
                return try OneSignal.makeService(for: req).send(notification: notification, toApp: app).transform(to: HTTPStatus.ok)
                
            } else {
                
                return req.future(HTTPStatus.badRequest)
            }
            
        }.catchFlatMap { error in
                
            throw Abort(.internalServerError, reason: "Failed to get customer for order: \(error.localizedDescription)")
        }
    }
    
    func deleteOrderHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try req.parameters.next(SUOrder.self).flatMap(to: HTTPStatus.self) { order in
            
            return order.delete(on: req).transform(to: HTTPStatus.noContent)
        }
    }
    
    // Order Items
    func updateOrderItemQuantityHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self, req.parameters.next(SUOrderItem.self), req.content.decode(OrderItemQuantityData.self)) { orderItem, orderItemQuantityData in
            
            orderItem.quantity = orderItemQuantityData.quantity
            
            return orderItem.update(on: req).transform(to: HTTPStatus.ok)
        }
    }
    
    func cancelReturnOrderItemHandler(_ req: Request, content: OrderItemCancelReturnData) throws -> Future<SUOrderItem> {
        
        return try req.parameters.next(SUOrderItem.self).flatMap { orderItem in
            
            let action = content.action
            let quantity = content.quantity
            
            return orderItem.order.get(on: req).flatMap { order in
                
                return try self.sendOrderItemCancelReturnAdminEmail(forOrder: order, andOrderItem: orderItem, action: action, quantity: quantity, on: req).flatMap { response in
                    
                    orderItem.orderItemStatus = OrderStatus.cancellationRequested.rawValue
                    return orderItem.update(on: req)
                }
            }
        }
    }
    
    func sendOrderItemCancelReturnAdminEmail(forOrder order: SUOrder, andOrderItem orderItem: SUOrderItem, action: String, quantity: Int, on req: Request) throws -> Future<Response> {
        
        return order.customer.get(on: req).flatMap { customer in
            
            self.getOrderItemDetails(for: [orderItem], on: req).flatMap { orderItemDetails in
                
                let context = OrderItemCancelReturnEmailContext(action: action, order: order, customer: customer, orderItemDetails: orderItemDetails)
                
                return try req.view().render("Emails/cancelReturnOrderItemEmail", context).flatMap { view in
                    
                    let content = String(data: view.data, encoding: .utf8)
                    
                    let subject = "RHS Uniform - " + action.capitalized + " Order Item"
                    
                    let message = Mailgun.Message(from: customer.email,
                                                  to: "david.canty@icloud.com",
                                                  subject: subject,
                                                  text: "",
                                                  html: content)
                    
                    let mailgun = try req.make(Mailgun.self)
                    return try mailgun.send(message, on: req)
                }
            }
        }
    }

    func deleteOrderItemHandler(_ req: Request) throws -> Future<[SUOrderItem]> {

        return try req.parameters.next(SUOrderItem.self).flatMap { orderItem in

            orderItem.order.get(on: req).flatMap { order in

                orderItem.delete(on: req).flatMap {

                    try order.orderItems.query(on: req).all()
                }
            }
        }
    }
    
    // Data structs
    struct SUOrderPostData: Content {
        let customerId: String
        let orderItems: [OrderItemInfo]
        let paymentMethod: String
        let chargeId: String?
    }
    
    struct OrderItemInfo: Codable {
        let itemID: String
        let sizeID: String
        let quantity: Int
    }
    
    struct SUOrderInfo: Content {
        let customer:  SUCustomer
        let order: SUOrder
        let orderItems: [SUOrderItem]
    }
    
    struct CancelOrderEmailContext: Encodable {
        let order: SUOrder
        let customer:  SUCustomer
        let orderItemDetails: [CancelOrderItemDetails]
        let itemCount: Int
        let formattedOrderTotal: String
    }
    
    struct CancelOrderItemDetails: Encodable {
        let item: SUShopItem
        let size: SUSize
        let quantity: Int
        let formattedTotal: String
    }
    
    struct OrderStatusData: Content {
        let orderStatus: String
    }
    
    struct OrderItemQuantityData: Content {
        let quantity: Int
    }
    
    struct OrderItemCancelReturnData: Content {
        let action: String
        let quantity: Int
    }
    
    struct OrderItemCancelReturnEmailContext: Encodable {
        let action: String
        let order: SUOrder
        let customer:  SUCustomer
        let orderItemDetails: [CancelOrderItemDetails]
    }
}
