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
        
        let context = CreateSchoolContext()
        return try req.view().render("school", context)
    }
    
    func schoolsHandler(_ req: Request) throws -> Future<View> {
        
        return SUSchool.query(on: req).all().flatMap(to: View.self) { schools in
            
            let context = SchoolsContext(title: "Schools", schools: schools)
            return try req.view().render("schools", context)
        }
    }
    
    func editSchoolHandler(_ req: Request) throws -> Future<View> {
        
        return try req.parameters.next(SUSchool.self).flatMap(to: View.self) { school in
            
            let context = EditSchoolContext(school: school)
            return try req.view().render("school", context)
        }
    }

    // Contexts
    struct CreateSchoolContext: Encodable {
        let title = "Create School"
    }
    
    struct SchoolsContext: Encodable {
        let title: String
        let schools: [SUSchool]
    }
    
    struct EditSchoolContext: Encodable {
        let title = "Edit School"
        let school: SUSchool
        let editing = true
    }
}
