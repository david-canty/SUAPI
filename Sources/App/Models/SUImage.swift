import Foundation
import Vapor
import FluentMySQL
import S3

final class SUImage: Codable {
    
    var id: UUID?
    var itemID: SUItem.ID
    var imageFilename: String
    var sortOrder: Int?
    
    init(itemID: SUItem.ID, imageFilename: String) {
        self.itemID = itemID
        self.imageFilename = imageFilename
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

extension SUImage: LocationConvertible {
    
    public var bucket: String? {
        return Environment.get("AWS_S3_BUCKET")
    }
    
    public var path: String {
        return self.imageFilename
    }

    public var region: Region? {
        return Region(name: .euWest2)
    }
}
