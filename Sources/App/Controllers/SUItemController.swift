import Vapor
import Fluent

struct SUItemController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let itemsRoute = router.grouped("api", "items")
        
        // CRUD
        itemsRoute.post(SUItem.self, use: createHandler)
        itemsRoute.get(use: getAllHandler)
        itemsRoute.get(SUItem.parameter, use: getHandler)
        itemsRoute.put(SUItem.parameter, use: updateHandler)
        itemsRoute.delete(SUItem.parameter, use: deleteHandler)
        
        // Category
        itemsRoute.get(SUItem.parameter, "category", use: getCategoryHandler)
        
        // Sizes
        itemsRoute.post(SUItem.parameter, "sizes", SUSize.parameter, use: addSizeHandler)
        itemsRoute.get(SUItem.parameter, "sizes", use: getSizesHandler)
        itemsRoute.delete(SUItem.parameter, "sizes", SUSize.parameter, use: deleteSizeHandler)
        
        // Years
        itemsRoute.post(SUItem.parameter, "years", SUYear.parameter, use: addYearHandler)
        itemsRoute.get(SUItem.parameter, "years", use: getYearsHandler)
        itemsRoute.delete(SUItem.parameter, "years", SUYear.parameter, use: deleteYearHandler)
    }
    
    // CRUD
    func createHandler(_ req: Request, item: SUItem) throws -> Future<SUItem> {
        
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
                            
                            return pivot.save(on: req).transform(to: .created)
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
    
    // Years
    func addYearHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self,
                           req.parameters.next(SUItem.self),
                           req.parameters.next(SUYear.self)) { item, year in
                            
                            let pivot = try SUItemYear(item.requireID(), year.requireID())
                            
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
