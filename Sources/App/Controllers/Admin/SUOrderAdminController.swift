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
    
    func getTotal(forOrder order: SUOrder, on req: Request) throws -> EventLoopFuture<Double> {
        
        return try order.orderItems.query(on: req).all().flatMap(to: Double.self) { orderItems in
            
            return orderItems.compactMap { orderItem in
                
                return SUShopItem.find(orderItem.itemID, on: req).map(to: Double.self) { item in
                    
                    return item!.itemPrice * Double(orderItem.quantity)
                }
                
            }.map(to: Double.self, on: req) { orderItemTotals in
                    
                return orderItemTotals.reduce(0.0, +)
            }
        }
    }
    
    func ordersHandler(_ req: Request) throws -> Future<View> {

        return SUOrder.query(on: req).sort(\.orderDate, .descending).all().flatMap(to: View.self) { orders in

            return try orders.compactMap { order in

                return try order.orderItems.query(on: req).all().map(to: OrderDetail.self) { orderItems in

                    let itemCount = orderItems.reduce(0) { return $0 + Int($1.quantity) }
                    let customer = order.customer.get(on: req)
                    let orderTotal = try self.getTotal(forOrder: order, on: req)

                    return OrderDetail(customer: customer, order: order, orderItems: orderItems, itemCount: itemCount, orderTotal: orderTotal)

                }

                }.flatMap(to: View.self, on: req) { orderDetails in

                    let user = try req.requireAuthenticated(SUUser.self)
                    let context = OrdersContext(authenticatedUser: user, orderDetails: orderDetails)

                    return try req.view().render("orders", context)
            }
        }
    }
    
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
        let orderTotal: EventLoopFuture<Double>
    }
}
