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
            
            // To Do
            // - validate claims
            
            let headerKid = jwt.header[.kid] as! String
            
            let _ = HTTPClient.connect(scheme: .https, hostname: "www.googleapis.com", on: req).flatMap(to: HTTPResponse.self) { client in
                
                let httpReq = HTTPRequest(method: .GET, url: "/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com")
                
                return client.send(httpReq).map(to: HTTPResponse.self) { clientResponse in
                    
                    let cache = clientResponse.headers.firstValue(name: HTTPHeaderName.cacheControl)
                    
                    let responseBody = clientResponse.body
                    
                    // To Do
                    // - parse response body for headerKid
                    // - extract corresponding certificate
                    //let verified = try JWT.verify(token, using: .rs256(Data(certificate.utf8), RSAKeyType.certificate) - throw abort if not verified
                    
                    return clientResponse
                }
            }
            
            return res
        }
    }
}

extension SUJWTMiddleware: ServiceType {
    
    static func makeService(for container: Container) throws -> SUJWTMiddleware {
        
        return .init()
    }
}
