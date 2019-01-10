import Vapor
import Leaf
import Fluent
import Authentication

struct SUOrderAdminController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let authSessionRoutes = router.grouped("orders").grouped(SUUser.authSessionsMiddleware())
        let redirectProtectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<SUUser>(path: "/sign-in"))
        
        redirectProtectedRoutes.get(use: ordersHandler)
        redirectProtectedRoutes.get(SUOrder.parameter, use: orderDetailsHandler)
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

                return try order.orderItems.query(on: req).all().flatMap(to: OrderDetail.self) { orderItems in

                    let customer = order.customer.get(on: req)
                    let itemCount = orderItems.reduce(0) { return $0 + Int($1.quantity) }
                    
                    return try self.getTotal(forOrder: order, on: req).map(to: OrderDetail.self) { orderTotal in
                        
                        let formatter = NumberFormatter()
                        formatter.numberStyle = .currency
                        formatter.currencySymbol = "£"
                        let formattedOrderTotal = formatter.string(from: orderTotal as NSNumber)
                        
                        return OrderDetail(customer: customer, order: order, orderItems: orderItems, itemCount: itemCount, formattedOrderTotal: formattedOrderTotal!)
                    }
                }

                }.flatMap(to: View.self, on: req) { orderDetails in

                    let user = try req.requireAuthenticated(SUUser.self)
                    let context = OrdersContext(authenticatedUser: user, orderDetails: orderDetails)

                    return try req.view().render("orders", context)
            }
        }
    }
    
    func orderDetailsHandler(_ req: Request) throws -> Future<View> {
        
        return try req.parameters.next(SUOrder.self).flatMap(to: View.self) { order in
            
            return try order.orderItems.query(on: req).all().flatMap(to: View.self) { orderItems in
                
                return orderItems.compactMap { orderItem in
                    
                    return SUShopItem.find(orderItem.itemID, on: req).flatMap(to: OrderItemDetails.self) { item in
                        
                        return SUSize.find(orderItem.sizeID, on: req).map(to: OrderItemDetails.self) { size in
                            
                            let quantity = orderItem.quantity
                            let status = orderItem.orderItemStatus
                            
                            let orderItemTotal = item!.itemPrice * Double(quantity)
                            let formatter = NumberFormatter()
                            formatter.numberStyle = .currency
                            formatter.currencySymbol = "£"
                            let formattedTotal = formatter.string(from: orderItemTotal as NSNumber)
                            
                            return OrderItemDetails(id: orderItem.id!, item: item!, size: size!, quantity: quantity, formattedTotal: formattedTotal!, status: status)
                        }
                    }
                }.flatten(on: req).flatMap(to: View.self) { orderItems in
                    
                    return try self.getTotal(forOrder: order, on: req).flatMap(to: View.self) { orderTotal in
                        
                        let user = try req.requireAuthenticated(SUUser.self)
                        let customer = order.customer.get(on: req)
                        
                        let itemCount = orderItems.reduce(0) { return $0 + Int($1.quantity) }
                        
                        let formatter = NumberFormatter()
                        formatter.numberStyle = .currency
                        formatter.currencySymbol = "£"
                        let formattedOrderTotal = formatter.string(from: orderTotal as NSNumber)
                        
                        let context = OrderDetailsContext(authenticatedUser: user, customer: customer, order: order, orderItems: orderItems, itemCount: itemCount, orderTotal: orderTotal, formattedOrderTotal: formattedOrderTotal!)
                        
                        return try req.view().render("order", context)
                    }
                }
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
        let formattedOrderTotal: String
    }
    
    struct OrderDetailsContext: Encodable {
        let title = "Order Details"
        let authenticatedUser: SUUser
        let customer:  EventLoopFuture<SUCustomer>
        let order: SUOrder
        let orderItems: [OrderItemDetails]
        let itemCount: Int
        let orderTotal: Double
        let formattedOrderTotal: String
    }
    
    struct OrderItemDetails: Encodable {
        let id: UUID
        let item: SUShopItem
        let size: SUSize
        let quantity: Int
        let formattedTotal: String
        let status: String
    }
}
