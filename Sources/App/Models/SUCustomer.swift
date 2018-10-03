import Foundation
import Vapor
import FluentMySQL

final class SUCustomer: Codable {
    
    var id: UUID?
    var firebaseUserID: String
    var firstName: String
    var lastName: String
    var email: String
    var tel: String?
    var mobile: String?
    var addressLine1: String?
    var addressLine2: String?
    var addressLine3: String?
    var postcode: String?
    
    init(firebaseUserID: String,
         firstName: String,
         lastName: String,
         email: String,
         tel: String? = nil,
         mobile: String? = nil,
         addressLine1: String? = nil,
         addressLine2: String? = nil,
         addressLine3: String? = nil,
         postcode: String? = nil) {
        
        self.firebaseUserID = firebaseUserID
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.tel = tel
        self.mobile = mobile
        self.addressLine1 = addressLine1
        self.addressLine2 = addressLine2
        self.addressLine3 = addressLine3
        self.postcode = postcode
    }
}

extension SUCustomer: MySQLUUIDModel {}
extension SUCustomer: Content {}
extension SUCustomer: Parameter {}

extension SUCustomer: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            builder.unique(on: \.firebaseUserID)
        }
    }
}

extension SUCustomer: Validatable {
    
    static func validations() throws -> Validations<SUCustomer> {
        
        var validations = Validations(SUCustomer.self)
        
        try validations.add(\.firebaseUserID, .count(1...))
        try validations.add(\.firstName, .count(1...) && .ascii)
        try validations.add(\.lastName, .count(1...) && .ascii)
        try validations.add(\.email, .email)
        
        let telCharacterSet = CharacterSet(charactersIn: "+ ()0123456789")
        try validations.add(\.tel, .count(1...) && .characterSet(telCharacterSet) || .nil)
        try validations.add(\.mobile, .count(1...) && .characterSet(telCharacterSet) || .nil)
        
        try validations.add(\.addressLine1, .count(1...) && .ascii || .nil)
        try validations.add(\.addressLine2, .count(1...) && .ascii || .nil)
        try validations.add(\.addressLine3, .count(1...) && .ascii || .nil)
        try validations.add(\.postcode, .count(1...) && .ascii || .nil)
        
        return validations
    }
}

extension SUCustomer {
    
    var orders: Children<SUCustomer, SUOrder> {
        
        return children(\.customerID)
    }
}
