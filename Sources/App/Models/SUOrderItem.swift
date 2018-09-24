import Foundation
import Vapor
import FluentMySQL

final class SUOrderItem: Codable {
    
    var id: UUID?
    var orderID: SUOrder.ID
    var itemID: SUItem.ID
    var itemSizeID: SUItemSize.ID
    var orderQty: Int
    
    init(orderID: SUOrder.ID,
         itemID: SUItem.ID,
         itemSizeID: SUItemSize.ID,
         orderQty: Int) {
        
        self.orderID = orderID
        self.itemID = itemID
        self.itemSizeID = itemSizeID
        self.orderQty = orderQty
    }
}

extension SUOrderItem: MySQLUUIDModel {}
extension SUOrderItem: Content {}
extension SUOrderItem: Parameter {}

extension SUOrderItem: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            builder.reference(from: \.orderID, to: \SUOrder.id, onUpdate: .cascade, onDelete: .restrict)
            builder.reference(from: \.itemID, to: \SUItem.id, onUpdate: .cascade, onDelete: .restrict)
            builder.reference(from: \.itemSizeID, to: \SUItemSize.id, onUpdate: .cascade, onDelete: .restrict)
        }
    }
}

extension SUOrderItem: Validatable {
    
    static func validations() throws -> Validations<SUOrderItem> {
        
        var validations = Validations(SUOrderItem.self)
        try validations.add(\.orderQty, .range(1...))
        return validations
    }
}

extension SUOrderItem {
    
    var order: Parent<SUOrderItem, SUOrder> {
        
        return parent(\.orderID)
    }
}
