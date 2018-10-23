import Foundation
import Vapor
import FluentMySQL
import S3

final class SUImage: Codable {
    
    var id: UUID?
    var itemID: SUShopItem.ID
    var filename: String
    var sortOrder: Int?
    
    init(itemID: SUShopItem.ID, filename: String) {
        self.itemID = itemID
        self.filename = filename
    }
}

extension SUImage: MySQLUUIDModel {}
extension SUImage: Content {}
extension SUImage: Parameter {}

extension SUImage: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            builder.reference(from: \.itemID, to: \SUShopItem.id, onUpdate: .cascade, onDelete: .cascade)
        }
    }
}

extension SUImage {
    
    var item: Parent<SUImage, SUShopItem> {
        
        return parent(\.itemID)
    }
}

extension SUImage: LocationConvertible {
    
    public var bucket: String? {
        return Environment.get("AWS_S3_BUCKET")
    }
    
    public var path: String {
        return self.filename
    }

    public var region: Region? {
        return Region(name: .euWest2)
    }
}
