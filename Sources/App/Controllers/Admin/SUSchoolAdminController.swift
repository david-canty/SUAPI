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
        
        redirectProtectedRoutes.get(SUSchool.parameter, "years", "create", use: createYearHandler)
        redirectProtectedRoutes.get(SUSchool.parameter, "years", use: yearsHandler)
        redirectProtectedRoutes.get(SUSchool.parameter, "years", SUYear.parameter, "edit", use: editYearHandler)
    }
    
    // CRUD handlers
    func createSchoolHandler(_ req: Request) throws -> Future<View> {
        
        let user = try req.requireAuthenticated(SUUser.self)
        let context = CreateSchoolContext(authenticatedUser: user)
        
        return try req.view().render("Schools/school", context)
    }
    
    func schoolsHandler(_ req: Request) throws -> Future<View> {
        
        return SUSchool.query(on: req).sort(\.sortOrder, .ascending).all().flatMap(to: View.self) { schools in
            
            let user = try req.requireAuthenticated(SUUser.self)
            let context = SchoolsContext(authenticatedUser: user, schools: schools)
            
            return try req.view().render("Schools/schools", context)
        }
    }
    
    func editSchoolHandler(_ req: Request) throws -> Future<View> {
        
        return try req.parameters.next(SUSchool.self).flatMap(to: View.self) { school in
            
            let user = try req.requireAuthenticated(SUUser.self)
            let context = EditSchoolContext(authenticatedUser: user, school: school)
            
            return try req.view().render("Schools/school", context)
        }
    }

    // Years CRUD handlers
    func createYearHandler(_ req: Request) throws -> Future<View> {
        
        return try req.parameters.next(SUSchool.self).flatMap(to: View.self) { school in
            
            let user = try req.requireAuthenticated(SUUser.self)
            let context = CreateYearContext(authenticatedUser: user, school: school)
            
            return try req.view().render("Years/year", context)
        }
    }
    
    func yearsHandler(_ req: Request) throws -> Future<View> {
        
        return try req.parameters.next(SUSchool.self).flatMap(to: View.self) { school in
            
            let user = try req.requireAuthenticated(SUUser.self)
            let years = try school.years.query(on: req).sort(\.sortOrder, .ascending).all()
            let context = YearsContext(authenticatedUser: user, school: school, years: years)
            
            return try req.view().render("Years/years", context)
        }
    }
    
    func editYearHandler(_ req: Request) throws -> Future<View> {
        
        return try flatMap(to: View.self,
                           req.parameters.next(SUSchool.self),
                           req.parameters.next(SUYear.self)) { school, year in

            let user = try req.requireAuthenticated(SUUser.self)
            let context = EditYearContext(authenticatedUser: user, year: year, school: school)
            
            return try req.view().render("Years/year", context)
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
    
    struct CreateYearContext: Encodable {
        let title = "Create Year"
        let authenticatedUser: SUUser
        let school: SUSchool
    }
    
    struct YearsContext: Encodable {
        let title = "Years"
        let authenticatedUser: SUUser
        let school: SUSchool
        let years: EventLoopFuture<[SUYear]>
    }
    
    struct EditYearContext: Encodable {
        let title = "Edit Year"
        let authenticatedUser: SUUser
        let year: SUYear
        let school: SUSchool
        let editing = true
    }
}
