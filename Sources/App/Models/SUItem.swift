import Vapor
import FluentMySQL

final class SUItem: Codable {
    
    var id: UUID?
    var itemName: String
    var itemDescription: String?
    var itemColor: String
    var itemGender: String
    var itemPrice: Double
    var categoryID: SUCategory.ID
    var timestamp: String?
    
    init(name: String,
         description: String? = nil,
         color: String,
         gender: String,
         price: Double,
         categoryID: SUCategory.ID) {
        
        self.itemName = name
        self.itemDescription = description
        self.itemColor = color
        self.itemGender = gender
        self.itemPrice = price
        self.categoryID = categoryID
        self.timestamp = String(describing: Date())
    }
}

extension SUItem: MySQLUUIDModel {}
extension SUItem: Content {}
extension SUItem: Parameter {}

extension SUItem: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            builder.reference(from: \.categoryID, to: \SUCategory.id, onUpdate: .cascade, onDelete: .restrict)
        }
    }
}

extension SUItem {
    
    var category: Parent<SUItem, SUCategory> {
        
        return parent(\.categoryID)
    }
    
    var sizes: Siblings<SUItem, SUSize, SUItemSize> {
        
        return siblings()
    }
    
    var years: Siblings<SUItem, SUYear, SUItemYear> {
        
        return siblings()
    }
}
