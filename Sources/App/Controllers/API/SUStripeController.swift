import Vapor
import Fluent
import Authentication
import Stripe

struct SUStripeController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let stripeRoutes = router.grouped("api")
        stripeRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in
            
            jwtProtectedGroup.post("charge", use: chargeHandler)
        }
    }
    
    func chargeHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try req.content.decode(SUChargeData.self).flatMap(to: HTTPStatus.self) { chargeData in
            
            let amount = chargeData.amount
            
            guard let currency = StripeCurrency(rawValue: chargeData.currency) else {
                throw Abort(.badRequest, reason: "Invalid Stripe currency.")
            }
            
            let description = chargeData.description
            let source = chargeData.token
            
            let stripeClient = try req.make(StripeClient.self)
            
            return try stripeClient.charge.create(amount: amount, currency: currency, description: description, source: source).flatMap(to: HTTPStatus.self) { charge in
             
                return req.future(HTTPStatus.ok)
                
                }.catchFlatMap { error in
                    
                    throw Abort(.internalServerError, reason: "Error creating charge: \(error.localizedDescription)")
                    
            }
        }
    }
    
    struct SUChargeData: Content {
        let token: String
        let amount: Int
        let currency: String
        let description: String
    }
}
