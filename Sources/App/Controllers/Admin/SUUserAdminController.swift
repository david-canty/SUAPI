import Vapor
import Leaf
import Fluent
import Authentication

struct SUUserAdminController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let authSessionRoutes = router.grouped("users").grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        redirectProtectedRoutes.get("create", use: createUserHandler)
        redirectProtectedRoutes.get(use: usersHandler)
        redirectProtectedRoutes.get(SUUser.parameter, "edit", use: editUserHandler)
        redirectProtectedRoutes.get(SUUser.parameter, "change-password", use: changePasswordHandler)
    }
    
    // CRUD handlers
    func createUserHandler(_ req: Request) throws -> Future<View> {
        
        let user = try req.requireAuthenticated(SUUser.self)
        let context = CreateUserContext(authenticatedUser: user)
        
        return try req.view().render("user", context)
    }
    
    func usersHandler(_ req: Request) throws -> Future<View> {
        
        return SUUser.query(on: req).all().flatMap(to: View.self) { users in
            
            let user = try req.requireAuthenticated(SUUser.self)
            let context = UsersContext(authenticatedUser: user, users: users)
            
            return try req.view().render("users", context)
        }
    }
    
    func editUserHandler(_ req: Request) throws -> Future<View> {
        
        return try req.parameters.next(SUUser.self).flatMap(to: View.self) { user in
            
            let authenticatedUser = try req.requireAuthenticated(SUUser.self)
            let context = EditUserContext(authenticatedUser: authenticatedUser, editingUser: user)
            
            return try req.view().render("user", context)
        }
    }
    
    func changePasswordHandler(_ req: Request) throws -> Future<View> {
        
        return try req.parameters.next(SUUser.self).flatMap(to: View.self) { user in
            
            let authenticatedUser = try req.requireAuthenticated(SUUser.self)
            let context = ChangePasswordContext(authenticatedUser: authenticatedUser, editingUser: user)
            
            return try req.view().render("password", context)
        }
    }
    
    // Contexts
    struct CreateUserContext: Encodable {
        let title = "Create User"
        let authenticatedUser: SUUser
    }
    
    struct UsersContext: Encodable {
        let title = "Users"
        let authenticatedUser: SUUser
        let users: [SUUser]
    }
    
    struct EditUserContext: Encodable {
        let title = "Edit User"
        let authenticatedUser: SUUser
        let editingUser: SUUser
    }
    
    struct ChangePasswordContext: Encodable {
        
        let title = "Change Password"
        let authenticatedUser: SUUser
        let editingUser: SUUser
    }
}
