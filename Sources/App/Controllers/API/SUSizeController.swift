import Vapor
import Fluent
import Authentication

struct SUSizeController: RouteCollection {
    
    func boot(router: Router) throws {
        
        // CRUD
        let sizeRoutes = router.grouped("api", "sizes")
        sizeRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in
            
            jwtProtectedGroup.get(use: getAllHandler)
            jwtProtectedGroup.get(SUSize.parameter, use: getHandler)
            
            // Items
            jwtProtectedGroup.get(SUSize.parameter, "items", use: getItemsHandler)
        }
        
        let authSessionRoutes = sizeRoutes.grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedGroup = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        redirectProtectedGroup.post(SUSize.self, use: createHandler)
        redirectProtectedGroup.put(SUSize.parameter, use: updateHandler)
        redirectProtectedGroup.delete(SUSize.parameter, use: deleteHandler)
    }
    
    // CRUD
    func createHandler(_ req: Request, size: SUSize) throws -> Future<SUSize> {
        
        size.timestamp = String(describing: Date())
        
        return size.save(on: req)
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[SUSize]> {
        
        return SUSize.query(on: req).all()
    }
    
    
    func getHandler(_ req: Request) throws -> Future<SUSize> {
        
        return try req.parameters.next(SUSize.self)
    }
    
    func updateHandler(_ req: Request) throws -> Future<SUSize> {
        
        return try flatMap(to: SUSize.self, req.parameters.next(SUSize.self), req.content.decode(SUSize.self)) { size, updatedSize in
            
            size.sizeName = updatedSize.sizeName
            size.timestamp = String(describing: Date())
            
            return size.save(on: req)
        }
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try req.parameters.next(SUSize.self).delete(on: req).transform(to: HTTPStatus.noContent)
    }
    
    // Items
    func getItemsHandler(_ req: Request) throws -> Future<[SUItem]> {
        
        return try req.parameters.next(SUSize.self).flatMap(to: [SUItem].self) { size in
            
            try size.items.query(on: req).all()
        }
    }
}
