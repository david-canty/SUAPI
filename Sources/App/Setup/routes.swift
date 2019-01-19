import Vapor
import Mailgun
import OneSignal
import Stripe

public func routes(_ router: Router, _ container: Container) throws {

    // Route services
    let mailgun = try container.make(Mailgun.self)
    let apiKeyStorage = try container.make(APIKeyStorage.self)
    let s3Client = try container.makeS3Client()
    let oneSignal = try OneSignal.makeService(for: container)
    let stripeClient = try container.make(StripeClient.self)
    
    // Routes
    let allController = SUAllController()
    try router.register(collection: allController)
    
    let categoryController = SUCategoryController()
    try router.register(collection: categoryController)
    
    let itemController = SUShopItemController(s3Client: s3Client)
    try router.register(collection: itemController)
    
    let sizeController = SUSizeController()
    try router.register(collection: sizeController)
    
    let yearController = SUYearController()
    try router.register(collection: yearController)
    
    let schoolController = SUSchoolController()
    try router.register(collection: schoolController)
    
    let userController = SUUserController()
    try router.register(collection: userController)
    
    let customerController = SUCustomerController()
    try router.register(collection: customerController)
    
    let orderController = SUOrderController(apiKeyStorage: apiKeyStorage,
                                            mailgun: mailgun,
                                            oneSignal: oneSignal)
    try router.register(collection: orderController)
    
    let adminController = SUAdminController()
    try router.register(collection: adminController)
    
    let schoolAdminController = SUSchoolAdminController()
    try router.register(collection: schoolAdminController)
    
    let categoryAdminController = SUCategoryAdminController()
    try router.register(collection: categoryAdminController)
    
    let sizeAdminController = SUSizeAdminController()
    try router.register(collection: sizeAdminController)
    
    let itemAdminController = SUShopItemAdminController(apiKeyStorage: apiKeyStorage)
    try router.register(collection: itemAdminController)
    
    let orderAdminController = SUOrderAdminController()
    try router.register(collection: orderAdminController)
    
    let userAdminController = SUUserAdminController()
    try router.register(collection: userAdminController)
    
//    let customerAdminController = SUCustomerAdminController()
//    try router.register(collection: customerAdminController)
    
    let stripeController = SUStripeController(stripeClient: stripeClient)
    try router.register(collection: stripeController)
}
