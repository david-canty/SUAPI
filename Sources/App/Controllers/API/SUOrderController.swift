import Vapor
import Fluent

enum PaymentMethod: String {
    case bacs = "bacs"
    case schoolBill = "schoolBill"
    case card = "card"
}

enum OrderStatus: String {
    case ordered = "Ordered"
    case awaitingStock = "Awaiting Stock"
    case readyForCollection = "Ready for Collection"
    case awaitingPayment = "Awaiting Payment"
    case complete = "Complete"
}

struct SUOrderController: RouteCollection {

    func boot(router: Router) throws {

        let orderRoutes = router.grouped("api", "customers")
        orderRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in

            jwtProtectedGroup.post(SUCustomer.parameter, "orders", use: createHandler)

        }
    }

    func createHandler(_ req: Request) throws -> Future<SUOrderInfo> {

        return try flatMap(to: SUOrderInfo.self, req.parameters.next(SUCustomer.self), req.content.decode(SUOrderPostData.self)) { customer, orderData in

            let order = SUOrder(customerID: customer.id!,
                                orderDate: String(describing: Date()),
                                orderStatus: OrderStatus.ordered.rawValue,
                                paymentMethod: orderData.paymentMethod)

            return order.save(on: req).flatMap(to: SUOrderInfo.self) { order in

                var orderItemSaveResults: [Future<SUOrderItem>] = []
                
                for orderItemData in orderData.orderItems {
                    
                    let itemID = UUID(uuidString: orderItemData["itemID"]!)
                    let sizeID = UUID(uuidString: orderItemData["sizeID"]!)
                    let quantity = Int(orderItemData["quantity"]!)
                    
                    let orderItem = SUOrderItem(orderID: order.id!, itemID: itemID!, sizeID: sizeID!, quantity: quantity!)
                    
                    orderItemSaveResults.append(orderItem.save(on: req))
                }
                
                return orderItemSaveResults.flatten(on: req).map(to: SUOrderInfo.self) { orderItems in
                    
                    return SUOrderInfo(customer: customer, order: order, orderItems: orderItems)
                }
            }
        }
    }

    struct SUOrderPostData: Content {
        let orderItems: [[String: String]]
        let paymentMethod: String
    }
    
    struct SUOrderInfo: Content {
        let customer:  SUCustomer
        let order: SUOrder
        let orderItems: [SUOrderItem]
    }
}

