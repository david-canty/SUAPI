import Foundation
import Vapor
import FluentMySQL

final class SUCustomer: Codable {
    
    var id: UUID?
    var firebaseUserId: String
    var firstName: String?
    var lastName: String?
    var email: String
    var phone: String?
    var mobile: String?
    var addressLine1: String?
    var addressLine2: String?
    var addressLine3: String?
    var postcode: String?
    var apnsDeviceToken: String?
    var timestamp: Date?
    
    init(firebaseUserId: String,
         firstName: String? = nil,
         lastName: String? = nil,
         email: String,
         phone: String? = nil,
         mobile: String? = nil,
         addressLine1: String? = nil,
         addressLine2: String? = nil,
         addressLine3: String? = nil,
         postcode: String? = nil) {
        
        self.firebaseUserId = firebaseUserId
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.mobile = mobile
        self.addressLine1 = addressLine1
        self.addressLine2 = addressLine2
        self.addressLine3 = addressLine3
        self.postcode = postcode
        //self.timestamp = Date()
    }
}

extension SUCustomer: MySQLUUIDModel {}
extension SUCustomer: Content {}
extension SUCustomer: Parameter {}

extension SUCustomer: Migration {
    
    static func prepare(on connection: MySQLConnection) -> Future<Void> {
        
        return Database.create(self, on: connection) { builder in
            
            try addProperties(to: builder)
            builder.unique(on: \.firebaseUserId)
            builder.unique(on: \.email)
        }
    }
}

extension SUCustomer: Validatable {
    
    static func validations() throws -> Validations<SUCustomer> {
        
        var validations = Validations(SUCustomer.self)
        
        try validations.add(\.firebaseUserId, .count(1...))
        try validations.add(\.firstName, .count(1...) && .ascii || .nil)
        try validations.add(\.lastName, .count(1...) && .ascii || .nil)
        try validations.add(\.email, .email)
        
//        let telCharacterSet = CharacterSet(charactersIn: "+ ()0123456789")
//        try validations.add(\.tel, .count(1...) && .characterSet(telCharacterSet) || .nil)
//        try validations.add(\.mobile, .count(1...) && .characterSet(telCharacterSet) || .nil)
        try validations.add(\.phone, .count(1...) && .ascii || .nil)
        try validations.add(\.mobile, .count(1...) && .ascii || .nil)
        
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
