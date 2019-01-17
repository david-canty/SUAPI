import Vapor
import FluentMySQL

public func databases(config: inout DatabasesConfig) throws {
    
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
    
    config.add(database: MySQLDatabase(config: databaseConfig), as: .mysql)
}
