import Vapor
import Leaf
import Fluent
import Authentication

struct SUItemAdminController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let authSessionRoutes = router.grouped("categories").grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        redirectProtectedRoutes.get("create", use: createCategoryHandler)
        redirectProtectedRoutes.get(use: categoriesHandler)
        redirectProtectedRoutes.get(SUCategory.parameter, "edit", use: editCategoryHandler)
    }
    
    // CRUD handlers
    func createCategoryHandler(_ req: Request) throws -> Future<View> {
        
        let user = try req.requireAuthenticated(SUUser.self)
        let context = CreateCategoryContext(authenticatedUser: user)
        
        return try req.view().render("category", context)
    }
    
    func categoriesHandler(_ req: Request) throws -> Future<View> {
        
        return SUCategory.query(on: req).sort(\.sortOrder, .ascending).all().flatMap(to: View.self) { categories in
            
            let user = try req.requireAuthenticated(SUUser.self)
            let context = CategoriesContext(authenticatedUser: user, categories: categories)
            
            return try req.view().render("categories", context)
        }
    }
    
    func editCategoryHandler(_ req: Request) throws -> Future<View> {
        
        return try req.parameters.next(SUCategory.self).flatMap(to: View.self) { category in
            
            let user = try req.requireAuthenticated(SUUser.self)
            let context = EditCategoryContext(authenticatedUser: user, category: category)
            
            return try req.view().render("category", context)
        }
    }
    
    // Contexts
    struct CreateCategoryContext: Encodable {
        let title = "Create Category"
        let authenticatedUser: SUUser
    }
    
    struct CategoriesContext: Encodable {
        let title = "Categories"
        let authenticatedUser: SUUser
        let categories: [SUCategory]
    }
    
    struct EditCategoryContext: Encodable {
        let title = "Edit Category"
        let authenticatedUser: SUUser
        let category: SUCategory
        let editing = true
    }
}
