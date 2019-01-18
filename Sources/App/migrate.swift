import Vapor
import FluentMySQL

public func migrate(migrations: inout MigrationConfig) throws {
    
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
}
