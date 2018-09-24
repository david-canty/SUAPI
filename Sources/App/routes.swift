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
    
    let categoryAdminController = SUCategoryAdminController()
    try router.register(collection: categoryAdminController)
    
    let sizeAdminController = SUSizeAdminController()
    try router.register(collection: sizeAdminController)
    
    let itemAdminController = SUItemAdminController()
    try router.register(collection: itemAdminController)
    
    let orderAdminController = SUOrderAdminController()
    try router.register(collection: orderAdminController)
    
    let userAdminController = SUUserAdminController()
    try router.register(collection: userAdminController)
}
