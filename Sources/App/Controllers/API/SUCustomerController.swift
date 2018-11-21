import Vapor
import Fluent

struct SUCustomerController: RouteCollection {

    func boot(router: Router) throws {

        let customerRoutes = router.grouped("api", "customers")
        customerRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in

            jwtProtectedGroup.post(use: createHandler)

        }
    }

    func createHandler(_ req: Request) throws -> Future<SUCustomer> {

        return try req.content.decode(SUCustomerData.self).flatMap(to: SUCustomer.self) { customerData in
        
            let firebaseUserId = customerData.firebaseUserId
            let email = customerData.email
            
            let customer = SUCustomer(firebaseUserId: firebaseUserId, email: email)
            
//            do {
//
//                try customer.validate()
//                customer.timestamp = Date()
//
//            } catch {
//
//                if let validationError = error as? ValidationError {
//
//                    let errorString = "Error creating customer:\n\n"
//                    var validationErrorReason = errorString
//
//                    if validationError.reason.contains("valid email") {
//                        validationErrorReason += "Invalid email address."
//                    }
//
//                    if validationErrorReason != errorString {
//                        throw Abort(.badRequest, reason: validationErrorReason)
//                    }
//                }
//            }
            
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
}
