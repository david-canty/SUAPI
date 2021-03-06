import Foundation
import Vapor
import FluentMySQL

final class SUOrderItem: Codable {
    
    var id: UUID?
    var orderID: SUOrder.ID
    var itemID: SUShopItem.ID
    var sizeID: SUSize.ID
    var quantity: Int
    var orderItemStatus: String
    
    init(orderID: SUOrder.ID,
         itemID: SUShopItem.ID,
         sizeID: SUSize.ID,
         quantity: Int,
         orderItemStatus: String) {
        
        self.orderID = orderID
        self.itemID = itemID
        self.sizeID = sizeID
        self.quantity = quantity
        self.orderItemStatus = orderItemStatus
    }
}

extension SUOrderItem: MySQLUUIDModel {}
extension SUOrderItem: Content {}
extension SUOrderItem: Parameter {}

extension SUOrderItem: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            builder.reference(from: \.orderID, to: \SUOrder.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.itemID, to: \SUShopItem.id, onUpdate: .cascade, onDelete: .restrict)
            builder.reference(from: \.sizeID, to: \SUSize.id, onUpdate: .cascade, onDelete: .restrict)
        }
    }
}

extension SUOrderItem: Validatable {
    
    static func validations() throws -> Validations<SUOrderItem> {
        
        var validations = Validations(SUOrderItem.self)
        try validations.add(\.quantity, .range(1...))
        return validations
    }
}

extension SUOrderItem {
    
    var order: Parent<SUOrderItem, SUOrder> {
        
        return parent(\.orderID)
    }
}
