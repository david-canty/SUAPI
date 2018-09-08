import Vapor
import Fluent
import Authentication

struct SUSchoolController: RouteCollection {
    
    func boot(router: Router) throws {
        
        // CRUD
        let schoolRoutes = router.grouped("api", "schools")
        schoolRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in
            
            jwtProtectedGroup.get(use: getAllHandler)
            jwtProtectedGroup.get(SUSchool.parameter, use: getHandler)
            
            // Years
            jwtProtectedGroup.get(SUSchool.parameter, "years", use: getYearsHandler)
        }
        
        let authSessionRoutes = schoolRoutes.grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedGroup = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        redirectProtectedGroup.post(SUSchool.self, use: createHandler)
        redirectProtectedGroup.put(SUSchool.parameter, use: updateHandler)
        redirectProtectedGroup.delete(SUSchool.parameter, use: deleteHandler)
    }
    
    // CRUD
    func createHandler(_ req: Request, school: SUSchool) throws -> Future<SUSchool> {
        
        do {
            
            try school.validate()
            school.timestamp = String(describing: Date())
            
        } catch {
            
            if let validationError = error as? ValidationError {
                
                let errorString = "Error creating school:\n\n"
                var validationErrorReason = errorString
                
                if validationError.reason.contains("not larger") {
                    validationErrorReason += "School name must not be blank."
                }
                
                if validationErrorReason != errorString {
                    throw Abort(.badRequest, reason: validationErrorReason)
                }
            }
        }
        
        return school.save(on: req).catchMap { error in
            
            let errorDescription = error.localizedDescription.lowercased()
            
            switch errorDescription {
                
            case let str where str.contains("duplicate"):
                throw Abort(.conflict, reason: "Error creating school:\n\nA school with this name exists.")
                
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
            
            do {
                
                try school.validate()
                school.timestamp = String(describing: Date())
                
            } catch {
                
                if let validationError = error as? ValidationError {
                    
                    let errorString = "Error updating school:\n\n"
                    var validationErrorReason = errorString
                    
                    if validationError.reason.contains("not larger") {
                        validationErrorReason += "School name must not be blank."
                    }
                    
                    if validationErrorReason != errorString {
                        throw Abort(.badRequest, reason: validationErrorReason)
                    }
                }
            }
            
            return school.save(on: req).catchMap { error in
                
                let errorDescription = error.localizedDescription.lowercased()
                
                switch errorDescription {
                    
                case let str where str.contains("duplicate"):
                    throw Abort(.conflict, reason: "Error updating school:\n\nA school with this name exists.")
                    
                default:
                    throw Abort(.internalServerError, reason: error.localizedDescription)
                }
            }
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
