import Foundation
import Vapor
import FluentMySQL

final class SUOrder: Codable {
    
    var id: UUID?
    var customerID: SUCustomer.ID
    var orderDate: String
    var orderStatus: String
    var paymentMethod: String
    var timestamp: String
    
    init(customerID: SUCustomer.ID,
         orderDate: String,
         orderStatus: String,
         paymentMethod: String) {
        
        self.customerID = customerID
        self.orderDate = orderDate
        self.orderStatus = orderStatus
        self.paymentMethod = paymentMethod
        self.timestamp = orderDate
    }
}

extension SUOrder: MySQLUUIDModel {}
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
