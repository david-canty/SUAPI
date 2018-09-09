import FluentMySQL
import Vapor
import Leaf
import Authentication

public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    
    try services.register(FluentMySQLProvider())
    try services.register(LeafProvider())
    try services.register(AuthenticationProvider())
    
    services.register(KeyedCache.self) { container in
        try container.keyedCache(for: .mysql)
    }

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
    let hostname = Environment.get("DATABASE_HOSTNAME") ?? "localhost"
    let username = Environment.get("DATABASE_USER") ?? "suapi"
    let password = Environment.get("DATABASE_PASSWORD") ?? "password"
    
    let databaseName: String
    let databasePort: Int
    if (env == .testing) {
        
        databaseName = "suapi-test"
        databasePort = 3307
        
    } else {
        
        databaseName = Environment.get("DATABASE_DB") ?? "suapi"
        databasePort = 3306
    }
    
    let databaseConfig = MySQLDatabaseConfig(
        hostname: hostname,
        port: databasePort,
        username: username,
        password: password,
        database: databaseName)
    
    let database = MySQLDatabase(config: databaseConfig)
    databases.add(database: database, as: .mysql)
    services.register(databases)
    
    var migrations = MigrationConfig()
    migrations.add(model: SUCategory.self, database: .mysql)
    migrations.add(model: SUItem.self, database: .mysql)
    migrations.add(model: SUSize.self, database: .mysql)
    migrations.add(model: SUItemSize.self, database: .mysql)
    migrations.add(model: SUSchool.self, database: .mysql)
    migrations.add(model: SUYear.self, database: .mysql)
    migrations.add(model: SUItemYear.self, database: .mysql)
    migrations.add(model: SUUser.self, database: .mysql)
    migrations.add(migration: AdminUser.self, database: .mysql)
    migrations.prepareCache(for: .mysql)
    services.register(migrations)
    
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)
    config.prefer(DatabaseKeyedCache<ConfiguredDatabase<MySQLDatabase>>.self, for: KeyedCache.self)
}
