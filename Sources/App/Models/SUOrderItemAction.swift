import Foundation
import Vapor
import FluentMySQL

final class SUOrderItemAction: Codable {
    
    var id: UUID?
    var orderItemID: SUOrderItem.ID
    var action: String
    var quantity: Int
    
    init(orderItemID: SUOrderItem.ID,
         action: String,
         quantity: Int) {
        
        self.orderItemID = orderItemID
        self.action = action
        self.quantity = quantity
    }
}

extension SUOrderItemAction: MySQLUUIDModel {}
extension SUOrderItemAction: Content {}
extension SUOrderItemAction: Parameter {}

extension SUOrderItemAction: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            builder.reference(from: \.orderItemID, to: \SUOrderItem.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }
}

extension SUOrderItemAction {
    
    var order: Parent<SUOrderItemAction, SUOrderItem> {
        
        return parent(\.orderItemID)
    }
}
