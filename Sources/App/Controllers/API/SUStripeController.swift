import Vapor
import Fluent
import Authentication
import Stripe

struct SUStripeController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let stripeRoutes = router.grouped("api", "stripe")
        
        stripeRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in
            
            jwtProtectedGroup.post("ephemeral-key", use: ephemeralKeyHandler)
            
            jwtProtectedGroup.post("customer", use: createCustomerHandler)
            jwtProtectedGroup.get("customer", String.parameter, use: getCustomerHandler)
            jwtProtectedGroup.post("customer", String.parameter, "source", use: createSourceHandler)
            jwtProtectedGroup.patch("customer", String.parameter, "default-source", use: defaultSourceHandler)
            
            jwtProtectedGroup.post("charge", use: chargeHandler)
        }
    }
    
    // MARK: - Ephemeral Key
    func ephemeralKeyHandler(_ req: Request) throws -> Future<StripeEphemeralKey> {
        
        return try req.content.decode(SUSTPEphemeralKeyPostData.self).flatMap(to: StripeEphemeralKey.self) { keyPostData in
         
            let customerId = keyPostData.customerId
            let apiVersion = keyPostData.apiVersion
            
            let stripeClient = try req.make(StripeClient.self)
            
            return try stripeClient.ephemeralKey.create(customer: customerId, apiVersion: apiVersion)
        }
    }
    
    // MARK: - Customer
    func createCustomerHandler(_ req: Request) throws -> Future<StripeCustomer> {
     
        return try req.content.decode(SUSTPCustomerPostData.self).flatMap(to: StripeCustomer.self) { customerPostData in
         
            let email = customerPostData.email
            
            let stripeClient = try req.make(StripeClient.self)
            
            return try stripeClient.customer.create(email: email)
        }
    }
    
    func getCustomerHandler(_ req: Request) throws -> Future<StripeCustomer> {
        
        let customerId = try req.parameters.next(String.self)
        let stripeClient = try req.make(StripeClient.self)
        
        return try stripeClient.customer.retrieve(customer: customerId)
    }
    
    func createSourceHandler(_ req: Request) throws -> Future<StripeCard> {
        
        return try req.content.decode(SUSTPCustomerSourceData.self).flatMap(to: StripeCard.self) { sourcePostData in
            
            let customerId = try req.parameters.next(String.self)
            let source = sourcePostData.source
            
            let stripeClient = try req.make(StripeClient.self)
            
            return try stripeClient.customer.addNewCardSource(customer: customerId, source: source)
        }
    }
    
    func defaultSourceHandler(_ req: Request) throws -> Future<StripeCustomer> {
        
        return try req.content.decode(SUSTPDefaultSourceData.self).flatMap(to: StripeCustomer.self) { defaultSourceData in
            
            let customerId = try req.parameters.next(String.self)
            let source = defaultSourceData.source
            
            let stripeClient = try req.make(StripeClient.self)
            
            return try stripeClient.customer.update(customer: customerId, defaultSource: source)
        }
    }
    
    // MARK: - Charge
    func chargeHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try req.content.decode(SUSTPChargeData.self).flatMap(to: HTTPStatus.self) { chargeData in
            
            let amount = chargeData.amount
            
            guard let currency = StripeCurrency(rawValue: chargeData.currency) else {
                throw Abort(.badRequest, reason: "Invalid Stripe currency.")
            }
            
            let description = chargeData.description
            let customer = chargeData.customerId
            
            let stripeClient = try req.make(StripeClient.self)
            
            return try stripeClient.charge.create(amount: amount, currency: currency, description: description, customer: customer).flatMap(to: HTTPStatus.self) { charge in
             
                return req.future(HTTPStatus.ok)
                
                }.catchFlatMap { error in
                    
                    throw Abort(.internalServerError, reason: "Error creating charge: \(error.localizedDescription)")
                    
            }
        }
    }
    
    // MARK: - Data Structs
    
    struct SUSTPEphemeralKeyPostData: Content {
        let customerId: String
        let apiVersion: String
    }
    
    struct SUSTPCustomerPostData: Content {
        let email: String
    }
    
    struct SUSTPDefaultSourceData: Content {
        let source: String
    }
    
    struct SUSTPCustomerSourceData: Content {
        let source: String
    }
    
    struct SUSTPChargeData: Content {
        let amount: Int
        let currency: String
        let description: String
        let customerId: String
    }
}
