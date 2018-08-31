import Vapor
import Leaf
import Fluent
import Authentication

struct SUAdminController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let authSessionRoutes = router.grouped(SUUser.authSessionsMiddleware())
        
        authSessionRoutes.get("signin", use: signInHandler)
        authSessionRoutes.post(SignInPostData.self, at: "signin", use: signInPostHandler)
        
        let redirectProtectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/signin"))
        
        redirectProtectedRoutes.get(use: indexHandler)
        redirectProtectedRoutes.post("signout", use: signOutHandler)
    }
    
    // Handlers
    func indexHandler(_ req: Request) throws -> Future<View> {
        
        let user = try req.requireAuthenticated(SUUser.self)
        let isAdmin = user.username == "admin"
        
        let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
        let context = IndexContext(isAdmin: isAdmin, showCookieMessage: showCookieMessage)
        return try req.view().render("index", context)
    }
    
    func signInHandler(_ req: Request) throws -> Future<View> {
        
        let context: SignInContext
        
        if req.query[Bool.self, at: "error"] != nil {
            
            context = SignInContext(signInError: true)
            
        } else {
            
            context = SignInContext()
        }
        
        return try req.view().render("signIn", context)
    }
    
    func signInPostHandler(_ req: Request, userData: SignInPostData) throws -> Future<HTTPResponseStatus> {
        
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
    
    struct SignInPostData: Content {
        let username: String
        let password: String
    }
    
    func signOutHandler(_ req: Request) throws -> Response {
        
        try req.unauthenticateSession(SUUser.self)
        return req.redirect(to: "/")
    }
    
    // Contexts
    struct IndexContext: Encodable {
        
        let title = "Home"
        let isAdmin: Bool
        let showCookieMessage: Bool
    }
    
    struct SignInContext: Encodable {
        
        let title = "Sign In"
        let signInError: Bool
        
        init(signInError: Bool = false) {
            self.signInError = signInError
        }
    }
}
