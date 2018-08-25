import Vapor
import Leaf
import Fluent

struct SUAdminController: RouteCollection {
    
    func boot(router: Router) throws {
        
        router.get(use: indexHandler)
    }
    
    func indexHandler(_ req: Request) throws -> Future<View> {
        
        let context = IndexContext(title: "Home")
        return try req.view().render("index", context)
    }
    
    struct IndexContext: Encodable {
        let title: String
    }
}
