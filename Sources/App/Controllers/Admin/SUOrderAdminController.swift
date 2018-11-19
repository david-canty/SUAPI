import Vapor
import Leaf
import Fluent
import Authentication

struct SUOrderAdminController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let authSessionRoutes = router.grouped("orders").grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        redirectProtectedRoutes.get(use: ordersHandler)
        //redirectProtectedRoutes.get(SUOrder.parameter, use: viewOrderHandler)
    }
    
    // CRUD handlers
    func ordersHandler(_ req: Request) throws -> Future<View> {
        
        return SUOrder.query(on: req).sort(\.orderDate, .descending).all().flatMap(to: View.self) { orders in
            
            return try orders.compactMap { order in
                
                return try order.orderItems.query(on: req).all().map(to: OrderDetail.self) { orderItems in
                 
                    var itemCount = 0
                    for item in orderItems {
                        itemCount += item.quantity
                    }
                    
                        let customer = order.customer.get(on: req)
                        return OrderDetail(customer: customer, order: order, orderItems: orderItems, itemCount: itemCount)
                    
                    }
                }.flatMap(to: View.self, on: req) { orderDetails in
                        
                        let user = try req.requireAuthenticated(SUUser.self)
                        let context = OrdersContext(authenticatedUser: user, orderDetails: orderDetails)
                        
                        return try req.view().render("orders", context)
            }
        }
    }
    
//    func ordersHandler(_ req: Request) throws -> Future<View> {
//
//        return SUOrder.query(on: req).sort(\.orderDate, .descending).all().flatMap(to: View.self) { orders in
//
//            let orderList = try orders.map { order -> OrderDetail in
//
//                let customer = order.customer.get(on: req)
//                let orderItems = try order.orderItems.query(on: req).all()
//                return OrderDetail(customer: customer, order: order, orderItems: orderItems)
//            }
//
//            let user = try req.requireAuthenticated(SUUser.self)
//            let context = OrdersContext(authenticatedUser: user, orderList: orderList)
//
//            return try req.view().render("orders", context)
//
//        }
//    }
    
//    func ordersHandler(_ req: Request) throws -> Future<View> {
//
//        return SUOrder.query(on: req).sort(\.orderDate, .descending).all().flatMap(to: View.self) { orders in
//        
//            var orderList: [OrderDetail] = []
//            for order in orders {
//
//                let customer = order.customer.get(on: req)
//                let orderItems = try order.orderItems.query(on: req).all()
//
//
//
//                let orderDetail = OrderDetail(customer: customer, order: order, orderItems: orderItems)
//                orderList.append(orderDetail)
//            }
//
//            let user = try req.requireAuthenticated(SUUser.self)
//            let context = OrdersContext(authenticatedUser: user, orderList: orderList)
//
//            return try req.view().render("orders", context)
//        }
//    }
    
//    func viewOrderHandler(_ req: Request) throws -> Future<View> {
//
//        return try req.parameters.next(SUOrder.self).flatMap(to: View.self) { order in
//
//            let customer = order.customer.get(on: req)
//            let orderItems = try order.orderItems.query(on: req).all()
//            let orderDetail = OrderDetail(customer: customer, order: order, orderItems: orderItems)
//
//            let user = try req.requireAuthenticated(SUUser.self)
//            let context = ViewOrderContext(authenticatedUser: user, order: orderDetail)
//
//            return try req.view().render("order", context)
//        }
//    }
    
    // Contexts
    struct OrdersContext: Encodable {
        let title = "Orders"
        let authenticatedUser: SUUser
        let orderDetails: [OrderDetail]
    }
    
    struct ViewOrderContext: Encodable {
        let title = "Order"
        let authenticatedUser: SUUser
        let order: OrderDetail
    }
    
    struct OrderDetail: Encodable {
        let customer:  EventLoopFuture<SUCustomer>
        let order: SUOrder
        let orderItems: [SUOrderItem]
        let itemCount: Int
//        let orderTotal: Double
    }
}
