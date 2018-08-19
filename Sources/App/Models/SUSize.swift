import Foundation
import Vapor
import FluentMySQL

final class SUSize: Codable {
    
    var id: UUID?
    var sizeName: String
    var timestamp: String?
    
    init(name: String) {
        self.sizeName = name
        self.timestamp = String(describing: Date())
    }
}

extension SUSize: MySQLUUIDModel {}
extension SUSize: Content {}
extension SUSize: Parameter {}

extension SUSize: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            builder.unique(on: \.sizeName)
        }
    }
}

extension SUSize {
    
    var items: Siblings<SUSize, SUItem, SUItemSize> {
        
        return siblings()
    }
}
