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
        redirectProtectedGroup.patch(SUCategory.parameter, "sort-order", use: updateSortOrderHandler)
        redirectProtectedGroup.delete(SUCategory.parameter, use: deleteHandler)
    }
    
    // CRUD
    func createHandler(_ req: Request, category: SUCategory) throws -> Future<SUCategory> {
        
        do {
            
            try category.validate()
            category.timestamp = Date()
            
        } catch {
            
            if let validationError = error as? ValidationError {
                
                let errorString = "Error creating category:\n\n"
                var validationErrorReason = errorString
                
                if validationError.reason.contains("not larger") {
                    validationErrorReason += "Category name must not be blank."
                }
                
                if validationErrorReason != errorString {
                    throw Abort(.badRequest, reason: validationErrorReason)
                }
            }
        }
        
        return SUCategory.query(on: req).count().flatMap(to: SUCategory.self) { categoryCount in
            
            category.sortOrder = categoryCount
            
            return category.save(on: req).catchMap { error in
                
                let errorDescription = error.localizedDescription.lowercased()
                
                switch errorDescription {
                    
                case let str where str.contains("duplicate"):
                    throw Abort(.conflict, reason: "Error creating category:\n\nA category with this name exists.")
                    
                default:
                    throw Abort(.internalServerError, reason: error.localizedDescription)
                }
            }
        }
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
            
            do {
                
                try category.validate()
                category.timestamp = Date()
                
            } catch {
                
                if let validationError = error as? ValidationError {
                    
                    let errorString = "Error updating category:\n\n"
                    var validationErrorReason = errorString
                    
                    if validationError.reason.contains("not larger") {
                        validationErrorReason += "Category name must not be blank."
                    }
                    
                    if validationErrorReason != errorString {
                        throw Abort(.badRequest, reason: validationErrorReason)
                    }
                }
            }
            
            return category.update(on: req).catchMap { error in
                
                let errorDescription = error.localizedDescription.lowercased()
                
                switch errorDescription {
                    
                case let str where str.contains("duplicate"):
                    throw Abort(.conflict, reason: "Error updating category:\n\nA category with this name exists.")
                    
                default:
                    throw Abort(.internalServerError, reason: error.localizedDescription)
                }
            }
        }
    }
    
    func updateSortOrderHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self, req.parameters.next(SUCategory.self), req.content.decode(SUCategorySortOrderData.self)) { category, sortOrderData in
            
            if category.sortOrder != sortOrderData.sortOrder {
                
                category.timestamp = Date()
                category.sortOrder = sortOrderData.sortOrder
                
                return category.update(on: req).transform(to: HTTPStatus.ok)
            }
            
            return req.future(HTTPStatus.ok)
        }
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try req.parameters.next(SUCategory.self).delete(on: req).transform(to: HTTPStatus.noContent).catchMap() { error in
                
            throw Abort(.conflict, reason: "Error deleting category:\n\nCannot delete this category because it contains uniform items. If you wish to delete this category, assign the related uniform items to another category.")
        }
    }
    
    // Items
    func getItemsHandler(_ req: Request) throws -> Future<[SUShopItem]> {
        
        return try req.parameters.next(SUCategory.self).flatMap(to: [SUShopItem].self) { category in
            
            try category.items.query(on: req).all()
        }
    }
    
    // Data structs
    struct SUCategorySortOrderData: Content {
        let sortOrder: Int
    }
}
