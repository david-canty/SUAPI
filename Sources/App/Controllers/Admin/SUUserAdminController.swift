import Vapor
import Leaf
import Fluent
import Authentication

struct SUUserAdminController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let authSessionRoutes = router.grouped("users").grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/signin"))
        
        redirectProtectedRoutes.get("create", use: createUserHandler)
        redirectProtectedRoutes.get(use: usersHandler)
        redirectProtectedRoutes.get(SUUser.parameter, "edit", use: editUserHandler)
    }
    
    // CRUD handlers
    func createUserHandler(_ req: Request) throws -> Future<View> {
        
        let user = try req.requireAuthenticated(SUUser.self)
        let isAdmin = user.username == "admin"
        
        let context = CreateUserContext(isAdmin: isAdmin)
        return try req.view().render("user", context)
    }
    
    func usersHandler(_ req: Request) throws -> Future<View> {
        
        let user = try req.requireAuthenticated(SUUser.self)
        let isAdmin = user.username == "admin"
        
        return SUUser.query(on: req).all().flatMap(to: View.self) { users in
            
            let context = UsersContext(isAdmin: isAdmin, users: users)
            return try req.view().render("users", context)
        }
    }
    
    func editUserHandler(_ req: Request) throws -> Future<View> {
        
        return try req.parameters.next(SUUser.self).flatMap(to: View.self) { user in
            
            let authenticatedUser = try req.requireAuthenticated(SUUser.self)
            let isAdmin = authenticatedUser.username == "admin"
            
            let context = EditUserContext(isAdmin: isAdmin, user: user)
            return try req.view().render("user", context)
        }
    }
    
    // Contexts
    struct CreateUserContext: Encodable {
        let title = "Create User"
        let isAdmin: Bool
    }
    
    struct UsersContext: Encodable {
        let title = "Users"
        let isAdmin: Bool
        let users: [SUUser]
    }
    
    struct EditUserContext: Encodable {
        let title = "Edit User"
        let isAdmin: Bool
        let user: SUUser
        let editing = true
    }
}
