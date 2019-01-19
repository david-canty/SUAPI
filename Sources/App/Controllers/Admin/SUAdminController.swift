import Vapor
import Leaf
import Fluent
import Authentication

struct SUAdminController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let authSessionRoutes = router.grouped(SUUser.authSessionsMiddleware())
        
        authSessionRoutes.get("sign-in", use: signInHandler)
        authSessionRoutes.post(SignInData.self, at: "sign-in", use: signInPostHandler)
        
        let redirectProtectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        redirectProtectedRoutes.get(use: indexHandler)
        redirectProtectedRoutes.get(SUUser.parameter, "change-password", use: changePasswordHandler)
        redirectProtectedRoutes.post("sign-out", use: signOutHandler)
    }
    
    // Handlers
    func indexHandler(_ req: Request) throws -> Future<View> {
        
        let user = try req.requireAuthenticated(SUUser.self)
        let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
        let context = IndexContext(authenticatedUser: user, showCookieMessage: showCookieMessage)
        
        return try req.view().render("index", context)
    }
    
    func signInHandler(_ req: Request) throws -> Future<View> {
        
        let context: SignInContext
        
        if req.query[Bool.self, at: "error"] != nil {
            
            context = SignInContext(signInError: true)
            
        } else {
            
            context = SignInContext()
        }
        
        return try req.view().render("Sign In/signIn", context)
    }
    
    func signInPostHandler(_ req: Request, userData: SignInData) throws -> Future<HTTPResponseStatus> {
        
        return SUUser.authenticate(username: userData.username, password: userData.password, using: BCryptDigest(), on: req).map(to: HTTPResponseStatus.self) { user in
                
            guard let user = user else {
                throw Abort(.unauthorized, reason: "Invalid username or password.")
            }
            
            if !user.isEnabled {
                throw Abort(.forbidden, reason: "This user account is disabled.")
            }
            
            try req.authenticateSession(user)
            
            return HTTPResponseStatus.ok
        }
    }
    
    func changePasswordHandler(_ req: Request) throws -> Future<View> {
     
        return try req.parameters.next(SUUser.self).flatMap(to: View.self) { user in
            
            let authenticatedUser = try req.requireAuthenticated(SUUser.self)
            let context = ChangePasswordContext(authenticatedUser: authenticatedUser, editingUser: user)
            
            return try req.view().render("Users/password", context)
        }
    }
    
    func signOutHandler(_ req: Request) throws -> Response {
        
        try req.unauthenticateSession(SUUser.self)
        return req.redirect(to: "/")
    }
    
    // Structs
    struct SignInData: Content {
        let username: String
        let password: String
    }
    
    struct ChangePasswordData: Content {
        let password: String
        let confirmPassword: String
    }
    
    // Contexts
    struct IndexContext: Encodable {

        let title = "Home"
        let authenticatedUser: SUUser
        let showCookieMessage: Bool
    }
    
    struct SignInContext: Encodable {
        
        let title = "Sign In"
        let signInError: Bool
        
        init(signInError: Bool = false) {
            self.signInError = signInError
        }
    }
    
    struct ChangePasswordContext: Encodable {
        
        let title = "Change Password"
        let authenticatedUser: SUUser
        let editingUser: SUUser
    }
}
