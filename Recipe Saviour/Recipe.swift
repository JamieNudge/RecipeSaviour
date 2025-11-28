import Foundation

struct Recipe: Identifiable, Codable {
    let id: UUID
    let title: String
    let ingredients: [String]
    let steps: [String]
    let sourceURL: URL
    let dateSaved: Date
    
    init(id: UUID = UUID(), title: String, ingredients: [String], steps: [String], sourceURL: URL, dateSaved: Date = Date()) {
        self.id = id
        self.title = title
        self.ingredients = ingredients
        self.steps = steps
        self.sourceURL = sourceURL
        self.dateSaved = dateSaved
    }
}


