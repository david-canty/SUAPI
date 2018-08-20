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
            
            // Validate claims
            
            
            // Verify token
            let headerKid = jwt.header[.kid] as! String
            
            if let publicKey = SUJWTHelper.sharedInstance.publicKeys[headerKid] {
                
                let stringFromWeb = "-----BEGIN CERTIFICATE-----\nMIIDHDCCAgSgAwIBAgIIJtpzZgDm7/IwDQYJKoZIhvcNAQEFBQAwMTEvMC0GA1UE\nAxMmc2VjdXJldG9rZW4uc3lzdGVtLmdzZXJ2aWNlYWNjb3VudC5jb20wHhcNMTgw\nODEzMjEyMDI5WhcNMTgwODMwMDkzNTI5WjAxMS8wLQYDVQQDEyZzZWN1cmV0b2tl\nbi5zeXN0ZW0uZ3NlcnZpY2VhY2NvdW50LmNvbTCCASIwDQYJKoZIhvcNAQEBBQAD\nggEPADCCAQoCggEBALfda+cug+JOY+u1uuIOn93JTxDHCWSwhDVgh488tgkPdi8z\ncG6r0r8DaiqRlyJWDcZ9Ywa2IPNHgyEWw07iQACykyZecZy3TIKoP0Bo5Fz7Tb+0\nZw8Qf0veeSksMybwLaVV5Xtkr3IDw3LoESOca0Bd5oHPv2I/3amZIAg2Q0JSuAQs\nQ88f6/zXTVpi1wBmKbCx0hxpPRjMJhCwCKmXqd5a0D6+ythGQy3rFU1qN3IB/7BR\nmYdNPr2N6UUn8AixYkhNE+tV/1Ww2XDWsYfHKTXCcUOtLRc9KWcL+3E8oOpt7785\ni6YgvdiMKz3Pw9bPJcwZKiEjKNNe9pZuqo6RskECAwEAAaM4MDYwDAYDVR0TAQH/\nBAIwADAOBgNVHQ8BAf8EBAMCB4AwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwIwDQYJ\nKoZIhvcNAQEFBQADggEBAK+RBKB57tihgDeIXQHfW3RFZbZVt1jnsFo04qPf4lRX\n3tk0e/Xk0ZyGx6YXIUGyCH57Gmv8MQJAfjcYXpjfNbBR3VuOAP9Et0E8+HJihoJd\n871ozoxt8PPOYcATWaDy9R7j8YpGlYRqSHjwdLys/4Fg7cYNslDj+KbuNzbgDA18\nkf99K7qj9mGe+vAmDmkoXdmmvx+PSoInpsawNYGpVcNdY7F0tKnr7og0lh5ISeLd\nfSQMwj0YGFph6ZmiXY8rl0nLYLWyP7CaNAoYs7IzK0oraWgmtKXWxSmXCzF3jJ4N\nMIw1J91a0vE77uVms0OHPPJyUkjSpOjRfu0WIMZI130=\n-----END CERTIFICATE-----\n"
                
                if stringFromWeb == publicKey {
                    print("the same")
                } else {
                    print("not the same")
                }
                
                let verified = try JWT.verify(token, using: .rs256(Data(publicKey.utf8), RSAKeyType.certificate))
                
                if !verified {
                    
                    throw Abort(HTTPResponseStatus.unauthorized)
                }
                
            } else {
                
                throw Abort(HTTPResponseStatus.unauthorized)
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
