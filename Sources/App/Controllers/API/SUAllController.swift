import Vapor
import Fluent
import Authentication

struct SUAllController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let allRoutes = router.grouped("api", "all")
        allRoutes.group(SUJWTMiddleware.self) { jwtProtectedGroup in
            
            jwtProtectedGroup.get(use: getAllHandler)
        }
    }
    
    func getAllHandler(_ req: Request) throws -> Future<SUAllData> {
        
        let schoolData = try getSchoolData(on: req)
        let itemData = try getItemData(on: req)
        let categoriesQuery = SUCategory.query(on: req).all()
        let sizesQuery = SUSize.query(on: req).all()
        
        return flatMap(schoolData, itemData, categoriesQuery, sizesQuery) { schools, items, categories, sizes in
            
            itemData.map { items in
                    
                return SUAllData(schools: schools, categories: categories, sizes: sizes, items: items)
            }
        }
    }
    
    func getSchoolData(on req: Request) throws -> Future<[SUSchoolData]> {
        
        return SUSchool.query(on: req).all().flatMap { schools in
            
            try schools.compactMap { school in
                
                try school.years.query(on: req).all().map { years in
                    
                    return SUSchoolData(school: school, years: years)
                }
                }.flatten(on: req)
        }
    }
    
    func getItemData(on req: Request) throws -> Future<[SUShopItemData]> {
        
        return SUShopItem.query(on: req).all().flatMap { items in
            
            return try items.compactMap { item in
                
                try SUItemSize.query(on: req).filter(\.itemID == item.requireID()).all().flatMap { sizes in
                    
                    return try map(item.years.query(on: req).all(), item.images.query(on: req).all()) { years, images in
                        
                        return SUShopItemData(item: item, sizes: sizes, years: years, images: images)
                    }
                }
                }.flatten(on: req)
        }
    }
    
    struct SUAllData: Content {
        let schools: [SUSchoolData]
        let categories: [SUCategory]
        let sizes: [SUSize]
        let items: [SUShopItemData]
    }
    
    struct SUSchoolData: Content {
        let school: SUSchool
        let years: [SUYear]
    }
    
    struct SUShopItemData: Content {
        let item: SUShopItem
        let sizes: [SUItemSize]
        let years: [SUYear]
        let images: [SUImage]
    }
}
