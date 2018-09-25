//import Vapor
//import Fluent
//
//struct SUOrderController: RouteCollection {
//
//    func boot(router: Router) throws {
//
//        let orderRoutes = router.grouped("api", "orders")
//        orderRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in
//
//            jwtProtectedGroup.post(SUOrderData.self, use: createHandler)
//
//        }
//    }
//
//    func createHandler(_ req: Request, orderData: SUOrderData) throws -> Future<SUOrder> {
//
//
//    }
//
//    struct SUOrderData: Content {
//
//    }
//}

