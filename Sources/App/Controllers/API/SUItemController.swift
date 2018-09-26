import Vapor
import Fluent
import Authentication
import S3

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
        
        redirectProtectedGroup.post(SUItemData.self, use: createHandler)
        redirectProtectedGroup.put(SUItem.parameter, use: updateHandler)
        redirectProtectedGroup.delete(SUItem.parameter, use: deleteHandler)
        
        // Sizes
        redirectProtectedGroup.post(SUItem.parameter, "sizes", SUSize.parameter, use: addSizeHandler)
        redirectProtectedGroup.delete(SUItem.parameter, "sizes", SUSize.parameter, use: deleteSizeHandler)
        
        // Images
        redirectProtectedGroup.post(SUItem.parameter, "images", use: uploadImagesHandler)
        redirectProtectedGroup.patch(SUItem.parameter, "images", SUImage.parameter, "sort-order", use: updateImageSortOrderHandler)
        redirectProtectedGroup.delete(SUItem.parameter, "images", SUImage.parameter, use: deleteItemImageHandler)
        
        // Stock
        redirectProtectedGroup.patch(SUItem.parameter, "stock", use: updateStockHandler)
        
        // Years
        redirectProtectedGroup.post(SUItem.parameter, "years", SUYear.parameter, use: addYearHandler)
        redirectProtectedGroup.delete(SUItem.parameter, "years", SUYear.parameter, use: deleteYearHandler)
    }
    
    // CRUD
    func createHandler(_ req: Request, itemData: SUItemData) throws -> Future<SUItem> {
        
        let item = SUItem(name: itemData.itemName, description: itemData.itemDescription, color: itemData.itemColor, gender: itemData.itemGender, price: itemData.itemPrice, categoryID: itemData.categoryId)
        
        do {
            
            try item.validate()
            item.timestamp = String(describing: Date())
            
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
    
    func getAllHandler(_ req: Request) throws -> Future<[SUItem]> {
        
        return SUItem.query(on: req).all()
    }
    
    func getHandler(_ req: Request) throws -> Future<SUItem> {
        
        return try req.parameters.next(SUItem.self)
    }
    
    func updateHandler(_ req: Request) throws -> Future<SUItem> {
        
        return try flatMap(to: SUItem.self, req.parameters.next(SUItem.self), req.content.decode(SUItemData.self)) { item, updatedItemData in
            
            item.itemName = updatedItemData.itemName
            item.itemDescription = updatedItemData.itemDescription
            item.itemColor = updatedItemData.itemColor
            item.itemGender = updatedItemData.itemGender
            item.itemPrice = updatedItemData.itemPrice
            item.categoryID = updatedItemData.categoryId
            
            do {
                
                try item.validate()
                item.timestamp = String(describing: Date())
                
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
                
                _ = item.sizes.detachAll(on: req).do {
                
                    for sizeId in updatedItemData.itemSizes {
                        
                        _ = SUSize.find(sizeId, on: req).unwrap(or: Abort(.internalServerError, reason: "Error finding size")).do() { size in
                            
                            _ = item.sizes.attach(size, on: req)
                            
                            }.catch() { error in
                                
                                print("Error attaching size to item: \(error)")
                        }
                    }
                    
                }.catch() { error in
                    
                    print("Error detaching sizes from item: \(error)")
                }
                
            }.catch() { error in
                
                print("Error updating item: \(error)")
            }
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
    
    // Images
    func uploadImagesHandler(_ req: Request) throws -> Future<[SUImage]> {
        
        return try flatMap(to: [SUImage].self, req.parameters.next(SUItem.self), req.content.decode(SUItemImageData.self)) { item, imageFiles in

            return try item.images.query(on: req).count().flatMap(to: [SUImage].self) { itemImageCount in
                
                var imageSaveResults: [Future<SUImage>] = []
                let s3 = try req.makeS3Client()
                
                for file in imageFiles.itemImages {
                    
                    let imageData = file.data
                    let filename = String.randomString() + "_" + file.filename
                    let s3FileUpload = File.Upload(data: imageData, destination: filename)
                    
                    //var filePUTResponses: [EventLoopFuture<File.Response>] = []
                    try s3.put(file: s3FileUpload, on: req)

                    let image = SUImage(itemID: item.id!, imageFilename: filename)
                    image.sortOrder = itemImageCount + imageSaveResults.count
                    imageSaveResults.append(image.save(on: req))
                }
                
                return imageSaveResults.flatten(on: req)
            }
        }
    }
    
    func updateImageSortOrderHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self, req.parameters.next(SUItem.self), req.parameters.next(SUImage.self), req.content.decode(SUImageSortOrderData.self)) { item, image, sortOrderData in
            
            image.sortOrder = sortOrderData.sortOrder
            return image.update(on: req).transform(to: HTTPStatus.ok)
        }
    }
    
    func deleteItemImageHandler(_ req: Request) throws -> Future<HTTPStatus> {
        
        return try flatMap(to: HTTPStatus.self, req.parameters.next(SUItem.self), req.parameters.next(SUImage.self)) { item, image in
            
            let fileManager = FileManager()
            let dirConfig = DirectoryConfig.detect()
            let imageDir = dirConfig.workDir + "Public/images"
            let filename = image.imageFilename
            let imageDirWithFilename = imageDir + "/\(filename)"
            
            do {
                try fileManager.removeItem(atPath: imageDirWithFilename)
            } catch {
                print("Error removing item image file: \(error)")
            }
            
            return image.delete(on: req).transform(to: HTTPStatus.noContent)
        }
    }
    
    // Stock
    func updateStockHandler(_ req: Request) throws -> Future<HTTPStatus> {
    
        return try flatMap(to: HTTPStatus.self, req.parameters.next(SUItem.self), req.content.decode(SUItemStockData.self)) { item, itemSizeStockData in
            
            let itemSizeIds = itemSizeStockData.itemSizeIds
            let itemSizeStocks = itemSizeStockData.itemSizeStocks
            
            return SUItemSize.query(on: req).filter(\SUItemSize.id ~~ itemSizeIds).all().flatMap(to: HTTPStatus.self) { itemSizes in
                
                var itemSizeSaveResults: [Future<SUItemSize>] = []
                
                for itemSize in itemSizes {
                    let idIndex = itemSizeIds.index(of: itemSize.id!)!
                    itemSize.itemSizeStock = itemSizeStocks[idIndex]
                    itemSizeSaveResults.append(itemSize.update(on: req))
                }
                
                return itemSizeSaveResults.flatten(on: req).transform(to: HTTPStatus.ok)
            }
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
    
    // Data structs
    struct SUItemData: Content {
        
        let itemName: String
        let itemDescription: String?
        let itemGender: String
        let itemColor: String
        let itemPrice: Double
        let categoryId: UUID
        let itemYears: [UUID]
        let itemSizes: [UUID]
    }
    
    struct SUItemStockData: Content {
        let itemSizeIds: [UUID]
        let itemSizeStocks: [Int]
    }
    
    struct SUItemImageData: Content {
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
