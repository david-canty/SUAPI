import Foundation
import Vapor
import FluentMySQL

final class SUYear: Codable {
    
    var id: UUID?
    var yearName: String
    var schoolID: SUSchool.ID
    
    init(name: String, schoolID: SUSchool.ID) {
        self.yearName = name
        self.schoolID = schoolID
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
            builder.reference(from: \.schoolID, to: \SUSchool.id)
        }
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
