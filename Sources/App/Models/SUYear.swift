import Foundation
import Vapor
import FluentMySQL

final class SUYear: Codable {
    
    var id: UUID?
    var yearName: String
    var schoolID: SUSchool.ID
    var sortOrder: Int?
    var timestamp: String?
    
    init(name: String, schoolID: SUSchool.ID, sortOrder: Int = 0) {
        self.yearName = name
        self.schoolID = schoolID
        self.sortOrder = sortOrder
        self.timestamp = String(describing: Date())
    }
}

extension SUYear: MySQLUUIDModel {}
extension SUYear: Content {}
extension SUYear: Parameter {}

extension SUYear: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            builder.unique(on: \.yearName)
            builder.reference(from: \.schoolID, to: \SUSchool.id, onUpdate: .cascade, onDelete: .restrict)
        }
    }
}

extension SUYear: Validatable {
    
    static func validations() throws -> Validations<SUYear> {
        
        var validations = Validations(SUYear.self)
        try validations.add(\.yearName, .count(1...))
        return validations
    }
}

extension SUYear {
    
    var school: Parent<SUYear, SUSchool> {
        
        return parent(\.schoolID)
    }
    
    var items: Siblings<SUYear, SUItem, SUItemYear> {
        
        return siblings()
    }
}
