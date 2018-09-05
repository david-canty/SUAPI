import Vapor
import Fluent
import Authentication

struct SUItemController: RouteCollection {
    
    func boot(router: Router) throws {
        
        // CRUD
        let itemRoutes = router.grouped("api", "items")
        itemRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in
            
            jwtProtectedGroup.get(use: getAllHandler)
            jwtProtectedGroup.get(SUItem.parameter, use: getHandler)
            
            // Category
            jwtProtectedGroup.get(SUItem.parameter, "category", use: getCategoryHandler)
            
            // Sizes
            jwtProtectedGroup.get(SUItem.parameter, "sizes", use: getSizesHandler)
            
            // Years
            jwtProtectedGroup.get(SUItem.parameter, "years", use: getYearsHandler)
        }
        
        let authSessionRoutes = itemRoutes.grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedGroup = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        redirectProtectedGroup.post(SUItem.self, use: createHandler)
        redirectProtectedGroup.put(SUItem.parameter, use: updateHandler)
        redirectProtectedGroup.delete(SUItem.parameter, use: deleteHandler)
        
        // Sizes
        redirectProtectedGroup.post(SUItem.parameter, "sizes", SUSize.parameter, use: addSizeHandler)
        redirectProtectedGroup.delete(SUItem.parameter, "sizes", SUSize.parameter, use: deleteSizeHandler)
        
        // Stock
        redirectProtectedGroup.put(SUItem.parameter, "sizes", SUSize.parameter, "stock", Int.parameter, use: updateStockHandler)
        
        // Years
        redirectProtectedGroup.post(SUItem.parameter, "years", SUYear.parameter, use: addYearHandler)
        redirectProtectedGroup.delete(SUItem.parameter, "years", SUYear.parameter, use: deleteYearHandler)
    }
    
    // CRUD
    func createHandler(_ req: Request, item: SUItem) throws -> Future<SUItem> {
        
        item.timestamp = String(describing: Date())
        
        return item.save(on: req)
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[SUItem]> {
        
        return SUItem.query(on: req).all()
    }
    
    func getHandler(_ req: Request) throws -> Future<SUItem> {
        
        return try req.parameters.next(SUItem.self)
    }
    
    func updateHandler(_ req: Request) throws -> Future<SUItem> {
        
        return try flatMap(to: SUItem.self, req.parameters.next(SUItem.self), req.content.decode(SUItem.self)) { item, updatedItem in
            
            item.itemName = updatedItem.itemName
            item.itemDescription = updatedItem.itemDescription
            item.itemColor = updatedItem.itemColor
            item.itemGender = updatedItem.itemGender
            item.itemPrice = updatedItem.itemPrice
            item.itemImage = updatedItem.itemImage
            item.categoryID = updatedItem.categoryID
            item.timestamp = String(describing: Date())
            
            return item.save(on: req)
        }
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try req.parameters.next(SUItem.self).delete(on: req).transform(to: HTTPStatus.noContent)
    }
    
    // Category
    func getCategoryHandler(_ req: Request) throws -> Future<SUCategory> {
        
        return try req.parameters.next(SUItem.self).flatMap(to: SUCategory.self) { item in
            
            item.category.get(on: req)
        }
    }
    
    // Sizes
    func addSizeHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self,
                           req.parameters.next(SUItem.self),
                           req.parameters.next(SUSize.self)) { item, size in
                            
                            let pivot = try SUItemSize(item.requireID(), size.requireID())
                            pivot.timestamp = String(describing: Date())
                            return pivot.save(on: req).transform(to: .created)
                            
                            //return item.sizes.attach(size, on: req).transform(to: .created)
        }
    }
    
    func getSizesHandler(_ req: Request) throws -> Future<[SUSize]> {
        
        return try req.parameters.next(SUItem.self).flatMap(to: [SUSize].self) { item in
            
            try item.sizes.query(on: req).all()
        }
    }
    
    func deleteSizeHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self,
                           req.parameters.next(SUItem.self),
                           req.parameters.next(SUSize.self)) { item, size in
                            
                            return item.sizes.detach(size, on: req).transform(to: HTTPStatus.noContent)
        }
    }
    
    // Stock
    func updateStockHandler(_ req: Request) throws -> Future<HTTPStatus> {
    
        return try flatMap(to: HTTPStatus.self, req.parameters.next(SUItem.self), req.parameters.next(SUSize.self)) { item, size in
                            
            let stock = try req.parameters.next(Int.self)
            
            let pivot = try SUItemSize.query(on: req)
                .filter(\.itemID == item.requireID())
                .filter(\.sizeID == size.requireID())
                .first()
            
            return pivot.flatMap(to: HTTPStatus.self) { itemSize in
                
                itemSize?.itemSizeStock = stock
                itemSize?.timestamp = String(describing: Date())
                
                return (itemSize?.save(on: req).transform(to: HTTPStatus.ok))!
            }
        }
    }
    
    // Years
    func addYearHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self,
                           req.parameters.next(SUItem.self),
                           req.parameters.next(SUYear.self)) { item, year in
                            
                            let pivot = try SUItemYear(item.requireID(), year.requireID())
                            pivot.timestamp = String(describing: Date())
                            
                            return pivot.save(on: req).transform(to: .created)
        }
    }
    
    func getYearsHandler(_ req: Request) throws -> Future<[SUYear]> {
        
        return try req.parameters.next(SUItem.self).flatMap(to: [SUYear].self) { item in
            
            try item.years.query(on: req).all()
        }
    }
    
    func deleteYearHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self,
                           req.parameters.next(SUItem.self),
                           req.parameters.next(SUYear.self)) { item, year in
                            
                            return item.years.detach(year, on: req).transform(to: HTTPStatus.noContent)
        }
    }
}
