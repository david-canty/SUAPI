import Vapor
import Fluent

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
}

struct SUOrderController: RouteCollection {

    func boot(router: Router) throws {

        let orderRoutes = router.grouped("api", "customers")
        orderRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in

            jwtProtectedGroup.post(use: createCustomerHandler)
            jwtProtectedGroup.post(SUCustomer.parameter, "orders", use: createOrderHandler)

        }
    }
    
    func createCustomerHandler(_ req: Request) throws -> Future<SUCustomer> {
        
        return try req.content.decode(SUCustomerData.self).flatMap(to: SUCustomer.self) { customerData in
            
            let firebaseUserId = customerData.firebaseUserId
            let email = customerData.email
            
            let customer = SUCustomer(firebaseUserId: firebaseUserId, email: email)
            
            do {
                
                try customer.validate()
                customer.timestamp = Date()
                
            } catch {
                
                if let validationError = error as? ValidationError {
                    
                    let errorString = "Error creating customer:\n\n"
                    var validationErrorReason = errorString
                    
                    if validationError.reason.contains("valid email") {
                        validationErrorReason += "Invalid email address."
                    }
                    
                    if validationErrorReason != errorString {
                        throw Abort(.badRequest, reason: validationErrorReason)
                    }
                }
            }
            
            return customer.save(on: req).catchMap { error in
                
                let errorDescription = error.localizedDescription.lowercased()
                
                switch errorDescription {
                    
                case let str where str.contains("duplicate"):
                    throw Abort(.conflict, reason: "Error creating customer:\n\nA customer with this email exists.")
                    
                default:
                    throw Abort(.internalServerError, reason: error.localizedDescription)
                }
            }
        }
    }
    
    struct SUCustomerData: Content {
        let firebaseUserId: String
        let email: String
    }

    func createOrderHandler(_ req: Request) throws -> Future<SUOrderInfo> {

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
}

