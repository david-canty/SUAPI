import Vapor

public func boot(_ app: Application) throws {
    
    SUJWTHelper.sharedInstance.app = app
    SUJWTHelper.sharedInstance.fetchPublicKeys()
}
