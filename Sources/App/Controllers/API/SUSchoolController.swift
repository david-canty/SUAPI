import Vapor
import Fluent

struct SUSchoolController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let schoolsRoute = router.grouped("api", "schools")
        
        // CRUD
        schoolsRoute.post(SUSchool.self, use: createHandler)
        schoolsRoute.get(use: getAllHandler)
        schoolsRoute.get(SUSchool.parameter, use: getHandler)
        schoolsRoute.put(SUSchool.parameter, use: updateHandler)
        schoolsRoute.delete(SUSchool.parameter, use: deleteHandler)
        
        // Years
        schoolsRoute.get(SUSchool.parameter, "years", use: getYearsHandler)
    }
    
    // CRUD
    func createHandler(_ req: Request, school: SUSchool) throws -> Future<SUSchool> {
        
        school.timestamp = String(describing: Date())
        
        do {
            
            try school.validate()
            
        } catch {
            
            if let validationError = error as? ValidationError {
                
                if validationError.reason.contains("not larger than 1") {
                
                    throw Abort(.conflict, reason: "School name cannot be blank.")
                }
            }
        }
        
        return school.save(on: req).catchMap { error in
            
            let errorDescription = error.localizedDescription.lowercased()
            
            switch errorDescription {
                
            case let str where str.contains("duplicate"):
                throw Abort(.conflict, reason: "A school with this name exists.")
                
            default:
                throw Abort(.internalServerError, reason: error.localizedDescription)
            }
        }
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[SUSchool]> {
        
        return SUSchool.query(on: req).all()
    }
    
    func getHandler(_ req: Request) throws -> Future<SUSchool> {
        
        return try req.parameters.next(SUSchool.self)
    }
    
    func updateHandler(_ req: Request) throws -> Future<SUSchool> {
        
        return try flatMap(to: SUSchool.self, req.parameters.next(SUSchool.self), req.content.decode(SUSchool.self)) { school, updatedSchool in
            
            school.schoolName = updatedSchool.schoolName
            school.sortOrder = updatedSchool.sortOrder
            school.timestamp = String(describing: Date())
            
            return school.save(on: req)
        }
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try req.parameters.next(SUSchool.self).delete(on: req).transform(to: HTTPStatus.noContent)
    }
    
    // Years
    func getYearsHandler(_ req: Request) throws -> Future<[SUYear]> {
        
        return try req.parameters.next(SUSchool.self).flatMap(to: [SUYear].self) { school in
            
            try school.years.query(on: req).all()
        }
    }
}
