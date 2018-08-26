import Foundation
import Vapor
import FluentMySQL

final class SUUser: Codable {
    
    var id: UUID?
    var name: String
    var username: String
    var password: String
    var timestamp: String?
    
    init(name: String, username: String, password: String) {
        self.name = name
        self.username = username
        self.password = password
        self.timestamp = String(describing: Date())
    }
    
    final class Public: Codable {
        
        var id: UUID?
        var name: String
        var username: String
        var timestamp: String?
        
        init(id: UUID?, name: String, username: String) {
            self.id = id
            self.name = name
            self.username = username
            self.timestamp = String(describing: Date())
        }
    }
}

extension SUUser: Validatable {
    
    static func validations() throws -> Validations<SUUser> {
        
        var validations = Validations(SUUser.self)
        try validations.add(\.name, .count(1...))
        try validations.add(\.username, .count(1...) && .alphanumeric)
        return validations
    }
}

extension SUUser: MySQLUUIDModel {}
extension SUUser: Content {}
extension SUUser: Parameter {}
extension SUUser.Public: Content {}

extension SUUser: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            builder.unique(on: \.username)
        }
    }
}

extension SUUser {
    
    func convertToPublic() -> SUUser.Public {
        
        return SUUser.Public(id: id, name: name, username: username)
    }
}

extension Future where T: SUUser {
    
    func convertToPublic() -> Future<SUUser.Public> {
        
        return self.map(to: SUUser.Public.self) { user in
            
            return user.convertToPublic()
        }
    }
}
