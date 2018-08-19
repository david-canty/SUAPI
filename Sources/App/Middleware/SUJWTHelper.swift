import Foundation
import Vapor

final class SUJWTHelper {
    
    static let sharedInstance = SUJWTHelper()
    
    var app: Application!
    var publicKeys: [String: String] = [:]
    var cacheControlMaxAge: Int = 0
    
    private init() {}
    
    func fetchPublicKeys() {
        
        do {
            
            // Request public keys
            let client = try app.client()
            let httpReq = HTTPRequest(method: .GET, url: "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com")
            let req = Request(http: httpReq, using: app)
            let res = client.send(req)
            
            // Parse response
            res.do { response in
                
                // Parse cache control max-age
                if let cacheControlString = response.http.headers.firstValue(name: .cacheControl) {

                    if let maxAgeRange = cacheControlString.range(of: "max-age=") {

                        let cacheSubstringFromMaxAge = cacheControlString[maxAgeRange.upperBound..<cacheControlString.endIndex]
                        let substringComponents = cacheSubstringFromMaxAge.split(separator: ",")
                        let maxAgeSubstring = substringComponents[0]
                        self.cacheControlMaxAge = Int(maxAgeSubstring)!
                    }
                }

                // Parse public keys
                if let bodyData = response.http.body.data {
                    
                    let bodyString = String(data: bodyData, encoding: .utf8)
                    
                    if let keyComponentPairs = bodyString?.split(separator: ",") {
                    
                        for keyComponents in keyComponentPairs {
                            
                            let keyPairs = keyComponents.split(separator: ":")
                            
                            let keyId = keyPairs[0]
                            var keyIdStripped = keyId.replacingOccurrences(of: "\"", with: "")
                            keyIdStripped = keyIdStripped.replacingOccurrences(of: "{", with: "")
                            keyIdStripped = keyIdStripped.replacingOccurrences(of: "\n", with: "")
                            keyIdStripped = keyIdStripped.replacingOccurrences(of: " ", with: "")
                            
                            let keyCert = keyPairs[1]
                            var keyCertStripped = keyCert.replacingOccurrences(of: "\"", with: "")
                            keyCertStripped = keyCertStripped.replacingOccurrences(of: " ", with: "")
                            // also } and check anything else
                            
                            self.publicKeys[keyIdStripped] = keyCertStripped
                        }
                    }
                }
                
                // Schedule next key refresh
                _ = self.app.eventLoop.scheduleTask(in: TimeAmount.seconds(self.cacheControlMaxAge)) { () -> Void in
                    self.fetchPublicKeys()
                }
                
            }.catch { error in
                
                fatalError("Could not send HTTP request: \(error)")
            }
        
        } catch {
            
            fatalError("Could not create HTTP client: \(error)")
        }
    }
}
