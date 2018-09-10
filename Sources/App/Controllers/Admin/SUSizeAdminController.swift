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
        
        return try req.view().render("size", context)
    }
    
    func sizesHandler(_ req: Request) throws -> Future<View> {
        
        return SUSize.query(on: req).count().flatMap(to: View.self) { totalSizesCount in
        
            var currentPage = 1
            var cursorOffset = 0
            var sizesPerPage = "2"
            var cursorLimit = 2
            
            if let sizesPageTotal = req.http.cookies["sizes-per-page"] {
                
                sizesPerPage = sizesPageTotal.string
                
                switch sizesPerPage {
                case let x where x == "All":
                    cursorLimit = totalSizesCount
                default:
                    cursorLimit = Int(sizesPageTotal.string)!
                }
            }
            
            if let pageQueryParam = req.query[Int.self, at: "page"] {
                
                currentPage = pageQueryParam
                cursorOffset = (currentPage - 1) * cursorLimit
            }
            
            return SUSize.query(on: req).sort(\.sortOrder, .ascending).range(cursorOffset..<currentPage * cursorLimit).all().flatMap(to: View.self) { sizes in
            
                let numPages = Int(ceil(Double(totalSizesCount) / Double(cursorLimit)))
                let pages = Array(1...numPages)
                
                let user = try req.requireAuthenticated(SUUser.self)
                let context = SizesContext(authenticatedUser: user, sizes: sizes, pages: pages, sizesPerPage: sizesPerPage, currentPage: currentPage)
                
                return try req.view().render("sizes", context)
            }
        }
    }
    
    func editSizeHandler(_ req: Request) throws -> Future<View> {
        
        return try req.parameters.next(SUSize.self).flatMap(to: View.self) { size in
            
            let user = try req.requireAuthenticated(SUUser.self)
            let context = EditSizeContext(authenticatedUser: user, size: size)
            
            return try req.view().render("size", context)
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
        let sizesPerPage: String
        let currentPage: Int
    }
    
    struct EditSizeContext: Encodable {
        let title = "Edit Size"
        let authenticatedUser: SUUser
        let size: SUSize
        let editing = true
    }
}
