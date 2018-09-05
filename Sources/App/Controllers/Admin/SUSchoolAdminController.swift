import Vapor
import Leaf
import Fluent
import Authentication

struct SUSchoolAdminController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let authSessionRoutes = router.grouped("schools").grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        redirectProtectedRoutes.get("create", use: createSchoolHandler)
        redirectProtectedRoutes.get(use: schoolsHandler)
        redirectProtectedRoutes.get(SUSchool.parameter, "edit", use: editSchoolHandler)
    }
    
    // CRUD handlers
    func createSchoolHandler(_ req: Request) throws -> Future<View> {
        
        let user = try req.requireAuthenticated(SUUser.self)
        let context = CreateSchoolContext(authenticatedUser: user)
        
        return try req.view().render("school", context)
    }
    
    func schoolsHandler(_ req: Request) throws -> Future<View> {
        
        return SUSchool.query(on: req).all().flatMap(to: View.self) { schools in
            
            let user = try req.requireAuthenticated(SUUser.self)
            let context = SchoolsContext(authenticatedUser: user, schools: schools)
            
            return try req.view().render("schools", context)
        }
    }
    
    func editSchoolHandler(_ req: Request) throws -> Future<View> {
        
        return try req.parameters.next(SUSchool.self).flatMap(to: View.self) { school in
            
            let user = try req.requireAuthenticated(SUUser.self)
            let context = EditSchoolContext(authenticatedUser: user, school: school)
            
            return try req.view().render("school", context)
        }
    }

    // Contexts
    struct CreateSchoolContext: Encodable {
        let title = "Create School"
        let authenticatedUser: SUUser
    }
    
    struct SchoolsContext: Encodable {
        let title = "Schools"
        let authenticatedUser: SUUser
        let schools: [SUSchool]
    }
    
    struct EditSchoolContext: Encodable {
        let title = "Edit School"
        let authenticatedUser: SUUser
        let school: SUSchool
        let editing = true
    }
}
