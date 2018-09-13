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
        //redirectProtectedRoutes.get(SUItem.parameter, "edit", use: editItemHandler)
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
    
//    func editCategoryHandler(_ req: Request) throws -> Future<View> {
//
//        return try req.parameters.next(SUCategory.self).flatMap(to: View.self) { category in
//
//            let user = try req.requireAuthenticated(SUUser.self)
//            let context = EditCategoryContext(authenticatedUser: user, category: category)
//
//            return try req.view().render("category", context)
//        }
//    }
    
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
        let selectedYears: [UUID]
        let sizes: [SUSize]
        let selectedSizes: [UUID]
    }
}
