import Vapor

public func routes(_ router: Router) throws {

    let categoryController = SUCategoryController()
    try router.register(collection: categoryController)
    
    let itemController = SUItemController()
    try router.register(collection: itemController)
    
    let sizeController = SUSizeController()
    try router.register(collection: sizeController)
}
