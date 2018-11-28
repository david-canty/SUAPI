import Vapor

enum TagError: Error {
    case error(reason: String)
}

final class OrderNoTag: TagRenderer {
    
    init() { }
    
    func render(tag: TagContext) throws -> EventLoopFuture<TemplateData> {
        
        try tag.requireParameterCount(1)
        
        guard let orderNo = tag.parameters[0].int else {
            throw TagError.error(reason: "Invalid order no tag parameter")
        }
        
        let paddedOrderNo = String(format: "%06d", orderNo)
        return tag.container.future(.string(paddedOrderNo))
    }
}
