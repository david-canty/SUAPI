import Foundation
import Vapor

final class SUJWTHelper {
    
    static let sharedInstance = SUJWTHelper()
    
    var app: Application!
    var publicKeys: [String: String] = [:]
    
    private init() {}
    
    func fetchPublicKeys() {
        
        do {
            
            // Create client request
            let client = try app.client()
            let httpReq = HTTPRequest(method: .GET, url: "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com")
            let req = Request(http: httpReq, using: app)

            // Get response
            _ = client.send(req).flatMap { response in
                
                // Decode public keys
                try response.content.decode([String: String].self).map() { keys in
                    
                    self.publicKeys = keys
                    
                    // Get cache control max-age
                    var cacheControlMaxAge = 86400 // default to a day
                    if let cacheControlString = response.http.headers.firstValue(name: .cacheControl) {
                        
                        if let maxAgeRange = cacheControlString.range(of: "max-age=") {
                            
                            let cacheSubstringFromMaxAge = cacheControlString[maxAgeRange.upperBound..<cacheControlString.endIndex]
                            let substringComponents = cacheSubstringFromMaxAge.split(separator: ",")
                            let maxAgeSubstring = substringComponents[0]
                            cacheControlMaxAge = Int(maxAgeSubstring)!
                        }
                    }
                    
                    // Schedule next keys refresh
                    _ = self.app.eventLoop.scheduleTask(in: TimeAmount.seconds(cacheControlMaxAge)) { () -> Void in
                            self.fetchPublicKeys()
                    }
                }
            }
            
        } catch {
            
            fatalError("Error with request: \(error)")
        }
    }
}
