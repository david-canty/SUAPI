import Vapor
import Fluent

struct SUCustomerController: RouteCollection {

    func boot(router: Router) throws {

        let customerRoutes = router.grouped("api", "customers")
        customerRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in

            // CRUD
            jwtProtectedGroup.post(use: createHandler)
            jwtProtectedGroup.patch(APNSToken.self, at: SUCustomer.parameter, "apns-token", use: apnsTokenHandler)
            
            // Orders
            jwtProtectedGroup.get(SUCustomer.parameter, "orders", use: getOrdersHandler)
        }
    }

    // CRUD
    func createHandler(_ req: Request) throws -> Future<SUCustomer> {

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

    func apnsTokenHandler(_ req: Request, content: APNSToken) throws -> Future<SUCustomer> {
        
        return try req.parameters.next(SUCustomer.self).flatMap { customer in
            
            customer.apnsDeviceToken = content.token
            customer.timestamp = Date()
            return customer.update(on: req)
        }
    }
    
    // Orders
    func getOrdersHandler(_ req: Request) throws -> Future<[OrderData]> {
        
        return try req.parameters.next(SUCustomer.self).flatMap(to: [OrderData].self) { customer in
            
            return try customer.orders.query(on: req).all().flatMap(to: [OrderData].self) { orders in
             
                return try orders.compactMap { order in
                    
                    return try order.orderItems.query(on: req).all().map(to: OrderData.self) { orderItems in
                        
                        return OrderData(order: order, orderItems: orderItems)
                    }
    
                }.flatten(on: req)
            }
        }
    }
    
    // Data structs
    struct SUCustomerData: Content {
        let firebaseUserId: String
        let email: String
    }
    
    struct OrderData: Content {
        let order: SUOrder
        let orderItems: [SUOrderItem]
    }
    
    struct APNSToken: Content {
        let token: String
    }
}
