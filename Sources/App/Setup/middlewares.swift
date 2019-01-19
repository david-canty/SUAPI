import Vapor

public func middlewares(config: inout MiddlewareConfig, services: inout Services) throws {
    
    //services.register(SULogMiddleware.self)
    services.register(SUJWTMiddleware.self)
    
    //config.use(SULogMiddleware.self)
    config.use(FileMiddleware.self)
    config.use(ErrorMiddleware.self)
    config.use(SessionsMiddleware.self)
}
