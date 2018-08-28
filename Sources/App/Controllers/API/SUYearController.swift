import Vapor
import Fluent
import Authentication

struct SUYearController: RouteCollection {
    
    func boot(router: Router) throws {
        
        // CRUD
        let yearRoutes = router.grouped("api", "years")
        yearRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in
            
            jwtProtectedGroup.get(use: getAllHandler)
            jwtProtectedGroup.get(SUYear.parameter, use: getHandler)
            
            // School
            jwtProtectedGroup.get(SUItem.parameter, "school", use: getSchoolHandler)
            
            // Items
            jwtProtectedGroup.get(SUYear.parameter, "items", use: getItemsHandler)
        }
        
        let authSessionRoutes = yearRoutes.grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedGroup = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/signin"))
        
        redirectProtectedGroup.post(SUYear.self, use: createHandler)
        redirectProtectedGroup.put(SUYear.parameter, use: updateHandler)
        redirectProtectedGroup.delete(SUYear.parameter, use: deleteHandler)
    }
    
    // CRUD
    func createHandler(_ req: Request, year: SUYear) throws -> Future<SUYear> {
        
        year.timestamp = String(describing: Date())
        
        return year.save(on: req)
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[SUYear]> {
        
        return SUYear.query(on: req).all()
    }
    
    
    func getHandler(_ req: Request) throws -> Future<SUYear> {
        
        return try req.parameters.next(SUYear.self)
    }
    
    func updateHandler(_ req: Request) throws -> Future<SUYear> {
        
        return try flatMap(to: SUYear.self, req.parameters.next(SUYear.self), req.content.decode(SUYear.self)) { year, updatedYear in
            
            year.yearName = updatedYear.yearName
            year.schoolID = updatedYear.schoolID
            year.sortOrder = updatedYear.sortOrder
            year.timestamp = String(describing: Date())
            
            return year.save(on: req)
        }
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try req.parameters.next(SUYear.self).delete(on: req).transform(to: HTTPStatus.noContent)
    }
    
    // School
    func getSchoolHandler(_ req: Request) throws -> Future<SUSchool> {
        
        return try req.parameters.next(SUYear.self).flatMap(to: SUSchool.self) { year in
            
            year.school.get(on: req)
        }
    }
    
    // Items
    func getItemsHandler(_ req: Request) throws -> Future<[SUItem]> {
        
        return try req.parameters.next(SUYear.self).flatMap(to: [SUItem].self) { year in
            
            try year.items.query(on: req).all()
        }
    }
}
