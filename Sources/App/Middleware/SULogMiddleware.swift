import Vapor

final class SULogMiddleware: Middleware {
    
    let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func respond(to req: Request, chainingTo next: Responder) throws -> Future<Response> {
        
        let start = Date()
        return try next.respond(to: req).map { res in
            
            self.log(res, start: start, for: req)
            return res
        }
    }
    
    func log(_ res: Response, start: Date, for req: Request) {
        
        let reqInfo = "\(req.http.method.string) \(req.http.url.path)"
        let resInfo = "\(res.http.status.code) " + "\(res.http.status.reasonPhrase)"
        
        let time = Date().timeIntervalSince(start).readableMilliseconds
        
        logger.info("\(reqInfo) -> \(resInfo) [\(time)]")
    }
}

extension SULogMiddleware: ServiceType {
    
    static func makeService(for container: Container) throws -> SULogMiddleware {
        return try .init(logger: container.make())
    }
}

extension TimeInterval {
    
    // Converts the time internal to readable milliseconds format, e.g., "3.4ms"
    var readableMilliseconds: String {
        let string = (self * 1000).description
        // include one decimal point after the zero
        let endIndex = string.index(string.index(of: ".")!, offsetBy: 2)
        let trimmed = string[string.startIndex..<endIndex]
        return .init(trimmed) + "ms"
    }
}
