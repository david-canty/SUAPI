import Vapor
import SwiftJWT

final class SUJWTMiddleware: Middleware {
    
    
    
    init() {
        
    }
    
    func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        
        return try next.respond(to: req).map { res in
            
            guard let token = req.http.headers.firstValue(name: .authorization),
                let jwt = try JWT.decode(token) else {
                throw Abort(HTTPResponseStatus.unauthorized)
            }
            
            // - validate claims
            
            let headerKid = jwt.header[.kid] as! String
            let publicKey = SUJWTHelper.sharedInstance.publicKeys[headerKid]
            
            //let verified = try JWT.verify(token, using: .rs256(Data(certificate.utf8), RSAKeyType.certificate) - throw abort if not verified
            
            return res
        }
    }
}

extension SUJWTMiddleware: ServiceType {
    
    static func makeService(for container: Container) throws -> SUJWTMiddleware {
        
        return .init()
    }
}
