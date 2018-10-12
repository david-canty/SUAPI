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
        
        return SUSchool.query(on: req).all().flatMap(to: SUAllData.self) { (schools) -> Future<SUAllData> in
            
            return try schools.compactMap { (school) -> Future<SUSchoolData> in
                
                return try school.years.query(on: req).all().map(to: SUSchoolData.self) { (years) -> SUSchoolData in
                    
                    return SUSchoolData(school: school, years: years)
                }
            }.flatten(on: req)
                .flatMap(to: SUAllData.self) { (schools) -> Future<SUAllData> in
                    
                    return SUCategory.query(on: req).all().flatMap(to: SUAllData.self) { (categories) -> Future<SUAllData> in
                     
                        return SUSize.query(on: req).all().flatMap(to: SUAllData.self) { (sizes) -> Future<SUAllData> in
                            
                            return SUItem.query(on: req).all().flatMap(to: SUAllData.self) { (items) -> Future<SUAllData> in
                            
                                return try items.compactMap { (item) -> Future<SUItemData> in
                                    
                                    return try SUItemSize.query(on: req).filter(\SUItemSize.itemID == item.requireID()).all().flatMap(to: SUItemData.self) { (sizes) -> Future<SUItemData> in
                                        
                                        return try item.years.query(on: req).all().flatMap(to: SUItemData.self) { (years) -> Future<SUItemData> in
                                            
                                            return try item.images.query(on: req).all().map(to: SUItemData.self) { (images) -> SUItemData in
                                                
                                                return SUItemData(item: item, sizes: sizes, years: years, images: images)
                                            }
                                        }
                                    }
                                    }.flatten(on: req).map(to: SUAllData.self) { (items) -> SUAllData in
                                        
                                        return SUAllData(schools: schools, categories: categories, sizes: sizes, items: items)
                                    }
                            }
                        }
                    }
                }
        }
    }
    
    struct SUAllData: Content {
        let schools: [SUSchoolData]
        let categories: [SUCategory]
        let sizes: [SUSize]
        let items: [SUItemData]
    }
    
    struct SUSchoolData: Content {
        let school: SUSchool
        let years: [SUYear]
    }
    
    struct SUItemData: Content {
        let item: SUItem
        let sizes: [SUItemSize]
        let years: [SUYear]
        let images: [SUImage]
    }
}
