import Vapor
import Fluent

struct SUSizeController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let sizesRoute = router.grouped("api", "sizes")
        
        // CRUD
        sizesRoute.post(SUSize.self, use: createHandler)
        sizesRoute.get(use: getAllHandler)
        sizesRoute.get(SUSize.parameter, use: getHandler)
        sizesRoute.put(SUSize.parameter, use: updateHandler)
        sizesRoute.delete(SUSize.parameter, use: deleteHandler)
        
        // Items
        sizesRoute.get(SUSize.parameter, "items", use: getItemsHandler)
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
