import Foundation
import Vapor
import FluentMySQL

final class SUCategory: Codable {
    
    var id: UUID?
    var categoryName: String
    var sortOrder: Int?
    var timestamp: String?
    
    init(name: String, sortOrder: Int = 0) {
        self.categoryName = name
        self.sortOrder = sortOrder
        self.timestamp = String(describing: Date())
    }
}

extension SUCategory: MySQLUUIDModel {}
extension SUCategory: Content {}
extension SUCategory: Parameter {}

extension SUCategory: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            builder.unique(on: \.categoryName)
        }
    }
}

extension SUCategory: Validatable {
    
    static func validations() throws -> Validations<SUCategory> {
        
        var validations = Validations(SUCategory.self)
        try validations.add(\.categoryName, .count(1...))
        return validations
    }
}

extension SUCategory {
    
    var items: Children<SUCategory, SUItem> {
        
        return children(\.categoryID)
    }
}
