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
        
        redirectProtectedGroup.post(SUUserData.self, use: createHandler)
        redirectProtectedGroup.get(use: getAllHandler)
        redirectProtectedGroup.get(SUUser.parameter, use: getHandler)
        redirectProtectedGroup.put(SUUser.parameter, use: updateHandler)
        redirectProtectedGroup.patch(SUUser.parameter, "status", use: isEnabledHandler)
        redirectProtectedGroup.delete(SUUser.parameter, use: deleteHandler)
    }

    // CRUD
    func createHandler(_ req: Request, data: SUUserData) throws -> Future<SUUser.Public> {
        
        let password = try BCrypt.hash(data.password)
        
        let user = SUUser(name: data.name,
                          username: data.username,
                          password: password)
        
        do {
            
            try user.validate()
            
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
        
        return try flatMap(to: SUUser.Public.self, req.parameters.next(SUUser.self), req.content.decode(SUUserUpdateData.self)) { user, updatedUser in
            
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
    
    func isEnabledHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self, req.parameters.next(SUUser.self), req.content.decode([String: Bool].self)) { user, status in
            
            if user.username == "admin" {
                
                throw Abort(.badRequest, reason: "Cannot disable admin user.")
            }
            user.isEnabled = !status["isEnabled"]!
            return user.save(on: req).transform(to: HTTPStatus.ok)
        }
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try req.parameters.next(SUUser.self).flatMap(to: HTTPStatus.self) { user in
            
            if user.username == "admin" {
               
                throw Abort(.badRequest, reason: "Cannot delete admin user.")
            }
            return user.delete(on: req).transform(to: HTTPStatus.noContent)
        }
    }
    
    struct SUUserData: Content {
        let name: String
        let username: String
        let password: String
    }
    
    struct SUUserUpdateData: Content {
        let name: String
        let username: String
    }
}
