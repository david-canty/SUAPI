import Vapor
import Fluent
import Crypto
import Authentication

struct SUUserController: RouteCollection {
    
    func boot(router: Router) throws {
        
        // CRUD
        let userRoutes = router.grouped("api", "users")
        let authSessionRoutes = userRoutes.grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedGroup = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        redirectProtectedGroup.post(SUUserData.self, use: createHandler)
        redirectProtectedGroup.get(use: getAllHandler)
        redirectProtectedGroup.get(SUUser.parameter, use: getHandler)
        redirectProtectedGroup.put(SUUser.parameter, use: updateHandler)
        redirectProtectedGroup.patch(SUUser.parameter, "change-password", use: changePasswordHandler)
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
                
                let errorString = "Error creating user:\n\n"
                var validationErrorReason = errorString
                
                if validationError.reason.contains("'name'") {
                    validationErrorReason += "Name must be alphanumeric only and not blank.\n\n"
                }
                
                if validationError.reason.contains("'username'") {
                    validationErrorReason += "Username must be alphanumeric only and not blank."
                }
                
                if validationErrorReason != errorString {
                    throw Abort(.badRequest, reason: validationErrorReason)
                }
            }
        }
        
        return user.save(on: req).convertToPublic().catchMap { error in
            
            let errorDescription = error.localizedDescription.lowercased()
            
            switch errorDescription {
                
            case let str where str.contains("duplicate"):
                throw Abort(.conflict, reason: "Error creating user:\n\nA user with this username exists.")
                
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
                    
                    let errorString = "Error updating user:\n\n"
                    var validationErrorReason = errorString
                    
                    if validationError.reason.contains("'name'") {
                        validationErrorReason += "Name must be alphanumeric only and not blank.\n\n"
                    }
                    
                    if validationError.reason.contains("'username'") {
                        validationErrorReason += "Username must be alphanumeric only and not blank."
                    }
                    
                    if validationErrorReason != errorString {
                        throw Abort(.badRequest, reason: validationErrorReason)
                    }
                }
            }
            
            return user.save(on: req).convertToPublic().catchMap { error in
                
                let errorDescription = error.localizedDescription.lowercased()
                
                switch errorDescription {
                    
                case let str where str.contains("duplicate"):
                    throw Abort(.conflict, reason: "Error updating user:\n\nA user with this username exists.")
                    
                default:
                    throw Abort(.internalServerError, reason: error.localizedDescription)
                }
            }
        }
    }
    
    func changePasswordHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self, req.parameters.next(SUUser.self), req.content.decode(SUUserPasswordData.self)) { user, passwordData in
            
            do {
                
                try passwordData.validate()
                
                let hashedPassword = try BCrypt.hash(passwordData.password)
                user.password = hashedPassword
                
            } catch {
                
                if let validationError = error as? ValidationError {
                    
                    let errorString = "Error changing password:\n\n"
                    var validationErrorReason = errorString
                    
                    if validationError.reason.contains("not larger") {
                        validationErrorReason += "Password must be 8 or more characters.\n\n"
                    }
                    
                    if validationError.reason.contains("match") {
                        validationErrorReason += "Password and confirmed password must match."
                    }
                    
                    if validationErrorReason != errorString {
                        throw Abort(.badRequest, reason: validationErrorReason)
                    }
                }
            }
            
            return user.save(on: req).transform(to: HTTPStatus.ok)
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
    
    struct SUUserPasswordData: Content, Validatable, Reflectable {
        
        let password: String
        let confirmPassword: String
        
        static func validations() throws -> Validations<SUUserPasswordData> {
            
            var validations = Validations(SUUserPasswordData.self)
            
            try validations.add(\.password, .count(8...))
            
            validations.add("passwords match") { passwordData in
            
                guard passwordData.password == passwordData.confirmPassword else {
                    throw BasicValidationError("Password and confirmed password must match.")
                }
            }
            
            return validations
        }
    }
}
