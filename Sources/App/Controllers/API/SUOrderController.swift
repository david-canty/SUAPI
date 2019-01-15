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

enum OrderStatus: String, CaseIterable {
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

enum CancelReturnItem: String {
    case cancelItem = "cancel"
    case returnItem = "return"
}

struct SUOrderController: RouteCollection {

    func boot(router: Router) throws {

        // Orders
        let ordersRoutes = router.grouped("api", "orders")
        ordersRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in

            jwtProtectedGroup.post(use: createHandler)
            jwtProtectedGroup.get(SUOrder.parameter, use: getOrderHandler)
            jwtProtectedGroup.post(SUOrder.parameter, "cancel", use: cancelOrderHandler)
        }
        
        let ordersAuthSessionRoutes = ordersRoutes.grouped(SUUser.authSessionsMiddleware())
        let ordersRedirectProtectedGroup = ordersAuthSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        ordersRedirectProtectedGroup.patch(OrderStatusData.self, at: SUOrder.parameter, "status", use: updateOrderStatusHandler)
        ordersRedirectProtectedGroup.delete(SUOrder.parameter, use: deleteOrderHandler)
        
        // Order Items
        let orderItemsRoutes = router.grouped("api", "order-items")
        orderItemsRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in
            
            jwtProtectedGroup.get(SUOrderItem.parameter, use: getOrderItemHandler)
            jwtProtectedGroup.post(OrderItemCancelReturnData.self, at: SUOrderItem.parameter, "cancel-return", use: cancelReturnOrderItemHandler)
        }
        
        let orderItemsAuthSessionRoutes = orderItemsRoutes.grouped(SUUser.authSessionsMiddleware())
        let orderItemsRedirectProtectedGroup = orderItemsAuthSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        orderItemsRedirectProtectedGroup.patch(OrderItemQuantityData.self, at: SUOrderItem.parameter, "quantity", use: updateOrderItemQuantityHandler)
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
                            
                            let orderItem = SUOrderItem(orderID: order.id!, itemID: itemID, sizeID: sizeID, quantity: quantity, orderItemStatus: OrderStatus.ordered.rawValue)
                            
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
    
    func getOrderHandler(_ req: Request) throws -> Future<OrderData> {
     
        return try req.parameters.next(SUOrder.self).flatMap { order in
            
            try order.orderItems.query(on: req).all().flatMap { orderItems in
                
                try orderItems.compactMap { orderItem in
                    
                    try SUOrderItemAction.query(on: req).filter(\.orderItemID == orderItem.requireID()).first().map { action in
                        
                        return OrderItemWithAction(orderItem: orderItem, orderItemAction: action)
                    }
                    }.flatten(on: req).map { orderItemsWithActions in
                        
                        return OrderData(order: order, orderItemsWithActions: orderItemsWithActions)
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
                
    func updateOrderStatusHandler(_ req: Request, orderStatusData: OrderStatusData) throws -> Future<HTTPStatus> {
        
        return try req.parameters.next(SUOrder.self).flatMap { order in
            
            guard let newOrderStatus = OrderStatus(rawValue: orderStatusData.orderStatus) else {
                throw Abort(.badRequest, reason: "Invalid order status")
            }
            
            let orderStatus = newOrderStatus.rawValue
            
            if order.orderStatus != orderStatus {
                
                order.timestamp = Date()
                order.orderStatus = orderStatus
                
                return order.update(on: req).flatMap { updatedOrder in
                    
                    try self.updateOrderItems(forOrder: updatedOrder, withStatus: orderStatus, on: req).flatMap { _ in
                     
                        try self.deleteOrderItemActions(forOrder: updatedOrder, on: req).flatMap { _ in
                    
                            return try self.sendAPNSFor(order: updatedOrder, on: req)
                        }
                    }
                }
                
            } else {
            
                return req.future(HTTPStatus.ok)
            }
        }
    }
    
    func updateOrderItems(forOrder order: SUOrder, withStatus status: String, on req: Request) throws -> Future<HTTPStatus> {
    
        guard let orderItemStatus = OrderStatus(rawValue: status) else {
            throw Abort(.badRequest, reason: "Invalid order status")
        }
        
        return try order.orderItems.query(on: req).all().flatMap { orderItems in
            
            return orderItems.map { orderItem -> EventLoopFuture<SUOrderItem> in
                
                orderItem.orderItemStatus =  orderItemStatus.rawValue
                return orderItem.update(on: req)
                
            }.flatten(on: req).transform(to: HTTPStatus.ok)
        }
    }
    
    func sendAPNSFor(order: SUOrder, on req: Request) throws -> Future<HTTPStatus> {
        
        guard let orderStatus = OrderStatus(rawValue: order.orderStatus) else {
            throw Abort(.badRequest, reason: "Invalid order status")
        }
        
        let paddedOrderId = String(format: "%06d", try order.requireID())
        
        switch orderStatus {
            
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
            
            return try self.deleteOrderItemActions(forOrder: order, on: req).flatMap { _ in
                
                let messageTitle = "Order Cancelled"
                let messageBody = "Order no \(paddedOrderId) has been cancelled."
                return try self.sendAPNS(withTitle: messageTitle, body: messageBody, forOrder: order, on: req)
            }
            
        case OrderStatus.returnRequested:
            
            return req.future(HTTPStatus.ok)
            
        case OrderStatus.returned:
            
            return try self.deleteOrderItemActions(forOrder: order, on: req).flatMap { _ in
                
                let messageTitle = "Order Returned"
                let messageBody = "Order no \(paddedOrderId) has been returned."
                return try self.sendAPNS(withTitle: messageTitle, body: messageBody, forOrder: order, on: req)
            }
        }
    }
    
    func sendAPNS(withTitle title: String, body: String, forOrder order: SUOrder, on req: Request) throws -> Future<HTTPStatus> {
        
        return order.customer.get(on: req).flatMap { customer in
            
            if let apnsToken = customer.apnsDeviceToken {
                
                guard let oneSignalAPIKey = Environment.get("ONESIGNAL_API_KEY") else { throw Abort(.internalServerError, reason: "Failed to get ONESIGNAL_API_KEY") }
                guard let oneSignalAppId = Environment.get("ONESIGNAL_APP_ID") else { throw Abort(.internalServerError, reason: "Failed to get ONESIGNAL_APP_ID") }
                
                let orderId = try order.requireID()
            
                var notification = OneSignalNotification(title: title, subtitle: nil, body: body, users: nil, iosDeviceTokens: [apnsToken])
                
                notification.additionalData(key: "orderId", value: String(orderId))
                notification.setContentAvailable(true)
                
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
    
    func deleteOrderItemActions(forOrder order: SUOrder, on req: Request) throws -> Future<HTTPStatus> {
        
        return try order.orderItems.query(on: req).all().flatMap { orderItems in
            
            try orderItems.map { orderItem in
                
                return try self.deleteAction(forOrderItem: orderItem, on: req)
                
            }.flatten(on: req).transform(to: HTTPStatus.ok)
        }
    }
    
    func deleteAction(forOrderItem orderItem: SUOrderItem, on req: Request) throws -> Future<HTTPStatus> {
        
        return try SUOrderItemAction.query(on: req).filter(\.orderItemID == orderItem.requireID()).all().flatMap { actions in
            
            actions.map { action in
                
                return action.delete(on: req)
                
            }.flatten(on: req).transform(to: HTTPStatus.ok)
        }
    }
    
    // Order Items
    func getOrderItemHandler(_ req: Request) throws -> Future<SUOrderItem> {
        
        return try req.parameters.next(SUOrderItem.self)
    }
    
    func updateOrderItemQuantityHandler(_ req: Request,  quantityData: OrderItemQuantityData) throws -> Future<HTTPStatus> {
        
        return try req.parameters.next(SUOrderItem.self).flatMap { orderItem in
            
            orderItem.order.get(on: req).flatMap { order in
                
                try self.sendAPNSFor(forOrder: order, orderItem: orderItem, on: req).flatMap { _ in
                    
                    orderItem.quantity = quantityData.quantity
                    orderItem.orderItemStatus = order.orderStatus
                    
                    return orderItem.update(on: req).flatMap { orderItem in
                        
                        return try self.deleteAction(forOrderItem: orderItem, on: req)
                    }
                }
            }
        }
    }
    
    func sendAPNSFor(forOrder order: SUOrder, orderItem: SUOrderItem, on req: Request) throws -> Future<HTTPStatus> {
        
        guard let orderItemStatus = OrderStatus(rawValue: orderItem.orderItemStatus) else {
            throw Abort(.badRequest, reason: "Invalid order item status")
        }
            
        return try SUOrderItemAction.query(on: req).filter(\.orderItemID == orderItem.requireID()).first().flatMap { action in
            
            guard let actionQuantity = action?.quantity else {
                throw Abort(.badRequest, reason: "Missing or invalid order item action quantity")
            }
            
            let paddedOrderId = String(format: "%06d", try order.requireID())
            
            switch orderItemStatus {
                
            case OrderStatus.cancellationRequested:
                
                let messageTitle = actionQuantity == 1 ? "Order - Cancel Item" : "Order - Cancel Items"
                let messageItems = actionQuantity == 1 ? "item has" : "items have"
                let messageBody = "\(actionQuantity) \(messageItems) been cancelled from order no \(paddedOrderId) and a refund issued."
                return try self.sendAPNS(withTitle: messageTitle, body: messageBody, forOrder: order, orderItem: orderItem, on: req)
                
            case OrderStatus.returnRequested:
                
                let messageTitle = actionQuantity == 1 ? "Order - Return Item" : "Order - Return Items"
                let messageItems = actionQuantity == 1 ? "item has" : "items have"
                let messageBody = "\(actionQuantity) \(messageItems) been returned from order no \(paddedOrderId) and a refund issued."
                return try self.sendAPNS(withTitle: messageTitle, body: messageBody, forOrder: order, orderItem: orderItem, on: req)
                
            default:
                
                return req.future(HTTPStatus.ok)
            }
        }
    }
    
    func sendAPNS(withTitle title: String, body: String, forOrder order: SUOrder, orderItem: SUOrderItem, on req: Request) throws -> Future<HTTPStatus> {
        
        return order.customer.get(on: req).flatMap { customer in
            
            if let apnsToken = customer.apnsDeviceToken {
                
                guard let oneSignalAPIKey = Environment.get("ONESIGNAL_API_KEY") else { throw Abort(.internalServerError, reason: "Failed to get ONESIGNAL_API_KEY") }
                guard let oneSignalAppId = Environment.get("ONESIGNAL_APP_ID") else { throw Abort(.internalServerError, reason: "Failed to get ONESIGNAL_APP_ID") }
                
                let orderItemId = try orderItem.requireID()
                
                var notification = OneSignalNotification(title: title, subtitle: nil, body: body, users: nil, iosDeviceTokens: [apnsToken])
                
                notification.additionalData(key: "orderItemId", value: String(orderItemId))
                notification.setContentAvailable(true)
                
                let app = OneSignalApp(apiKey: oneSignalAPIKey, appId: oneSignalAppId)
                
                return try OneSignal.makeService(for: req).send(notification: notification, toApp: app).transform(to: HTTPStatus.ok)
                
            } else {
                
                return req.future(HTTPStatus.badRequest)
            }
            
            }.catchFlatMap { error in
                
                throw Abort(.internalServerError, reason: "Failed to get customer for order: \(error.localizedDescription)")
        }
    }
    
    func cancelReturnOrderItemHandler(_ req: Request, content: OrderItemCancelReturnData) throws -> Future<OrderItemCancelReturnResponse> {
        
        return try req.parameters.next(SUOrderItem.self).flatMap { orderItem in
            
            guard let cancelReturnItem = CancelReturnItem(rawValue: content.action) else { throw Abort(.badRequest, reason: "Invalid cancel return item type") }
            
            let quantity = content.quantity
            
            return orderItem.order.get(on: req).flatMap { order in
                
                return try self.sendOrderItemCancelReturnAdminEmail(forOrder: order, andOrderItem: orderItem, action: cancelReturnItem.rawValue, quantity: quantity, on: req).flatMap { response in
                    
                    switch cancelReturnItem {
                    case .cancelItem:
                        orderItem.orderItemStatus = OrderStatus.cancellationRequested.rawValue
                    case .returnItem:
                        orderItem.orderItemStatus = OrderStatus.returnRequested.rawValue
                    }
                    
                    let orderItemAction = try SUOrderItemAction(orderItemID: orderItem.requireID(), action: cancelReturnItem.rawValue, quantity: quantity)
                    
                    return req.transaction(on: .mysql) { conn in
                     
                        return orderItemAction.save(on: conn).flatMap { orderItemAction in
                            
                            return orderItem.update(on: conn).map(to: OrderItemCancelReturnResponse.self) { updatedOrderItem in
                                
                                return OrderItemCancelReturnResponse(orderItem: updatedOrderItem, orderItemAction: orderItemAction)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func sendOrderItemCancelReturnAdminEmail(forOrder order: SUOrder, andOrderItem orderItem: SUOrderItem, action: String, quantity: Int, on req: Request) throws -> Future<Response> {
        
        return order.customer.get(on: req).flatMap { customer in
            
            self.getCancelReturnDetails(for: orderItem, qty: quantity, on: req).flatMap { orderItemDetails in
                
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
    
    func getCancelReturnDetails(for orderItem: SUOrderItem, qty: Int, on req: Request) -> EventLoopFuture<CancelReturnOrderItemDetails> {
        
        return map(SUShopItem.find(orderItem.itemID, on: req), SUSize.find(orderItem.sizeID, on: req)) { item, size in
            
            guard let item = item else { throw Abort(.internalServerError, reason: "Failed to get item") }
            guard let size = size else { throw Abort(.internalServerError, reason: "Failed to get size") }
            
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencySymbol = "£"
         
            let formattedItemPrice = formatter.string(from: item.itemPrice as NSNumber)
            let itemTotal = item.itemPrice * Double(qty)
            let formattedItemTotal = formatter.string(from: itemTotal as NSNumber)
            
            return CancelReturnOrderItemDetails(name: item.itemName, size: size.sizeName, price: formattedItemPrice!, quantity: qty, total: formattedItemTotal!)
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
    
    struct OrderData: Content {
        let order: SUOrder
        let orderItemsWithActions: [OrderItemWithAction]
    }
    
    struct OrderItemWithAction: Content {
        let orderItem: SUOrderItem
        let orderItemAction: SUOrderItemAction?
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
    
    struct OrderItemCancelReturnResponse: Content {
        let orderItem: SUOrderItem
        let orderItemAction: SUOrderItemAction
    }
    
    struct OrderItemCancelReturnEmailContext: Encodable {
        let action: String
        let order: SUOrder
        let customer:  SUCustomer
        let orderItemDetails: CancelReturnOrderItemDetails
    }
    
    struct CancelReturnOrderItemDetails: Encodable {
        let name: String
        let size: String
        let price: String
        let quantity: Int
        let total: String
    }
}
