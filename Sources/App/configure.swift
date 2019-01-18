import FluentMySQL
import Vapor
import Leaf
import Authentication
import S3
import Stripe
import Mailgun
import Paginator

struct APIKeyStorage: Service {
    let awsAccessKey: String
    let awsSecretKey: String
    let awsS3Bucket: String
    let awsRegion: String
    let stripeSecretKey: String
    let mailgunAPIKey: String
    let mailgunDomain: String
    let oneSignalAPIKey: String
    let oneSignalAppId: String
}

public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    
    // Key storage
    guard let awsAccessKey = Environment.get("AWS_ACCESS_KEY") else { throw Abort(.internalServerError, reason: "Failed to get AWS_ACCESS_KEY") }
    guard let awsSecretKey = Environment.get("AWS_SECRET_KEY") else { throw Abort(.internalServerError, reason: "Failed to get AWS_SECRET_KEY") }
    guard let awsS3Bucket = Environment.get("AWS_S3_BUCKET") else { throw Abort(.internalServerError, reason: "Failed to get AWS_S3_BUCKET") }
    guard let stripeSecretKey = Environment.get("STRIPE_SECRET_KEY") else { throw Abort(.internalServerError, reason: "Failed to get STRIPE_SECRET_KEY") }
    guard let mailgunAPIKey = Environment.get("MAILGUN_API_KEY") else { throw Abort(.internalServerError, reason: "Failed to get MAILGUN_API_KEY") }
    guard let mailgunDomain = Environment.get("MAILGUN_DOMAIN") else { throw Abort(.internalServerError, reason: "Failed to get MAILGUN_DOMAIN") }
    guard let oneSignalAPIKey = Environment.get("ONESIGNAL_API_KEY") else { throw Abort(.internalServerError, reason: "Failed to get ONESIGNAL_API_KEY") }
    guard let oneSignalAppId = Environment.get("ONESIGNAL_APP_ID") else { throw Abort(.internalServerError, reason: "Failed to get ONESIGNAL_APP_ID") }
    
    services.register { container -> APIKeyStorage in
        return APIKeyStorage(awsAccessKey: awsAccessKey, awsSecretKey: awsSecretKey, awsS3Bucket: awsS3Bucket, awsRegion: "eu-west-2", stripeSecretKey: stripeSecretKey, mailgunAPIKey: mailgunAPIKey, mailgunDomain: mailgunDomain, oneSignalAPIKey: oneSignalAPIKey, oneSignalAppId: oneSignalAppId)
    }
    
    // Services
    services.register(NIOServerConfig.default(hostname: "0.0.0.0", port: 8080))
    
    try services.register(FluentMySQLProvider())
    try services.register(LeafProvider())
    try services.register(AuthenticationProvider())
    
    services.register(KeyedCache.self) { container in
        try container.keyedCache(for: .mysql)
    }
    
    // Tags
    services.register { container -> LeafTagConfig in
        var config = LeafTagConfig.default()
        config.use([
            "orderNo": OrderNoTag(),
            "offsetPaginator": OffsetPaginatorTag(templatePath: "Paginator/offsetpaginator")
            ])
        return config
    }
    
    services.register(OffsetPaginatorConfig(
        perPage: 15,
        defaultPage: 1
    ))
    
    // S3 config
    let s3SignerConfig = S3Signer.Config(accessKey: awsAccessKey, secretKey: awsSecretKey, region: Region(name: .euWest2))
    try services.register(s3: s3SignerConfig, defaultBucket: awsS3Bucket)
    
    // Stripe config
    let stripeConfig = StripeConfig(apiKey: stripeSecretKey)
    services.register(stripeConfig)
    try services.register(StripeProvider())
    
    // Mailgun config
    let mailgun = Mailgun(apiKey: mailgunAPIKey, domain: mailgunDomain)
    services.register(mailgun, as: Mailgun.self)

    // Routes
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    // Register middlewares
    var middlewaresConfig = MiddlewareConfig()
    try middlewares(config: &middlewaresConfig, services: &services)
    services.register(middlewaresConfig)
    
    // Database config
    var databasesConfig = DatabasesConfig()
    try databases(config: &databasesConfig)
    services.register(databasesConfig)
    
    // Migrations
    services.register { container -> MigrationConfig in
        var migrationConfig = MigrationConfig()
        try migrate(migrations: &migrationConfig)
        return migrationConfig
    }
    
    // Config prefers
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)
    config.prefer(DatabaseKeyedCache<ConfiguredDatabase<MySQLDatabase>>.self, for: KeyedCache.self)
    
    // Command config
    var commandsConfig = CommandConfig.default()
    commands(config: &commandsConfig)
    services.register(commandsConfig)
}
