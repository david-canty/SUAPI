import FluentMySQL
import Vapor
import Leaf
import Authentication
import S3
import Stripe
import Mailgun
import Paginator

public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    
    guard let awsAccessKey = Environment.get("AWS_ACCESS_KEY") else { throw Abort(.internalServerError, reason: "Failed to get AWS_ACCESS_KEY") }
    guard let awsSecretKey = Environment.get("AWS_SECRET_KEY") else { throw Abort(.internalServerError, reason: "Failed to get AWS_SECRET_KEY") }
    guard let awsS3Bucket = Environment.get("AWS_S3_BUCKET") else { throw Abort(.internalServerError, reason: "Failed to get AWS_S3_BUCKET") }
    guard let stripeSecretKey = Environment.get("STRIPE_SECRET_KEY") else { throw Abort(.internalServerError, reason: "Failed to get STRIPE_SECRET_KEY") }
    guard let mailgunAPIKey = Environment.get("MAILGUN_API_KEY") else { throw Abort(.internalServerError, reason: "Failed to get MAILGUN_API_KEY") }
    guard let mailgunDomain = Environment.get("MAILGUN_DOMAIN") else { throw Abort(.internalServerError, reason: "Failed to get MAILGUN_DOMAIN") }
    
    services.register(NIOServerConfig.default(hostname: "0.0.0.0", port: 8080))
    
    try services.register(FluentMySQLProvider())
    try services.register(LeafProvider())
    try services.register(AuthenticationProvider())
    
    services.register(KeyedCache.self) { container in
        try container.keyedCache(for: .mysql)
    }
    
    services.register { container -> LeafTagConfig in
        var config = LeafTagConfig.default()
        config.use([
            "orderNo": OrderNoTag(),
            "offsetPaginator": OffsetPaginatorTag(templatePath: "Paginator/offsetpaginator")
            ])
        return config
    }
    
    services.register(OffsetPaginatorConfig(
        perPage: 1,
        defaultPage: 1
    ))
    
    let s3SignerConfig = S3Signer.Config(accessKey: awsAccessKey, secretKey: awsSecretKey, region: Region(name: .euWest2))
    try services.register(s3: s3SignerConfig, defaultBucket: awsS3Bucket)
    
    let stripeConfig = StripeConfig(apiKey: stripeSecretKey)
    services.register(stripeConfig)
    try services.register(StripeProvider())
    
    let mailgun = Mailgun(apiKey: mailgunAPIKey, domain: mailgunDomain)
    services.register(mailgun, as: Mailgun.self)

    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)
    
    //services.register(SULogMiddleware.self)
    services.register(SUJWTMiddleware.self)

    var middlewares = MiddlewareConfig()
    //middlewares.use(SULogMiddleware.self)
    middlewares.use(FileMiddleware.self)
    middlewares.use(ErrorMiddleware.self)
    middlewares.use(SessionsMiddleware.self)
    
    services.register(middlewares)
    
    var databases = DatabasesConfig()
    let databaseConfig: MySQLDatabaseConfig
    
    let url = Environment.get("DB_MYSQL")
    
    if let url = url {
        
        guard let urlConfig = try MySQLDatabaseConfig(url: url) else {
            fatalError("Failed to create MySQLDatabaseConfig")
        }
        
        databaseConfig = urlConfig
        
    } else {
        
        let hostname = Environment.get("DATABASE_HOSTNAME") ?? "localhost"
        let databasePort = 3306
        let username = Environment.get("DATABASE_USER") ?? "suapi"
        let password = Environment.get("DATABASE_PASSWORD") ?? "password"
        let databaseName = Environment.get("DATABASE_DB") ?? "suapi"
        
        databaseConfig = MySQLDatabaseConfig(
            hostname: hostname,
            port: databasePort,
            username: username,
            password: password,
            database: databaseName)
    }
    
    let database = MySQLDatabase(config: databaseConfig)
    databases.add(database: database, as: .mysql)
    services.register(databases)
    
    var migrations = MigrationConfig()
    migrations.add(model: SUCategory.self, database: .mysql)
    migrations.add(model: SUShopItem.self, database: .mysql)
    migrations.add(model: SUImage.self, database: .mysql)
    migrations.add(model: SUSize.self, database: .mysql)
    migrations.add(model: SUItemSize.self, database: .mysql)
    migrations.add(model: SUSchool.self, database: .mysql)
    migrations.add(model: SUYear.self, database: .mysql)
    migrations.add(model: SUItemYear.self, database: .mysql)
    migrations.add(model: SUUser.self, database: .mysql)
    migrations.add(model: SUCustomer.self, database: .mysql)
    migrations.add(model: SUOrder.self, database: .mysql)
    migrations.add(model: SUOrderItem.self, database: .mysql)
    migrations.add(model: SUOrderItemAction.self, database: .mysql)
    migrations.add(migration: AdminUser.self, database: .mysql)
    migrations.prepareCache(for: .mysql)
    services.register(migrations)
    
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)
    config.prefer(DatabaseKeyedCache<ConfiguredDatabase<MySQLDatabase>>.self, for: KeyedCache.self)
    
    var commandConfig = CommandConfig.default()
    commandConfig.useFluentCommands()
    services.register(commandConfig)
}
