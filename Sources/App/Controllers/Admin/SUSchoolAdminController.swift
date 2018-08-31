import Vapor
import Leaf
import Fluent
import Authentication

struct SUSchoolAdminController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let authSessionRoutes = router.grouped("schools").grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/signin"))
        
        redirectProtectedRoutes.get("create", use: createSchoolHandler)
        redirectProtectedRoutes.get(use: schoolsHandler)
        redirectProtectedRoutes.get(SUSchool.parameter, "edit", use: editSchoolHandler)
    }
    
    // CRUD handlers
    func createSchoolHandler(_ req: Request) throws -> Future<View> {
        
        let user = try req.requireAuthenticated(SUUser.self)
        let isAdmin = user.username == "admin"
        
        let context = CreateSchoolContext(isAdmin: isAdmin)
        return try req.view().render("school", context)
    }
    
    func schoolsHandler(_ req: Request) throws -> Future<View> {
        
        let user = try req.requireAuthenticated(SUUser.self)
        let isAdmin = user.username == "admin"
        
        return SUSchool.query(on: req).all().flatMap(to: View.self) { schools in
            
            let context = SchoolsContext(isAdmin: isAdmin, schools: schools)
            return try req.view().render("schools", context)
        }
    }
    
    func editSchoolHandler(_ req: Request) throws -> Future<View> {
        
        return try req.parameters.next(SUSchool.self).flatMap(to: View.self) { school in
            
            let user = try req.requireAuthenticated(SUUser.self)
            let isAdmin = user.username == "admin"
            
            let context = EditSchoolContext(isAdmin: isAdmin, school: school)
            return try req.view().render("school", context)
        }
    }

    // Contexts
    struct CreateSchoolContext: Encodable {
        let title = "Create School"
        let isAdmin: Bool
    }
    
    struct SchoolsContext: Encodable {
        let title = "Schools"
        let isAdmin: Bool
        let schools: [SUSchool]
    }
    
    struct EditSchoolContext: Encodable {
        let title = "Edit School"
        let isAdmin: Bool
        let school: SUSchool
        let editing = true
    }
}
