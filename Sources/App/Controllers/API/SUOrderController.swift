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

        let orderRoutes = router.grouped("api", "customers")
        orderRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in

            jwtProtectedGroup.post(SUCustomer.parameter, "orders", use: createHandler)
            
        }
        
        let authSessionRoutes = orderRoutes.grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedGroup = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        redirectProtectedGroup.patch(SUOrder.parameter, "status", use: updateOrderStatusHandler)
    }

    func createHandler(_ req: Request) throws -> Future<SUOrderInfo> {

        return try flatMap(to: SUOrderInfo.self, req.parameters.next(SUCustomer.self), req.content.decode(SUOrderPostData.self)) { customer, orderData in
            
            return req.transaction(on: .mysql) { conn in
             
                let order = SUOrder(customerID: customer.id!,
                                    orderDate: Date(),
                                    orderStatus: OrderStatus.ordered.rawValue,
                                    paymentMethod: orderData.paymentMethod)
                
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
    
    // Data structs
    struct SUOrderPostData: Content {
        let orderItems: [OrderItemInfo]
        let paymentMethod: String
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
}
