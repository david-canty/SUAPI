import FluentMySQL
import Vapor

public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    
    try services.register(FluentMySQLProvider())

    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    var middlewares = MiddlewareConfig()
    //middlewares.use(FileMiddleware.self)
    middlewares.use(ErrorMiddleware.self)
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
    services.register(migrations)
}
