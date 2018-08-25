import Vapor
import Fluent

struct SUCategoryController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let categoriesRoute = router.grouped("api", "categories")
        
        // CRUD
        categoriesRoute.post(SUCategory.self, use: createHandler)
        categoriesRoute.get(use: getAllHandler)
        categoriesRoute.get(SUCategory.parameter, use: getHandler)
        categoriesRoute.put(SUCategory.parameter, use: updateHandler)
        categoriesRoute.delete(SUCategory.parameter, use: deleteHandler)
        
        // Items
        categoriesRoute.get(SUCategory.parameter, "items", use: getItemsHandler)
    }
    
    // CRUD
    func createHandler(_ req: Request, category: SUCategory) throws -> Future<SUCategory> {
        
        category.timestamp = String(describing: Date())
        
        return category.save(on: req)
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[SUCategory]> {
        
        return SUCategory.query(on: req).all()
    }
    
    func getHandler(_ req: Request) throws -> Future<SUCategory> {
        
        return try req.parameters.next(SUCategory.self)
    }
    
    func updateHandler(_ req: Request) throws -> Future<SUCategory> {
        
        return try flatMap(to: SUCategory.self, req.parameters.next(SUCategory.self), req.content.decode(SUCategory.self)) { category, updatedCategory in
            
            category.categoryName = updatedCategory.categoryName
            category.sortOrder = updatedCategory.sortOrder
            category.timestamp = String(describing: Date())
            
            return category.save(on: req)
        }
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try req.parameters.next(SUCategory.self).delete(on: req).transform(to: HTTPStatus.noContent)
    }
    
    // Items
    func getItemsHandler(_ req: Request) throws -> Future<[SUItem]> {
        
        return try req.parameters.next(SUCategory.self).flatMap(to: [SUItem].self) { category in
            
            try category.items.query(on: req).all()
        }
    }
}
