import Foundation
import Vapor
import FluentMySQL

final class SUOrder: Codable {
    
    var id: Int?
    var customerID: SUCustomer.ID
    var orderDate: Date
    var orderStatus: String
    var paymentMethod: String
    var chargeId: String?
    var timestamp: Date?
    
    init(customerID: SUCustomer.ID,
         orderDate: Date,
         orderStatus: String,
         paymentMethod: String,
         chargeId: String? = nil) {
        
        self.customerID = customerID
        self.orderDate = orderDate
        self.orderStatus = orderStatus
        self.paymentMethod = paymentMethod
        self.chargeId = chargeId
        self.timestamp = orderDate
    }
}

extension SUOrder: MySQLModel {}
extension SUOrder: Content {}
extension SUOrder: Parameter {}

extension SUOrder: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            builder.reference(from: \.customerID, to: \SUCustomer.id, onUpdate: .cascade, onDelete: .restrict)
        }
    }
}

extension SUOrder {
    
    var customer: Parent<SUOrder, SUCustomer> {
        
        return parent(\.customerID)
    }
    
    var orderItems: Children<SUOrder, SUOrderItem> {
        
        return children(\.orderID)
    }
}
