import Vapor

public func routes(_ router: Router) throws {

    let categoryController = SUCategoryController()
    try router.register(collection: categoryController)
    
    let itemController = SUItemController()
    try router.register(collection: itemController)
    
    let sizeController = SUSizeController()
    try router.register(collection: sizeController)
    
    let yearController = SUYearController()
    try router.register(collection: yearController)
    
    let schoolController = SUSchoolController()
    try router.register(collection: schoolController)
    
    let userController = SUUserController()
    try router.register(collection: userController)
    
    let adminController = SUAdminController()
    try router.register(collection: adminController)
    
    let schoolAdminController = SUSchoolAdminController()
    try router.register(collection: schoolAdminController)
}
