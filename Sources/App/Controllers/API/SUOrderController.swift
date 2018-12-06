import Vapor
import Fluent
import Authentication

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
    case cancelled = "Cancelled"
}

struct SUOrderController: RouteCollection {

    func boot(router: Router) throws {

        // Orders
        let ordersRoutes = router.grouped("api", "orders")
        ordersRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in

            jwtProtectedGroup.post(use: createHandler)
            
        }
        
        let ordersAuthSessionRoutes = ordersRoutes.grouped(SUUser.authSessionsMiddleware())
        let ordersRedirectProtectedGroup = ordersAuthSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        ordersRedirectProtectedGroup.patch(SUOrder.parameter, "status", use: updateOrderStatusHandler)
        ordersRedirectProtectedGroup.delete(SUOrder.parameter, use: deleteOrderHandler)
        
        // Order Items
        let orderItemsRoutes = router.grouped("api", "order-items")
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

    func updateOrderStatusHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self, req.parameters.next(SUOrder.self), req.content.decode(OrderStatusData.self)) { order, orderStatusData in
            
            if order.orderStatus != orderStatusData.orderStatus {
                
                order.timestamp = Date()
                order.orderStatus = orderStatusData.orderStatus
                
                return order.update(on: req).transform(to: HTTPStatus.ok)
            }
            
            return req.future(HTTPStatus.ok)
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
    
    struct OrderStatusData: Content {
        let orderStatus: String
    }
    
    struct OrderItemQuantityData: Content {
        let quantity: Int
    }
}
