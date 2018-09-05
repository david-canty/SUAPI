import Vapor
import Fluent
import Authentication

struct SUCategoryController: RouteCollection {
    
    func boot(router: Router) throws {
        
        // CRUD
        let categoryRoutes = router.grouped("api", "categories")
        categoryRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in
            
            jwtProtectedGroup.get(use: getAllHandler)
            jwtProtectedGroup.get(SUCategory.parameter, use: getHandler)
            
            // Items
            jwtProtectedGroup.get(SUCategory.parameter, "items", use: getItemsHandler)
        }
        
        let authSessionRoutes = categoryRoutes.grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedGroup = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        redirectProtectedGroup.post(SUCategory.self, use: createHandler)
        redirectProtectedGroup.put(SUCategory.parameter, use: updateHandler)
        redirectProtectedGroup.delete(SUCategory.parameter, use: deleteHandler)
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
