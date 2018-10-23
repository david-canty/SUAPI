import Vapor
import FluentMySQL

final class SUShopItem: Codable {
    
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

extension SUShopItem: MySQLUUIDModel {}
extension SUShopItem: Content {}
extension SUShopItem: Parameter {}

extension SUShopItem: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            builder.reference(from: \.categoryID, to: \SUCategory.id, onUpdate: .cascade, onDelete: .restrict)
        }
    }
}

extension SUShopItem: Validatable {
    
    static func validations() throws -> Validations<SUShopItem> {
        
        var validations = Validations(SUShopItem.self)
        try validations.add(\.itemName, .count(1...))
        try validations.add(\.itemColor, .count(1...))
        try validations.add(\.itemGender, .count(1...))
        try validations.add(\.itemPrice, .range(0...))
        return validations
    }
}

extension SUShopItem {
    
    var category: Parent<SUShopItem, SUCategory> {
        
        return parent(\.categoryID)
    }
    
    var sizes: Siblings<SUShopItem, SUSize, SUItemSize> {
        
        return siblings()
    }
    
    var years: Siblings<SUShopItem, SUYear, SUItemYear> {
        
        return siblings()
    }
    
    var images: Children<SUShopItem, SUImage> {
        
        return children(\.itemID)
    }
}
