import Vapor
import Leaf
import Fluent
import Authentication

struct SUOrderAdminController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let authSessionRoutes = router.grouped("orders").grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        redirectProtectedRoutes.get(use: ordersHandler)
        redirectProtectedRoutes.get(SUOrder.parameter, use: viewOrderHandler)
    }
    
    // CRUD handlers
    func ordersHandler(_ req: Request) throws -> Future<View> {
        
        return SUOrder.query(on: req).sort(\.orderDate, .descending).all().flatMap(to: View.self) { orders in
        
            var orderList: [OrderDetail] = []
            for order in orders {
            
                let customer = order.customer.get(on: req)
                let orderItems = try order.orderItems.query(on: req).all()
                
                // orderTotal = for each order item - get item (from orderItem.itemID) price * orderItem orderQty
                let orderTotal = 0.0
                
                let orderDetail = OrderDetail(customer: customer, order: order, orderItems: orderItems, orderTotal: orderTotal)
                orderList.append(orderDetail)
            }
            
            let user = try req.requireAuthenticated(SUUser.self)
            let context = OrdersContext(authenticatedUser: user, orderList: orderList)
            
            return try req.view().render("orders", context)
        }
    }
    
    func viewOrderHandler(_ req: Request) throws -> Future<View> {
        
        return try req.parameters.next(SUOrder.self).flatMap(to: View.self) { order in
                
            let customer = order.customer.get(on: req)
            let orderItems = try order.orderItems.query(on: req).all()
            
            // orderTotal = for each order item - get item (from orderItem.itemID) price * orderItem orderQty
            let orderTotal = 0.0
            
            let orderDetail = OrderDetail(customer: customer, order: order, orderItems: orderItems, orderTotal: orderTotal)
            
            let user = try req.requireAuthenticated(SUUser.self)
            let context = ViewOrderContext(authenticatedUser: user, order: orderDetail)
            
            return try req.view().render("order", context)
        }
    }
    
    // Contexts
    struct OrdersContext: Encodable {
        let title = "Orders"
        let authenticatedUser: SUUser
        let orderList: [OrderDetail]
    }
    
    struct ViewOrderContext: Encodable {
        let title = "Order"
        let authenticatedUser: SUUser
        let order: OrderDetail
    }
    
    struct OrderDetail: Encodable {
        let customer:  EventLoopFuture<SUCustomer>
        let order: SUOrder
        let orderItems: EventLoopFuture<[SUOrderItem]>
        let orderTotal: Double
    }
}
