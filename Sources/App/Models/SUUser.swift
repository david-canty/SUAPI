import Foundation
import Vapor
import FluentMySQL
import Authentication

final class SUUser: Codable {
    
    var id: UUID?
    var name: String
    var username: String
    var password: String
    var isEnabled = true
    var timestamp = String(describing: Date())
    
    init(name: String, username: String, password: String) {
        self.name = name
        self.username = username
        self.password = password
    }
    
    final class Public: Codable {
        
        var id: UUID?
        var name: String
        var username: String
        var isEnabled: Bool
        var timestamp: String
        
        init(id: UUID?, name: String, username: String, isEnabled: Bool, timestamp: String) {
            self.id = id
            self.name = name
            self.username = username
            self.isEnabled = isEnabled
            self.timestamp = timestamp
        }
    }
}

extension SUUser: MySQLUUIDModel {}
extension SUUser: Content {}
extension SUUser: Parameter {}
extension SUUser.Public: Content {}
extension SUUser: PasswordAuthenticatable {}
extension SUUser: SessionAuthenticatable {}

extension SUUser: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            builder.unique(on: \.username)
        }
    }
}

extension SUUser: Validatable {
    
    static func validations() throws -> Validations<SUUser> {
        
        var validations = Validations(SUUser.self)
        try validations.add(\.name, .count(1...) && .characterSet(.alphanumerics + .whitespaces))
        try validations.add(\.username, .count(1...) && .alphanumeric)
        return validations
    }
}

extension SUUser {
    
    func convertToPublic() -> SUUser.Public {
        
        return SUUser.Public(id: id, name: name, username: username, isEnabled: isEnabled, timestamp: timestamp)
    }
}

extension Future where T: SUUser {
    
    func convertToPublic() -> Future<SUUser.Public> {
        
        return self.map(to: SUUser.Public.self) { user in
            
            return user.convertToPublic()
        }
    }
}

extension SUUser: BasicAuthenticatable {
    
    static let usernameKey: UsernameKey = \SUUser.username
    static let passwordKey: PasswordKey = \SUUser.password
}

struct AdminUser: Migration {
    
    typealias Database = MySQLDatabase
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        let password = try? BCrypt.hash("password")
        
        guard let hashedPassword = password else {
            fatalError("Failed to create admin user.")
        }
    
        let user = SUUser(name: "Admin", username: "admin", password: hashedPassword)
        
        return user.save(on: connection).transform(to: ())
    }
    
    static func revert(on connection: MySQLConnection) -> Future<Void> {
            return .done(on: connection)
    }
}
