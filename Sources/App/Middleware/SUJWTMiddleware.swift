import Vapor
import SwiftJWT

final class SUJWTMiddleware: Middleware {
    
    init() { }
    
    func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        
        return try next.respond(to: req).map { res in
            
            // Get token from authorization header
            guard let token = req.http.headers.firstValue(name: .authorization) else {
                throw Abort(HTTPResponseStatus.unauthorized)
            }
                
            // Decode token
            guard let jwt = try JWT.decode(token) else {
                throw Abort(HTTPResponseStatus.unauthorized)
            }
            
            // Get header key id
            guard let headerKid = jwt.header[.kid] as? String else {
                throw Abort(HTTPResponseStatus.unauthorized)
            }
            
            // Get public key correspondong to header key id
            guard let publicKey = SUJWTHelper.sharedInstance.publicKeys[headerKid] else {
                throw Abort(HTTPResponseStatus.unauthorized)
            }
            
            // Validate token claims
            guard let headerAlg = jwt.header[.alg] as? String, headerAlg == "RS256" else {
                throw Abort(HTTPResponseStatus.unauthorized)
            }
            
            let issuer = "https://securetoken.google.com/red-house-school"
            let audience = "red-house-school"
            let validationResult = jwt.validateClaims(issuer: issuer, audience: audience)
            
            if validationResult != .success {
                print("Validate token claims failed: ", validationResult)
                throw Abort(HTTPResponseStatus.unauthorized)
            }
            
            // Verify validated token
            let verified = try JWT.verify(token, using: .rs256(Data(publicKey.utf8), RSAKeyType.certificate))
            if !verified {
                throw Abort(HTTPResponseStatus.unauthorized)
            }
            
//            if let uid = jwt.claims["sub"] {
//
//                print("user id = \(uid)")
//            }
            
            return res
        }
    }
}

extension SUJWTMiddleware: ServiceType {
    
    static func makeService(for container: Container) throws -> SUJWTMiddleware {
        
        return .init()
    }
}
