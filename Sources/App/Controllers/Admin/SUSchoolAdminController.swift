import Vapor
import Leaf
import Fluent

struct SUSchoolAdminController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let schoolsRoute = router.grouped("schools")
        
        schoolsRoute.get(use: schoolsHandler)
        schoolsRoute.get("create", use: createSchoolHandler)
    }
    
    // CRUD handlers
    func schoolsHandler(_ req: Request) throws -> Future<View> {
        
        return SUSchool.query(on: req).all().flatMap(to: View.self) { schools in
            
            let context = SchoolsContext(title: "Schools", schools: schools)
            return try req.view().render("schools", context)
        }
    }
    
    func createSchoolHandler(_ req: Request) throws -> Future<View> {
        
        let context = CreateSchoolContext()
        return try req.view().render("school", context)
    }

    // Contexts
    struct SchoolsContext: Encodable {
        let title: String
        let schools: [SUSchool]
    }
    
    struct CreateSchoolContext: Encodable {
        let title = "Create School"
    }
}

