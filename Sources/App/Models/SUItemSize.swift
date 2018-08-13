import FluentMySQL
import Foundation

final class SUItemSize: MySQLUUIDPivot, ModifiablePivot {
    
    var id: UUID?
    var itemSizeStock: Int = 0
    
    var itemID: SUItem.ID
    var sizeID: SUSize.ID
    
    typealias Left = SUItem
    typealias Right = SUSize
    
    static let leftIDKey: LeftIDKey = \.itemID
    static let rightIDKey: RightIDKey = \.sizeID
    
    init(_ itemID: SUItem.ID, _ sizeID: SUSize.ID) {
        self.itemID = itemID
        self.sizeID = sizeID
    }
    
    init(_ left: SUItem, _ right: SUSize) throws {
        self.itemID = try left.requireID()
        self.sizeID = try right.requireID()
    }
}

extension SUItemSize: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            
            builder.reference(from: \.itemID, to: \SUItem.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.sizeID, to: \SUSize.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }
}
