import FluentMySQL
import Foundation

final class SUItemYear: MySQLUUIDPivot, ModifiablePivot {
    
    var id: UUID?
    
    var itemID: SUItem.ID
    var yearID: SUSize.ID
    
    typealias Left = SUItem
    typealias Right = SUYear
    
    static let leftIDKey: LeftIDKey = \.itemID
    static let rightIDKey: RightIDKey = \.yearID
    
    init(_ itemID: SUItem.ID, _ yearID: SUYear.ID) {
        self.itemID = itemID
        self.yearID = yearID
    }
    
    init(_ left: SUItem, _ right: SUYear) throws {
        self.itemID = try left.requireID()
        self.yearID = try right.requireID()
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
