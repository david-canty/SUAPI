import FluentMySQL
import Foundation
import Vapor

final class SUItemSize: MySQLUUIDPivot, ModifiablePivot, Content {
    
    var id: UUID?
    var stock: Int = 0
    var timestamp: String?
    
    var itemID: SUShopItem.ID
    var sizeID: SUSize.ID
    
    typealias Left = SUShopItem
    typealias Right = SUSize
    
    static let leftIDKey: LeftIDKey = \.itemID
    static let rightIDKey: RightIDKey = \.sizeID
    
    init(_ itemID: SUShopItem.ID, _ sizeID: SUSize.ID) {
        self.itemID = itemID
        self.sizeID = sizeID
        self.timestamp = String(describing: Date())
    }
    
    init(_ item: SUShopItem, _ size: SUSize) throws {
        self.itemID = try item.requireID()
        self.sizeID = try size.requireID()
        self.timestamp = String(describing: Date())
    }
}

extension SUItemSize: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            
            builder.reference(from: \.itemID, to: \SUShopItem.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.sizeID, to: \SUSize.id, onUpdate: .cascade, onDelete: .restrict)
        }
    }
}

extension SUItemSize: Validatable {
    
    static func validations() throws -> Validations<SUItemSize> {
        
        var validations = Validations(SUItemSize.self)
        try validations.add(\.stock, .range(0...))
        return validations
    }
}
