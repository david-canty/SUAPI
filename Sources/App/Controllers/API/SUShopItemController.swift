import Vapor
import Fluent
import Authentication
import S3

struct SUShopItemController: RouteCollection {
    
    func boot(router: Router) throws {
        
        // CRUD
        let itemRoutes = router.grouped("api", "items")
        itemRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in
            
            jwtProtectedGroup.get(use: getAllHandler)
            jwtProtectedGroup.get(SUShopItem.parameter, use: getHandler)
            
            // Category
            jwtProtectedGroup.get(SUShopItem.parameter, "category", use: getCategoryHandler)
            
            // Sizes
            jwtProtectedGroup.get(SUShopItem.parameter, "sizes", use: getSizesHandler)
            jwtProtectedGroup.get("sizes", use: getAllItemSizesHandler)
            
            // Stock
//            jwtProtectedGroup.get(SUShopItem.parameter, "sizes", "stock", use: getSizesStockHandler)
            
            // Images
            jwtProtectedGroup.get(SUShopItem.parameter, "images", use: getImagesHandler)
            
            // Years
            jwtProtectedGroup.get(SUShopItem.parameter, "years", use: getYearsHandler)
        }
        
        let authSessionRoutes = itemRoutes.grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedGroup = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        redirectProtectedGroup.post(SUShopItemData.self, use: createHandler)
        redirectProtectedGroup.put(SUShopItem.parameter, use: updateHandler)
        redirectProtectedGroup.delete(SUShopItem.parameter, use: deleteHandler)
        
        // Sizes
        redirectProtectedGroup.post(SUShopItem.parameter, "sizes", SUSize.parameter, use: addSizeHandler)
        redirectProtectedGroup.delete(SUShopItem.parameter, "sizes", SUSize.parameter, use: deleteSizeHandler)
        
        // Stock
        redirectProtectedGroup.patch(SUShopItem.parameter, "stock", use: updateStockHandler)
        
        // Status
        redirectProtectedGroup.patch(SUShopItemStatusData.self, at: SUShopItem.parameter, "status", use: updateStatusHandler)
        
        // Images
        redirectProtectedGroup.post(SUShopItem.parameter, "images", use: uploadImagesHandler)
        redirectProtectedGroup.patch(SUShopItem.parameter, "images", SUImage.parameter, "sort-order", use: updateImageSortOrderHandler)
        redirectProtectedGroup.delete(SUShopItem.parameter, "images", SUImage.parameter, use: deleteItemImageHandler)
        
        // Years
        redirectProtectedGroup.post(SUShopItem.parameter, "years", SUYear.parameter, use: addYearHandler)
        redirectProtectedGroup.delete(SUShopItem.parameter, "years", SUYear.parameter, use: deleteYearHandler)
    }
    
    // CRUD
    func createHandler(_ req: Request, itemData: SUShopItemData) throws -> Future<SUShopItem> {
        
        let item = SUShopItem(name: itemData.itemName, description: itemData.itemDescription, color: itemData.itemColor, gender: itemData.itemGender, price: itemData.itemPrice, status: ShopItemStatus.active, categoryID: itemData.categoryId)
        
        do {
            
            try item.validate()
            item.timestamp = Date()
            
        } catch {
            
            if let validationError = error as? ValidationError {
                
                let errorString = "Error creating item:\n\n"
                var validationErrorReason = errorString
                
                if validationError.reason.contains("'itemName'") {
                    validationErrorReason += "Name must not be blank.\n\n"
                }
                
                if validationError.reason.contains("'itemColor'") {
                    validationErrorReason += "Colour must not be blank.\n\n"
                }
                
                if validationError.reason.contains("'itemGender'") {
                    validationErrorReason += "Gender must not be blank.\n\n"
                }
                
                if validationError.reason.contains("'itemPrice'") {
                    validationErrorReason += "Price must not be negative.\n\n"
                }
                
                if validationErrorReason != errorString {
                    throw Abort(.badRequest, reason: validationErrorReason)
                }
            }
        }
        
        return item.save(on: req).do() { item in
            
            for yearId in itemData.itemYears {
                
                _ = SUYear.find(yearId, on: req).unwrap(or: Abort(.internalServerError, reason: "Error finding year")).do() { year in
                    
                    _ = item.years.attach(year, on: req)
                
                }.catch() { error in
                    
                    print("Error attaching year to item: \(error)")
                }
            }
            
            for sizeId in itemData.itemSizes {
                
                _ = SUSize.find(sizeId, on: req).unwrap(or: Abort(.internalServerError, reason: "Error finding size")).do() { size in
                    
                    _ = item.sizes.attach(size, on: req)
                    
                }.catch() { error in
                        
                    print("Error attaching size to item: \(error)")
                }
            }
            
        }.catch() { error in
            
            print("Error saving item: \(error)")
        }

    }
    
    func getAllHandler(_ req: Request) throws -> Future<[SUShopItemWithRelations]> {
        
        return SUShopItem.query(on: req).all().flatMap(to: [SUShopItemWithRelations].self) { (items) -> Future<[SUShopItemWithRelations]> in

            return try items.compactMap { (item) -> Future<SUShopItemWithRelations> in

                return try item.sizes.query(on: req).all().flatMap(to: SUShopItemWithRelations.self) { (sizes) -> Future<SUShopItemWithRelations> in

                    return try item.years.query(on: req).all().flatMap(to: SUShopItemWithRelations.self) { (years) -> Future<SUShopItemWithRelations> in
                        
                        return try item.images.query(on: req).all().map(to: SUShopItemWithRelations.self) { (images) -> SUShopItemWithRelations in
                            
                            return SUShopItemWithRelations(item: item, sizes: sizes, years: years, images: images)
                        }
                    }
                }
                
            }.flatten(on: req)
        }
    }
    
    func getHandler(_ req: Request) throws -> Future<SUShopItem> {
        
        return try req.parameters.next(SUShopItem.self)
    }
    
    func updateHandler(_ req: Request) throws -> Future<SUShopItem> {
        
        return try flatMap(to: SUShopItem.self, req.parameters.next(SUShopItem.self), req.content.decode(SUShopItemData.self)) { item, updatedItemData in
            
            item.itemName = updatedItemData.itemName
            item.itemDescription = updatedItemData.itemDescription
            item.itemColor = updatedItemData.itemColor
            item.itemGender = updatedItemData.itemGender
            item.itemPrice = updatedItemData.itemPrice
            item.categoryID = updatedItemData.categoryId
            
            do {
                
                try item.validate()
                item.timestamp = Date()
                
            } catch {
                
                if let validationError = error as? ValidationError {
                    
                    let errorString = "Error updating item:\n\n"
                    var validationErrorReason = errorString
                    
                    if validationError.reason.contains("'itemName'") {
                        validationErrorReason += "Name must not be blank.\n\n"
                    }
                    
                    if validationError.reason.contains("'itemColor'") {
                        validationErrorReason += "Colour must not be blank.\n\n"
                    }
                    
                    if validationError.reason.contains("'itemGender'") {
                        validationErrorReason += "Gender must not be blank.\n\n"
                    }
                    
                    if validationError.reason.contains("'itemPrice'") {
                        validationErrorReason += "Price must not be negative.\n\n"
                    }
                    
                    if validationErrorReason != errorString {
                        throw Abort(.badRequest, reason: validationErrorReason)
                    }
                }
            }
            
            return item.update(on: req).do() { item in
                
                // Update item years
                _ = item.years.detachAll(on: req).do {
                    
                    for yearId in updatedItemData.itemYears {
                        
                        _ = SUYear.find(yearId, on: req).unwrap(or: Abort(.internalServerError, reason: "Error finding year")).do() { year in
                            
                            _ = item.years.attach(year, on: req)
                            
                            }.catch() { error in
                                
                                print("Error attaching year to item: \(error)")
                        }
                    }
                    
                }.catch() { error in
                    
                    print("Error detaching years from item: \(error)")
                }
                
                // Update item sizes
                self.updateSizesForItem(item: item, withData: updatedItemData, on: req)
                
            }.catch() { error in
                
                print("Error updating item: \(error)")
            }
        }
    }
    
    func updateSizesForItem(item: SUShopItem, withData data: SUShopItemData, on req: Request) {
     
        // Attach newly selected sizes
        _ = data.itemSizes.map { sizeId in
            
            _ = SUSize.find(sizeId, on: req).unwrap(or: Abort(.internalServerError, reason: "Error finding size")).do() { size in
                
                _ = item.sizes.isAttached(size, on: req).map { isAttached in
                    
                    if !isAttached {
                        
                        _ = item.sizes.attach(size, on: req)
                    }
                }
            }
        }
        
        // Detach deselected item sizes
        do {
            
            _ = try item.sizes.query(on: req).all().do { sizes in
                
                _ = sizes.map() { size in
                    
                    if !data.itemSizes.contains(size.id!) {
                        
                        _ = item.sizes.detach(size, on: req)
                    }
                }
            }
            
        } catch {
            
            print("Error detaching size from item")
        }
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try req.parameters.next(SUShopItem.self).delete(on: req).transform(to: HTTPStatus.noContent).catchMap() { error in
            
            let reason = error.localizedDescription
            
            switch reason {
                
            case let x where x.contains("SUOrderItem"):
                
                throw Abort(.conflict, reason: "Error deleting item:\n\nCannot delete this item because it is associated with one or more orders.")
                
            default:
                
                throw Abort(.conflict, reason: "Error deleting item:\n\n\(reason)")
            }
        }
    }
    
    // Category
    func getCategoryHandler(_ req: Request) throws -> Future<SUCategory> {
        
        return try req.parameters.next(SUShopItem.self).flatMap(to: SUCategory.self) { item in
            
            item.category.get(on: req)
        }
    }
    
    // Sizes
    func addSizeHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self,
                           req.parameters.next(SUShopItem.self),
                           req.parameters.next(SUSize.self)) { item, size in
                            
                            let pivot = try SUItemSize(item.requireID(), size.requireID())
                            return pivot.save(on: req).transform(to: .created)
                            
                            //return item.sizes.attach(size, on: req).transform(to: .created)
        }
    }
    
    func getSizesHandler(_ req: Request) throws -> Future<[SUSize]> {
        
        return try req.parameters.next(SUShopItem.self).flatMap(to: [SUSize].self) { item in
            
            return try item.sizes.query(on: req).all()
        }
    }
    
    func getAllItemSizesHandler(_ req: Request) throws -> Future<[SUItemSize]> {
        
        return SUItemSize.query(on: req).all()
    }
    
    func deleteSizeHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self,
                           req.parameters.next(SUShopItem.self),
                           req.parameters.next(SUSize.self)) { item, size in
                            
                            return item.sizes.detach(size, on: req).transform(to: HTTPStatus.noContent)
        }
    }
    
    // Stock
//    func getSizesStockHandler(_ req: Request) throws -> Future<[SUItemSize]> {
//
//        return try req.parameters.next(SUShopItem.self).flatMap(to: [SUItemSize].self) { item in
//
//            return try SUItemSize.query(on: req).filter(\SUItemSize.itemID == item.requireID()).all()
//        }
//    }
    
    func updateStockHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self, req.parameters.next(SUShopItem.self), req.content.decode(SUShopItemStockData.self)) { item, itemStockData in
            
            let itemSizeIds = itemStockData.itemSizeIds
            let itemSizeStocks = itemStockData.itemSizeStocks
            
            return SUItemSize.query(on: req).filter(\SUItemSize.id ~~ itemSizeIds).all().flatMap(to: HTTPStatus.self) { itemSizes in
                
                var itemSizeSaveResults: [Future<SUItemSize>] = []
                
                for itemSize in itemSizes {
                    let idIndex = itemSizeIds.index(of: itemSize.id!)!
                    itemSize.stock = itemSizeStocks[idIndex]
                    itemSize.timestamp = Date()
                    itemSizeSaveResults.append(itemSize.update(on: req))
                }
                
                return itemSizeSaveResults.flatten(on: req).transform(to: HTTPStatus.ok)
            }
        }
    }
    
    // Status
    func updateStatusHandler(_ req: Request, itemStatusData: SUShopItemStatusData) throws -> Future<HTTPStatus> {
        
        return try req.parameters.next(SUShopItem.self).flatMap { item in
            
            guard let itemStatus = ShopItemStatus.init(rawValue: itemStatusData.itemStatus) else {
                throw Abort(.badRequest, reason: "Invalid item status")
            }
            
            item.timestamp = Date()
            item.itemStatus = itemStatus.rawValue
            
            return item.update(on: req).transform(to: HTTPStatus.ok)
        }
    }
    
    // Images
    func uploadImagesHandler(_ req: Request) throws -> Future<[SUImage]> {
        
        return try flatMap(to: [SUImage].self, req.parameters.next(SUShopItem.self), req.content.decode(SUShopItemImageData.self)) { item, uploadedImageFiles in
            
            return try item.images.query(on: req).count().flatMap(to: [SUImage].self) { itemImageCount in
                
                var imageSaveCount = 0
                let s3Client = try req.makeS3Client()
                
                return try uploadedImageFiles.itemImages.compactMap { file -> EventLoopFuture<SUImage> in
                    
                    let imageData = file.data
                    let filename = String.randomString() + "_" + file.filename
                    let file = File.Upload(data: imageData, destination: filename, access: .publicRead)
                    
                    return try s3Client.put(file: file, on: req).flatMap(to: SUImage.self) { putResponse in
                        
                        let image = SUImage(itemID: item.id!, filename: filename)
                        image.sortOrder = itemImageCount + imageSaveCount
                        imageSaveCount += 1
                        
                        return image.save(on: req)
                        
                        }.catchMap({ error in
                            
                            throw Abort(.internalServerError, reason: "Error saving image file '\(filename)' to S3: \(error)")
                        })
                    
                }.flatten(on: req)
            }
        }
    }
    
    func getImagesHandler(_ req: Request) throws -> Future<[SUImage]> {
        
        return try req.parameters.next(SUShopItem.self).flatMap(to: [SUImage].self) { item in
            
            try item.images.query(on: req).all()
        }
    }
    
    func updateImageSortOrderHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self, req.parameters.next(SUShopItem.self), req.parameters.next(SUImage.self), req.content.decode(SUImageSortOrderData.self)) { item, image, sortOrderData in
            
            item.timestamp = Date()
            image.sortOrder = sortOrderData.sortOrder
            
            return req.transaction(on: .mysql) { conn in
             
                return item.update(on: conn).flatMap { _ in
                    
                    return image.update(on: conn)
                    
                }.transform(to: HTTPStatus.ok)
            }
        }
    }
    
    func deleteItemImageHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self, req.parameters.next(SUShopItem.self), req.parameters.next(SUImage.self)) { item, image in
            
            let s3Client = try req.makeS3Client()
            
            return try s3Client.delete(file: image, on: req).flatMap(to: HTTPStatus.self) {
                
                return req.transaction(on: .mysql) { conn in
                    
                    item.timestamp = Date()
                    return item.update(on: conn).flatMap { _ in
                        
                        return image.delete(on: conn)
                        
                        }.transform(to: HTTPStatus.noContent)
                }
                
                }.catchMap { error in
                
                throw Abort(.internalServerError, reason: "Error deleting file '\(image.filename)': \(error)")
            }
        }
    }
    
    // Years
    func addYearHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self,
                           req.parameters.next(SUShopItem.self),
                           req.parameters.next(SUYear.self)) { item, year in
                            
                            let pivot = try SUItemYear(item.requireID(), year.requireID())
                            
                            return pivot.save(on: req).transform(to: .created)
        }
    }
    
    func getYearsHandler(_ req: Request) throws -> Future<[SUYear]> {
        
        return try req.parameters.next(SUShopItem.self).flatMap(to: [SUYear].self) { item in
            
            try item.years.query(on: req).all()
        }
    }
    
    func deleteYearHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self,
                           req.parameters.next(SUShopItem.self),
                           req.parameters.next(SUYear.self)) { item, year in
                            
                            return item.years.detach(year, on: req).transform(to: HTTPStatus.noContent)
        }
    }
    
    // Data structs
    struct SUShopItemData: Content {
        
        let itemName: String
        let itemDescription: String?
        let itemGender: String
        let itemColor: String
        let itemPrice: Double
        let categoryId: UUID
        let itemYears: [UUID]
        let itemSizes: [UUID]
    }
    
    struct SUShopItemWithRelations: Content {
        let item: SUShopItem
        let sizes: [SUSize]
        let years: [SUYear]
        let images: [SUImage]
    }
    
    struct SUShopItemStockData: Content {
        let itemSizeIds: [UUID]
        let itemSizeStocks: [Int]
    }
    
    struct SUShopItemStatusData: Content {
        let itemStatus: String
    }
    
    struct SUShopItemImageData: Content {
        let itemImages: [Vapor.File]
    }
    
    struct SUImageSortOrderData: Content {
        let sortOrder: Int
    }
}

extension String {
    
    static func randomString(length: Int = 8) -> String {
        
        let base = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomStr: String = ""
        
        for _ in 0..<length {
            let randomValue = Int.random(in: 0..<base.count)
            randomStr += "\(base[base.index(base.startIndex, offsetBy: randomValue)])"
        }
        return randomStr
    }
}
