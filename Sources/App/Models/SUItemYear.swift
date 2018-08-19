import FluentMySQL
import Foundation

final class SUItemYear: MySQLUUIDPivot, ModifiablePivot {
    
    var id: UUID?
    var timestamp: String?
    
    var itemID: SUItem.ID
    var yearID: SUSize.ID
    
    typealias Left = SUItem
    typealias Right = SUYear
    
    static let leftIDKey: LeftIDKey = \.itemID
    static let rightIDKey: RightIDKey = \.yearID
    
    init(_ itemID: SUItem.ID, _ yearID: SUYear.ID) {
        self.itemID = itemID
        self.yearID = yearID
        self.timestamp = String(describing: Date())
    }
    
    init(_ item: SUItem, _ year: SUYear) throws {
        self.itemID = try item.requireID()
        self.yearID = try year.requireID()
        self.timestamp = String(describing: Date())
    }
}

extension SUItemYear: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            
            builder.reference(from: \.itemID, to: \SUItem.id, onUpdate: .cascade, onDelete: .cascade)
            builder.reference(from: \.yearID, to: \SUYear.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }
}
