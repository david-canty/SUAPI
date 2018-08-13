import Vapor

struct SUSizeController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let sizesRoute = router.grouped("api", "sizes")
        
        // CRUD
        sizesRoute.post(SUSize.self, use: createHandler)
        sizesRoute.get(use: getAllHandler)
        sizesRoute.get(SUSize.parameter, use: getHandler)
        categoriesRoute.put(SUCategory.parameter, use: updateHandler)
        categoriesRoute.delete(SUCategory.parameter, use: deleteHandler)
        
        // Items
        sizesRoute.get(SUSize.parameter, "items", use: getItemsHandler)
    }
    
    // CRUD
    func createHandler(_ req: Request, size: SUSize) throws -> Future<SUSize> {
        
        return size.save(on: req)
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[SUSize]> {
        
        return SUSize.query(on: req).all()
    }
    
    
    func getHandler(_ req: Request) throws -> Future<SUSize> {
        
        return try req.parameters.next(SUSize.self)
    }
    
    // Items
    func getItemsHandler(_ req: Request) throws -> Future<[SUItem]> {
        
        return try req.parameters.next(SUSize.self).flatMap(to: [SUItem].self) { size in
            
            try size.items.query(on: req).all()
        }
    }
}

