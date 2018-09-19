import Vapor
import Leaf
import Fluent
import Authentication

struct SUItemAdminController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let authSessionRoutes = router.grouped("items").grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        redirectProtectedRoutes.get("create", use: createItemHandler)
        redirectProtectedRoutes.get(use: itemsHandler)
        redirectProtectedRoutes.get(SUItem.parameter, "edit", use: editItemHandler)
        redirectProtectedRoutes.get(SUItem.parameter, "images", use: itemImagesHandler)
        redirectProtectedRoutes.get(SUItem.parameter, "stock", use: itemStockHandler)
    }
    
    // CRUD handlers
    func createItemHandler(_ req: Request) throws -> Future<View> {
        
        return SUCategory.query(on: req).sort(\.sortOrder, .ascending).all().flatMap(to: View.self) { categories in
         
            return SUSchool.query(on: req).sort(\.sortOrder, .ascending).all().flatMap(to: View.self) { schools in
                
                var schoolYears: [EventLoopFuture<[SUYear]>] = []
                for school in schools {
                    
                    let years = try school.years.query(on: req).sort(\.sortOrder, .ascending).all()
                    schoolYears.append(years)
                }
                
                return SUSize.query(on: req).sort(\.sortOrder, .ascending).all().flatMap(to: View.self) { sizes in
                    
                    let genders = [Gender(name: "Boys", isSelected: true),
                                   Gender(name: "Girls", isSelected: false),
                                   Gender(name: "Unisex", isSelected: false)]
                    
                    let user = try req.requireAuthenticated(SUUser.self)
                    let context = CreateItemContext(authenticatedUser: user, categories: categories, genders: genders, schoolYears: schoolYears, sizes: sizes)
                    
                    return try req.view().render("item", context)
                }
            }
        }
    }
    
    func itemsHandler(_ req: Request) throws -> Future<View> {
        
        return SUCategory.query(on: req).sort(\.sortOrder, .ascending).all().flatMap(to: View.self) { categories in
            
            var categoriesAndItems = [CategoryAndItems]()
            for category in categories {
                let items = try category.items.query(on: req).all()
                let categoryAndItems = CategoryAndItems(category: category, items: items)
                categoriesAndItems.append(categoryAndItems)
            }
            
            let user = try req.requireAuthenticated(SUUser.self)
            let context = ItemsContext(authenticatedUser: user, itemsByCategory: categoriesAndItems)
            
            return try req.view().render("items", context)
        }
    }
    
    func editItemHandler(_ req: Request) throws -> Future<View> {

        return try req.parameters.next(SUItem.self).flatMap(to: View.self) { item in

            return SUCategory.query(on: req).sort(\.sortOrder, .ascending).all().flatMap(to: View.self) { categories in
                
                return SUSchool.query(on: req).sort(\.sortOrder, .ascending).all().flatMap(to: View.self) { schools in
                    
                    var schoolYears: [EventLoopFuture<[SUYear]>] = []
                    for school in schools {
                        
                        let years = try school.years.query(on: req).sort(\.sortOrder, .ascending).all()
                        schoolYears.append(years)
                    }
                    
                    let itemYears = try item.years.query(on: req).all()
                    
                    return SUSize.query(on: req).sort(\.sortOrder, .ascending).all().flatMap(to: View.self) { sizes in
                        
                        let itemSizes = try item.sizes.query(on: req).all()
                        
                        let genders = [Gender(name: "Boys", isSelected: item.itemGender == "Boys"),
                                       Gender(name: "Girls", isSelected: item.itemGender == "Girls"),
                                       Gender(name: "Unisex", isSelected: item.itemGender == "Unisex")]
                        
                        let user = try req.requireAuthenticated(SUUser.self)
                        let context = EditItemContext(authenticatedUser: user, item: item, categories: categories, genders: genders, schoolYears: schoolYears, selectedYears: itemYears, sizes: sizes, selectedSizes: itemSizes)
                        
                        return try req.view().render("item", context)
                    }
                }
            }
        }
    }
    
    // Images
    func itemImagesHandler(_ req: Request) throws -> Future<View> {

        return try req.parameters.next(SUItem.self).flatMap(to: View.self) { item in
            
            return try item.images.query(on: req).sort(\.sortOrder, .ascending).all().flatMap(to: View.self) { images in
                
                let user = try req.requireAuthenticated(SUUser.self)
                let context = ItemImagesContext(authenticatedUser: user, item: item, images: images)
                return try req.view().render("itemImages", context)
            }
        }
    }
    
    // Stock
    func itemStockHandler(_ req: Request) throws -> Future<View> {
        
        return try req.parameters.next(SUItem.self).flatMap(to: View.self) { item in
            
            return try SUItemSize.query(on: req).filter(\.itemID == item.requireID()).all().flatMap(to: View.self) { itemSizes in
                
                return try item.siblings(related: SUSize.self, through: SUItemSize.self).query(on: req).sort(\.sortOrder, .ascending).all().flatMap(to: View.self) { sizes in
                    
                    var itemSizesWithSizes = [ItemSizeWithSize]()
                    for size in sizes {
                     
                        let itemSize = itemSizes.filter{ $0.sizeID == size.id }.first
                        let itemSizeWithSize = ItemSizeWithSize(itemSize: itemSize!, size: size)
                        itemSizesWithSizes.append(itemSizeWithSize)
                    }
                    
                    let user = try req.requireAuthenticated(SUUser.self)
                    let context = ItemStockContext(authenticatedUser: user, item: item, itemSizesWithSizes: itemSizesWithSizes)
                    return try req.view().render("itemStock", context)    
                }
            }
        }
    }
    
    // Contexts
    struct CreateItemContext: Encodable {
        let title = "Create Item"
        let authenticatedUser: SUUser
        let categories: [SUCategory]
        let genders: [Gender]
        let schoolYears: [EventLoopFuture<[SUYear]>]
        let sizes: [SUSize]
    }
    
    struct Gender: Encodable {
        let name: String
        let isSelected: Bool
    }
    
    struct ItemsContext: Encodable {
        let title = "Items"
        let authenticatedUser: SUUser
        let itemsByCategory: [CategoryAndItems]
    }
    
    struct CategoryAndItems: Encodable {
        let category: SUCategory
        let items: EventLoopFuture<[SUItem]>
    }
    
    struct EditItemContext: Encodable {
        let title = "Edit Item"
        let authenticatedUser: SUUser
        let editing = true
        let item: SUItem
        let categories: [SUCategory]
        let genders: [Gender]
        let schoolYears: [EventLoopFuture<[SUYear]>]
        let selectedYears: EventLoopFuture<[SUYear]>
        let sizes: [SUSize]
        let selectedSizes: EventLoopFuture<[SUSize]>
    }
    
    struct ItemImagesContext: Encodable {
        let title = "Item Images"
        let authenticatedUser: SUUser
        let item: SUItem
        let images: [SUImage]
    }
    
    struct ItemStockContext: Encodable {
        let title = "Item Stock"
        let authenticatedUser: SUUser
        let item: SUItem
        let itemSizesWithSizes: [ItemSizeWithSize]
    }
    
    struct ItemSizeWithSize: Encodable {
        let itemSize: SUItemSize
        let size: SUSize
    }
}
