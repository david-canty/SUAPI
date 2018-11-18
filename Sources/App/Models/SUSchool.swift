import Foundation
import Vapor
import FluentMySQL

final class SUSchool: Codable {
    
    var id: UUID?
    var schoolName: String
    var sortOrder: Int?
    var timestamp: Date?
    
    init(name: String) {
        self.schoolName = name
        self.timestamp = Date()
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

extension SUSchool: Validatable {
    
    static func validations() throws -> Validations<SUSchool> {
        
        var validations = Validations(SUSchool.self)
        try validations.add(\.schoolName, .count(1...))
        return validations
    }
}

extension SUSchool {
    
    var years: Children<SUSchool, SUYear> {
        
        return children(\.schoolID)
    }
}
