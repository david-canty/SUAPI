import FluentMySQL
import Foundation

final class SUItemSize: MySQLUUIDPivot, ModifiablePivot {
    
    var id: UUID?
    var itemSizeStock: Int = 0
    var timestamp: String?
    
    var itemID: SUItem.ID
    var sizeID: SUSize.ID
    
    typealias Left = SUItem
    typealias Right = SUSize
    
    static let leftIDKey: LeftIDKey = \.itemID
    static let rightIDKey: RightIDKey = \.sizeID
    
    init(_ itemID: SUItem.ID, _ sizeID: SUSize.ID) {
        self.itemID = itemID
        self.sizeID = sizeID
        self.timestamp = String(describing: Date())
    }
    
    init(_ item: SUItem, _ size: SUSize) throws {
        self.itemID = try item.requireID()
        self.sizeID = try size.requireID()
        self.timestamp = String(describing: Date())
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
