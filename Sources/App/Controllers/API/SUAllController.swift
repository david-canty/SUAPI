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
            
            return try schools.compactMap { (school) -> Future<SUSchoolYearsData> in
                
                return try school.years.query(on: req).all().map(to: SUSchoolYearsData.self) { (years) -> SUSchoolYearsData in
                    
                    return SUSchoolYearsData(school: school, years: years)
                }
            }.flatten(on: req)
                .flatMap(to: SUAllData.self) { (schoolYears) -> Future<SUAllData> in
                    
                    return SUCategory.query(on: req).all().flatMap(to: SUAllData.self) { (categories) -> Future<SUAllData> in
                     
                        return SUSize.query(on: req).all().flatMap(to: SUAllData.self) { (sizes) -> Future<SUAllData> in
                            
                            return SUItem.query(on: req).all().flatMap(to: SUAllData.self) { (items) -> Future<SUAllData> in
                            
                                return try items.compactMap { (item) -> Future<SUItemSizesData> in
                                    
                                    return try SUItemSize.query(on: req).filter(\SUItemSize.itemID == item.requireID()).all().map(to: SUItemSizesData.self) { (sizes) -> SUItemSizesData in
                                    
                                        return SUItemSizesData(item: item, sizes: sizes)
                                    }
                                    }.flatten(on: req).map(to: SUAllData.self) { (itemSizes) -> SUAllData in
                                        
                                        return SUAllData(schoolYears: schoolYears, categories: categories, sizes: sizes, itemSizes: itemSizes)
                                    }
                            }
                        }
                    }
                }
        }
    }
    
    struct SUAllData: Content {
        let schoolYears: [SUSchoolYearsData]
        let categories: [SUCategory]
        let sizes: [SUSize]
        let itemSizes: [SUItemSizesData]
    }
    
    struct SUSchoolYearsData: Content {
        let school: SUSchool
        let years: [SUYear]
    }
    
    struct SUItemSizesData: Content {
        let item: SUItem
        let sizes: [SUItemSize]
    }
}
