import Foundation
import Vapor
import FluentMySQL

final class SUSchool: Codable {
    
    var id: UUID?
    var schoolName: String
    var timestamp: String?
    
    init(name: String) {
        self.schoolName = name
        self.timestamp = String(describing: Date())
    }
}

extension SUSchool: MySQLUUIDModel {}
extension SUSchool: Content {}
extension SUSchool: Parameter {}

extension SUSchool: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            builder.unique(on: \.schoolName)
        }
    }
}

extension SUSchool {
    
    var years: Children<SUSchool, SUYear> {
        
        return children(\.schoolID)
    }
}
