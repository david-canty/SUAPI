import Vapor

public func routes(_ router: Router) throws {

    let itemController = SUItemController()
    try router.register(collection: itemController)
}
