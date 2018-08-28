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
        
        let context = IndexContext(title: "Home")
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
    
    func signInPostHandler(_ req: Request, userData: SignInPostData) throws -> Future<Response> {
        
        return SUUser.authenticate(username: userData.username, password: userData.password, using: BCryptDigest(), on: req).map(to: Response.self) { user in
                
            guard let user = user else {
                return req.redirect(to: "/signin?error")
            }
            
            try req.authenticateSession(user)
            
            return req.redirect(to: "/")
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
        
        let title: String
    }
    
    struct SignInContext: Encodable {
        
        let title = "Sign In"
        let signInError: Bool
        
        init(signInError: Bool = false) {
            self.signInError = signInError
        }
    }
}
