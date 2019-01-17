import Vapor

public func middlewares(config: inout MiddlewareConfig) throws {
    
    //config.use(SULogMiddleware.self)
    config.use(FileMiddleware.self)
    config.use(ErrorMiddleware.self)
    config.use(SessionsMiddleware.self)
}
