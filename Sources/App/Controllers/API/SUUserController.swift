import Vapor
import Fluent
import Crypto
import Authentication

struct SUUserController: RouteCollection {
    
    func boot(router: Router) throws {
        
        // CRUD
        let userRoutes = router.grouped("api", "users")
        let authSessionRoutes = userRoutes.grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedGroup = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/signin"))
        
        redirectProtectedGroup.post(SUUser.self, use: createHandler)
        redirectProtectedGroup.get(use: getAllHandler)
        redirectProtectedGroup.get(SUUser.parameter, use: getHandler)
        redirectProtectedGroup.put(SUUser.parameter, use: updateHandler)
        redirectProtectedGroup.delete(SUUser.parameter, use: deleteHandler)
    }

    // CRUD
    func createHandler(_ req: Request, user: SUUser) throws -> Future<SUUser.Public> {
        
        do {
            
            try user.validate()
            user.password = try BCrypt.hash(user.password)
            user.timestamp = String(describing: Date())
            
        } catch {
            
            if let validationError = error as? ValidationError {
                
                switch validationError.reason {
                    
                case let str where str.contains("not larger than 1"):
                    throw Abort(.badRequest, reason: "Username cannot be blank.")
                    
                case let str where str.contains("invalid character"):
                    throw Abort(.badRequest, reason: "Username must be alphanumeric with no spaces.")
                    
                default:
                    throw Abort(.internalServerError, reason: error.localizedDescription)
                }
            }
        }
        
        return user.save(on: req).convertToPublic().catchMap { error in
            
            let errorDescription = error.localizedDescription.lowercased()
            
            switch errorDescription {
                
            case let str where str.contains("duplicate"):
                throw Abort(.conflict, reason: "A user with this username exists.")
                
            default:
                throw Abort(.internalServerError, reason: error.localizedDescription)
            }
        }
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[SUUser.Public]> {
        
        return SUUser.query(on: req).decode(data: SUUser.Public.self).all()
    }
    
    func getHandler(_ req: Request) throws -> Future<SUUser.Public> {
        
        return try req.parameters.next(SUUser.self).convertToPublic()
    }
    
    func updateHandler(_ req: Request) throws -> Future<SUUser.Public> {
        
        return try flatMap(to: SUUser.Public.self, req.parameters.next(SUUser.self), req.content.decode(SUUser.self)) { user, updatedUser in
            
            user.name = updatedUser.name
            user.username = updatedUser.username
            
            do {
                
                try user.validate()
                user.timestamp = String(describing: Date())
                
            } catch {
                
                if let validationError = error as? ValidationError {
                    
                    switch validationError.reason {
                        
                    case let str where str.contains("not larger than 1"):
                        throw Abort(.badRequest, reason: "Username cannot be blank.")
                        
                    case let str where str.contains("invalid character"):
                        throw Abort(.badRequest, reason: "Username must be alphanumeric with no spaces.")
                        
                    default:
                        throw Abort(.internalServerError, reason: error.localizedDescription)
                    }
                }
            }
            
            return user.save(on: req).convertToPublic().catchMap { error in
                
                let errorDescription = error.localizedDescription.lowercased()
                
                switch errorDescription {
                    
                case let str where str.contains("duplicate"):
                    throw Abort(.conflict, reason: "A user with this username exists.")
                    
                default:
                    throw Abort(.internalServerError, reason: error.localizedDescription)
                }
            }
        }
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try req.parameters.next(SUUser.self).delete(on: req).transform(to: HTTPStatus.noContent)
    }
}
