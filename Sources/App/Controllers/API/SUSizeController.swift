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
        redirectProtectedGroup.patch(SUSize.parameter, "sort-order", use: updateSortOrderHandler)
        redirectProtectedGroup.delete(SUSize.parameter, use: deleteHandler)
    }
    
    // CRUD
    func createHandler(_ req: Request, size: SUSize) throws -> Future<SUSize> {
        
        do {
            
            try size.validate()
            size.timestamp = Date()
            
        } catch {
            
            if let validationError = error as? ValidationError {
                
                let errorString = "Error creating size:\n\n"
                var validationErrorReason = errorString
                
                if validationError.reason.contains("not larger") {
                    validationErrorReason += "Size name must not be blank."
                }
                
                if validationErrorReason != errorString {
                    throw Abort(.badRequest, reason: validationErrorReason)
                }
            }
        }
        
        return SUSize.query(on: req).count().flatMap(to: SUSize.self) { sizeCount in
            
            size.sortOrder = sizeCount
            
            return size.save(on: req).catchMap { error in
                
                let errorDescription = error.localizedDescription.lowercased()
                
                switch errorDescription {
                    
                case let str where str.contains("duplicate"):
                    throw Abort(.conflict, reason: "Error creating size:\n\nA size with this name exists.")
                    
                default:
                    throw Abort(.internalServerError, reason: error.localizedDescription)
                }
            }
        }
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
            
            do {
                
                try size.validate()
                size.timestamp = Date()
                
            } catch {
                
                if let validationError = error as? ValidationError {
                    
                    let errorString = "Error updating size:\n\n"
                    var validationErrorReason = errorString
                    
                    if validationError.reason.contains("not larger") {
                        validationErrorReason += "Size name must not be blank."
                    }
                    
                    if validationErrorReason != errorString {
                        throw Abort(.badRequest, reason: validationErrorReason)
                    }
                }
            }
            
            return size.update(on: req).catchMap { error in
                
                let errorDescription = error.localizedDescription.lowercased()
                
                switch errorDescription {
                    
                case let str where str.contains("duplicate"):
                    throw Abort(.conflict, reason: "Error updating size:\n\nA size with this name exists.")
                    
                default:
                    throw Abort(.internalServerError, reason: error.localizedDescription)
                }
            }
        }
    }
    
    func updateSortOrderHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self, req.parameters.next(SUSize.self), req.content.decode(SUSizeSortOrderData.self)) { size, sortOrderData in
            
            if size.sortOrder != sortOrderData.sortOrder {
                
                size.timestamp = Date()
                size.sortOrder = sortOrderData.sortOrder
                
                return size.update(on: req).transform(to: HTTPStatus.ok)
            }
            
            return req.future(HTTPStatus.ok)
        }
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try req.parameters.next(SUSize.self).flatMap(to: HTTPStatus.self) { size in
            
            return req.transaction(on: .mysql) { conn in
                
                let deletedSizeSortOrder = size.sortOrder!
                
                return SUSize.query(on: conn).filter(\.sortOrder > deletedSizeSortOrder).sort(\.sortOrder, .ascending).all().flatMap(to: HTTPStatus.self) { sizesAfterDeleted in
                    
                    var sizesAfterDeletedSaveResults: [Future<SUSize>] = []
                    
                    for sizeAfter in sizesAfterDeleted {
                        
                        sizeAfter.timestamp = Date()
                        sizeAfter.sortOrder = sizeAfter.sortOrder! - 1
                        
                        sizesAfterDeletedSaveResults.append(sizeAfter.update(on: conn))
                    }
                    
                    return sizesAfterDeletedSaveResults.flatten(on: conn).flatMap(to: HTTPStatus.self) { _ in
                        
                        size.delete(on: conn).transform(to: HTTPStatus.noContent).catchMap() { error in
                            
                            let reason = error.localizedDescription
                            
                            switch reason {
                                
                            case let x where x.contains("SUOrderItem"):
                                
                                throw Abort(.conflict, reason: "Error deleting size:\n\nCannot delete this size because it is associated with one or more orders.")
                                
                            case let x where x.contains("SUShopItem"):
                                
                                throw Abort(.conflict, reason: "Error deleting size:\n\nCannot delete this size because it is associated with one or more items.")
                                
                            default:
                                
                                throw Abort(.conflict, reason: "Error deleting size:\n\n\(reason)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Items
    func getItemsHandler(_ req: Request) throws -> Future<[SUShopItem]> {
        
        return try req.parameters.next(SUSize.self).flatMap(to: [SUShopItem].self) { size in
            
            try size.items.query(on: req).all()
        }
    }
    
    // Data structs
    struct SUSizeSortOrderData: Content {
        let sortOrder: Int
    }
}
