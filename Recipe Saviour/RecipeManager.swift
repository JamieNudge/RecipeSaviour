import Foundation
import Combine

@MainActor
class RecipeManager: ObservableObject {
    @Published var savedRecipes: [Recipe] = []
    @Published var favouritePlans: [MealPlan] = []
    
    private let persistenceKey = "savedRecipes"
    private let plansPersistenceKey = "savedMealPlans"
    
    static let shared = RecipeManager()
    
    private init() {
        loadRecipes()
        loadMealPlans()
    }
    
    func saveRecipe(_ recipe: Recipe) {
        // Check if already saved (by URL)
        if savedRecipes.contains(where: { $0.sourceURL == recipe.sourceURL }) {
            print("⚠️ Recipe already saved: \(recipe.title)")
            return
        }
        
        savedRecipes.append(recipe)
        persistRecipes()
        print("✅ Saved recipe: \(recipe.title)")
    }
    
    func deleteRecipe(_ recipe: Recipe) {
        savedRecipes.removeAll { $0.id == recipe.id }
        persistRecipes()
        print("🗑️ Deleted recipe: \(recipe.title)")
    }
    
    func isRecipeSaved(_ recipe: Recipe) -> Bool {
        savedRecipes.contains(where: { $0.sourceURL == recipe.sourceURL })
    }
    
    // MARK: - Persistence
    
    private func persistRecipes() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(savedRecipes)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            print("❌ Failed to save recipes: \(error.localizedDescription)")
        }
    }
    
    private func loadRecipes() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else {
            print("ℹ️ No saved recipes found")
            // In debug builds, seed with a few example recipes to make testing easier
            seedDebugRecipesIfNeeded()
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            savedRecipes = try decoder.decode([Recipe].self, from: data)
            print("✅ Loaded \(savedRecipes.count) saved recipes")
        } catch {
            print("❌ Failed to load recipes: \(error.localizedDescription)")
            // If decoding fails, fall back to debug seed data (in debug builds)
            seedDebugRecipesIfNeeded()
        }
    }

    // MARK: - Meal Plan Favourites
    
    func saveMealPlan(_ recipes: [Recipe]) {
        // Avoid saving empty plans
        guard !recipes.isEmpty else { return }
        
        // Avoid duplicates with identical recipe sets
        let newSet = Set(recipes.map { $0.id })
        if favouritePlans.contains(where: { Set($0.recipes.map { $0.id }) == newSet }) {
            print("⚠️ Meal plan with same recipes already saved")
            return
        }
        
        let plan = MealPlan(recipes: recipes)
        favouritePlans.append(plan)
        persistMealPlans()
        print("✅ Saved meal plan with \(recipes.count) recipes")
    }
    
    func deleteMealPlan(_ plan: MealPlan) {
        favouritePlans.removeAll { $0.id == plan.id }
        persistMealPlans()
    }
    
    private func persistMealPlans() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(favouritePlans)
            UserDefaults.standard.set(data, forKey: plansPersistenceKey)
        } catch {
            print("❌ Failed to save meal plans: \(error.localizedDescription)")
        }
    }
    
    private func loadMealPlans() {
        guard let data = UserDefaults.standard.data(forKey: plansPersistenceKey) else {
            print("ℹ️ No saved meal plans found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            favouritePlans = try decoder.decode([MealPlan].self, from: data)
            print("✅ Loaded \(favouritePlans.count) favourite meal plans")
        } catch {
            print("❌ Failed to load meal plans: \(error.localizedDescription)")
        }
    }

    // MARK: - Debug Seed Data

    /// For development only: if there are no saved recipes, populate a small test library
    /// so the Meal Planner and shopping list can be exercised without manual entry.
    private func seedDebugRecipesIfNeeded() {
        #if DEBUG
        guard savedRecipes.isEmpty else { return }

        print("ℹ️ Seeding debug recipes for development build")

        let now = Date()

        let pasta = Recipe(
            title: "Quick Tomato Pasta",
            ingredients: [
                "200 g spaghetti",
                "2 cloves garlic",
                "1 tbsp olive oil",
                "1 can chopped tomatoes",
                "1 tsp dried oregano",
                "Salt",
                "Black pepper",
                "Parmesan cheese"
            ],
            steps: [
                "Cook spaghetti in salted boiling water according to packet instructions.",
                "Gently fry sliced garlic in olive oil until fragrant.",
                "Add chopped tomatoes, oregano, salt and pepper and simmer for 10 minutes.",
                "Toss the drained pasta through the sauce.",
                "Serve with grated parmesan."
            ],
            sourceURL: URL(string: "https://example.com/debug-tomato-pasta")!,
            dateSaved: now
        )

        let chickenBurgers = Recipe(
            title: "Juicy Chicken Burgers",
            ingredients: [
                "500 g boneless chicken thighs",
                "1 tsp sweet paprika",
                "1 tsp garlic powder",
                "2 burger buns",
                "4 slices American cheese",
                "Salad leaves",
                "Salt and pepper",
                "5 tbsp frying oil",
                "4 tbsp mayo",
                "3 gherkins",
                "1 shallot",
                "Sriracha sauce"
            ],
            steps: [
                "Chop chicken thighs and mince with spices, salt and pepper.",
                "Form burger patties and chill.",
                "Fry patties in hot oil until cooked through and crispy.",
                "Toast buns in butter.",
                "Mix mayo, chopped gherkins, shallot and Sriracha for the sauce.",
                "Assemble burgers with sauce, salad and cheese."
            ],
            sourceURL: URL(string: "https://www.foodnerdrockstar.com/recipes/juicy-chicken-burger-recipe-and-spicy-fries")!,
            dateSaved: now
        )

        let veggieTraybake = Recipe(
            title: "Roast Veggie Traybake",
            ingredients: [
                "2 red peppers",
                "1 red onion",
                "2 courgettes",
                "200 g cherry tomatoes",
                "2 tbsp olive oil",
                "1 tsp dried mixed herbs",
                "Salt and pepper",
                "1 block feta cheese"
            ],
            steps: [
                "Preheat oven to 200°C (400°F).",
                "Chop all vegetables into bite-sized pieces and place on a baking tray.",
                "Drizzle with olive oil, sprinkle with herbs, salt and pepper and toss to coat.",
                "Roast for 25–30 minutes until tender and slightly charred.",
                "Crumble feta over the hot vegetables and serve."
            ],
            sourceURL: URL(string: "https://example.com/debug-veggie-traybake")!,
            dateSaved: now
        )

        savedRecipes = [pasta, chickenBurgers, veggieTraybake]
        persistRecipes()
        #endif
    }
}

