import Foundation
import Vapor
import FluentMySQL

final class SUImage: Codable {
    
    var id: UUID?
    var image: Data
    var itemID: SUItem.ID
    var sortOrder: Int?
    
    init(image: Data, itemID: SUItem.ID) {
        self.image = image
        self.itemID = itemID
    }
}

extension SUImage: MySQLUUIDModel {}
extension SUImage: Content {}
extension SUImage: Parameter {}

extension SUImage: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            builder.reference(from: \.itemID, to: \SUItem.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }
}

extension SUImage {
    
    var item: Parent<SUImage, SUItem> {
        
        return parent(\.itemID)
    }
}
