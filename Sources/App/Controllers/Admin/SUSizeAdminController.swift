import Vapor
import Leaf
import Fluent
import Authentication

struct SUSizeAdminController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let authSessionRoutes = router.grouped("sizes").grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        redirectProtectedRoutes.get("create", use: createSizeHandler)
        redirectProtectedRoutes.get(use: sizesHandler)
        redirectProtectedRoutes.get(SUSize.parameter, "edit", use: editSizeHandler)
    }
    
    // CRUD handlers
    func createSizeHandler(_ req: Request) throws -> Future<View> {
        
        let user = try req.requireAuthenticated(SUUser.self)
        let context = CreateSizeContext(authenticatedUser: user)
        
        return try req.view().render("Sizes/size", context)
    }
    
    func sizesHandler(_ req: Request) throws -> Future<View> {
        
        return SUSize.query(on: req).count().flatMap(to: View.self) { totalSizesCount in
        
            // Set page increment step
            let pageIncrementStep = 15
            
            // Default to page 1 and first increment step
            var selectedSizesPerPage = pageIncrementStep
            var currentPage = 1
            var pageOffset = 0
            
            // Get selected sizes per page from cookie
            if let sizesPageTotal = req.http.cookies["sizes-per-page"] {
                selectedSizesPerPage = Int(sizesPageTotal.string)!
            }
            
            // Get current page from request
            if let pageQueryParam = req.query[Int.self, at: "page"] {
                currentPage = pageQueryParam
                pageOffset = (currentPage - 1) * selectedSizesPerPage
            }
            
            // Calculate page increment values
            let numIncrements = Int(ceil(Double(totalSizesCount) / Double(pageIncrementStep)))
            var pageIncrementValues = Array(repeating: 0, count: numIncrements)
            var incrementValue = pageIncrementStep
            pageIncrementValues = pageIncrementValues.map { _ in
                let value = incrementValue
                incrementValue += pageIncrementStep
                return value
            }
            
            return SUSize.query(on: req).sort(\.sortOrder, .ascending).range(pageOffset..<currentPage * selectedSizesPerPage).all().flatMap(to: View.self) { sizes in
            
                let numPages = Int(ceil(Double(totalSizesCount) / Double(selectedSizesPerPage)))
                var pages = [Int]()
                if numPages > 0 {
                    pages = Array(1...numPages)
                }
                
                let user = try req.requireAuthenticated(SUUser.self)
                
                let context = SizesContext(authenticatedUser: user, sizes: sizes, pages: pages, currentPage: currentPage, pageOffset: pageOffset, sizesPerPage: selectedSizesPerPage, pageIncrements: pageIncrementValues)
                
                return try req.view().render("Sizes/sizes", context)
            }
        }
    }
    
    func editSizeHandler(_ req: Request) throws -> Future<View> {
        
        return try req.parameters.next(SUSize.self).flatMap(to: View.self) { size in
            
            let user = try req.requireAuthenticated(SUUser.self)
            let context = EditSizeContext(authenticatedUser: user, size: size)
            
            return try req.view().render("Sizes/size", context)
        }
    }
    
    // Contexts
    struct CreateSizeContext: Encodable {
        let title = "Create Size"
        let authenticatedUser: SUUser
    }
    
    struct SizesContext: Encodable {
        let title = "Sizes"
        let authenticatedUser: SUUser
        let sizes: [SUSize]
        let pages: [Int]
        let currentPage: Int
        let pageOffset: Int
        let sizesPerPage: Int
        let pageIncrements: [Int]
    }
    
    struct EditSizeContext: Encodable {
        let title = "Edit Size"
        let authenticatedUser: SUUser
        let size: SUSize
        let editing = true
    }
}
