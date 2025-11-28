import SwiftUI

struct MealPlannerView: View {
    @EnvironmentObject var recipeManager: RecipeManager
    @State private var selectedRecipes: Set<UUID> = []
    @State private var showingShoppingList = false
    @State private var autoMealCount: Int = 3
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if recipeManager.savedRecipes.isEmpty {
                    emptyStateView
                } else {
                    recipeSelectionView
                }
            }
            .navigationTitle("Meal Planner")
            .toolbar {
                if !selectedRecipes.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear") {
                            selectedRecipes.removeAll()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingShoppingList) {
                ShoppingListView(recipes: selectedRecipesArray)
                    .environmentObject(recipeManager)
            }
        }
    }
    
    private var selectedRecipesArray: [Recipe] {
        recipeManager.savedRecipes.filter { selectedRecipes.contains($0.id) }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No saved recipes yet")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Save some recipes first to start meal planning")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var recipeSelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Plan your week's meals")
                    .font(.headline)
                Text("We'll pick meals with variety but shared ingredients to make shopping easier")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Auto-planning controls
                HStack(spacing: 12) {
                    let maxMeals = max(1, min(7, recipeManager.savedRecipes.count))
                    Stepper("Meals this week: \(autoMealCount)", value: $autoMealCount, in: 1...maxMeals)
                        .onChange(of: recipeManager.savedRecipes.count) { newCount in
                            let newMax = max(1, min(7, newCount))
                            if autoMealCount > newMax {
                                autoMealCount = newMax
                            }
                        }

                    Button {
                        generateSmartPlan()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Plan My Week")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(recipeManager.savedRecipes.count < 1)
                }
                .font(.footnote)
            }
            .padding()
            
            List {
                ForEach(recipeManager.savedRecipes.sorted(by: { $0.dateSaved > $1.dateSaved })) { recipe in
                    Button(action: {
                        if selectedRecipes.contains(recipe.id) {
                            selectedRecipes.remove(recipe.id)
                        } else {
                            selectedRecipes.insert(recipe.id)
                        }
                    }) {
                        HStack {
                            Image(systemName: selectedRecipes.contains(recipe.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedRecipes.contains(recipe.id) ? .blue : .secondary)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recipe.title)
                                    .font(.headline)
                                Text("\(recipe.ingredients.count) ingredients")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if !selectedRecipes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(selectedRecipesArray.count) meals selected")
                        .font(.subheadline.weight(.semibold))
                    Text("View your planned meals and full shopping list with all the shared ingredients.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Button {
                        showingShoppingList = true
                    } label: {
                        Text("View Plan & Shopping List")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
        }
    }

    /// Automatically pick a set of recipes (of size autoMealCount) that share
    /// as many ingredients as possible, to minimise the overall shopping list.
    private func generateSmartPlan() {
        let recipes = recipeManager.savedRecipes
        guard !recipes.isEmpty else { return }

        let targetCount = min(autoMealCount, recipes.count)
        if targetCount == 0 {
            return
        }

        // Normalised ingredient sets for each recipe
        let ingredientSets: [Set<String>] = recipes.map { recipe in
            Set(
                recipe.ingredients.compactMap { normalizedIngredientKey(from: $0) }
            )
        }

        func overlapScore(between i: Int, and j: Int) -> Int {
            ingredientSets[i].intersection(ingredientSets[j]).count
        }

        // If only one meal requested, just pick the recipe with the most ingredients
        if targetCount == 1 {
            if let bestIndex = ingredientSets.enumerated().max(by: { $0.element.count < $1.element.count })?.offset {
                selectedRecipes = [recipes[bestIndex].id]
            }
            return
        }

        // Choose a starting recipe whose ingredients overlap most with others
        var scores: [Int] = Array(repeating: 0, count: recipes.count)
        for i in 0..<recipes.count {
            var total = 0
            for j in 0..<recipes.count where j != i {
                total += overlapScore(between: i, and: j)
            }
            scores[i] = total
        }

        guard let startIndex = scores.enumerated().max(by: { $0.element < $1.element })?.offset else {
            return
        }

        var selectedIndices: [Int] = [startIndex]
        var remaining = Set(0..<recipes.count)
        remaining.remove(startIndex)

        // Greedily add recipes that maximise overlap with the already selected set
        while selectedIndices.count < targetCount, let nextIndex = remaining.max(by: { a, b in
            let scoreA = selectedIndices.reduce(0) { $0 + overlapScore(between: a, and: $1) }
            let scoreB = selectedIndices.reduce(0) { $0 + overlapScore(between: b, and: $1) }
            if scoreA == scoreB {
                // Tie-breaker: prefer the one with more ingredients
                return ingredientSets[a].count < ingredientSets[b].count
            }
            return scoreA < scoreB
        }) {
            selectedIndices.append(nextIndex)
            remaining.remove(nextIndex)
        }

        // Update selectedRecipes with the chosen plan
        let chosenIDs = selectedIndices.map { recipes[$0].id }
        selectedRecipes = Set(chosenIDs)
    }
    
}

struct ShoppingListView: View {
    @Environment(\.dismiss) var dismiss
    let recipes: [Recipe]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Planned meals summary
                if !recipes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(recipes) { recipe in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recipe.title)
                                        .font(.caption)
                                        .lineLimit(2)
                                    Text("\(recipe.ingredients.count) ingredients")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                .frame(width: 140)
                            }
                        }
                        .padding()
                    }
                    .background(Color(UIColor.systemGroupedBackground))
                    
                    Divider()
                }
                
                // Full shopping list with common-ingredient analysis
                ShoppingListContentView(recipes: recipes, isPreview: false)
            }
            .navigationTitle("Meal Plan & Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ShoppingListContentView: View {
    let recipes: [Recipe]
    let isPreview: Bool
    
    var ingredientAnalysis: (common: [String: Int], unique: [String: [String]]) {
        var ingredientCount: [String: Int] = [:]
        var ingredientToRecipes: [String: [String]] = [:]
        
        for recipe in recipes {
            for ingredient in recipe.ingredients {
                guard let key = normalizedIngredientKey(from: ingredient) else { continue }
                ingredientCount[key, default: 0] += 1
                ingredientToRecipes[key, default: []].append(recipe.title)
            }
        }
        
        return (ingredientCount, ingredientToRecipes)
    }
    
    var body: some View {
        List {
            // Precompute groupings
            let commonIngredients = ingredientAnalysis.common
                .filter { $0.value > 1 }
                .sorted { $0.value > $1.value }
            let uniqueIngredients = ingredientAnalysis.common
                .filter { $0.value == 1 }
                .sorted { $0.key < $1.key }
            
            if !commonIngredients.isEmpty {
                Section {
                    ForEach(commonIngredients, id: \.key) { ingredient, count in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(ingredient.capitalized)
                                    .font(.body)
                                Spacer()
                                Text("\(count) recipes")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .cornerRadius(8)
                            }
                            if !isPreview {
                                Text("Used in: \(ingredientAnalysis.unique[ingredient]?.joined(separator: ", ") ?? "")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Common Ingredients (\(commonIngredients.count))")
                } footer: {
                    Text("These ingredients are used in multiple recipes - buy in bulk!")
                }
            } else if !recipes.isEmpty {
                // Make it obvious when there is *no* overlap yet
                Section {
                    Text("These recipes don't share any ingredients yet.\n\nFor an easier shop, try swapping one of the meals or tap “Auto Plan” in Meal Planner.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Unique ingredients (used in 1 recipe only)
            if !uniqueIngredients.isEmpty && !isPreview {
                Section {
                    ForEach(uniqueIngredients, id: \.key) { ingredient, _ in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ingredient.capitalized)
                                .font(.body)
                            Text("For: \(ingredientAnalysis.unique[ingredient]?.first ?? "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Unique Ingredients (\(uniqueIngredients.count))")
                } footer: {
                    Text("These ingredients are only needed for one recipe")
                }
            }
            
            // Summary
            Section {
                HStack {
                    Text("Ingredients shared between recipes")
                    Spacer()
                    Text("\(commonIngredients.count)")
                        .fontWeight(.bold)
                }
                HStack {
                    Text("Recipes Selected")
                    Spacer()
                    Text("\(recipes.count)")
                        .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Ingredient Normalisation Helper

/// Turn a free-text ingredient line into a coarse "ingredient key"
/// so that similar lines (e.g. "2 tbsp soy sauce" vs "1 tbsp light soy sauce")
/// are treated as the same base ingredient ("soy sauce").
fileprivate func normalizedIngredientKey(from raw: String) -> String? {
    // Lowercase and strip parentheses content to reduce noise
    var text = raw.lowercased()
    
    // Remove simple parenthetical notes like "(optional)"
    if let open = text.firstIndex(of: "(") {
        let afterOpen = text.index(after: open)
        if let close = text[afterOpen...].firstIndex(of: ")") {
            text.removeSubrange(open...close)
        }
    }
    
    // Keep only letters and spaces
    let allowed = CharacterSet.letters.union(.whitespaces)
    text = String(text.unicodeScalars.filter { allowed.contains($0) })
    
    let units: Set<String> = [
        "g","kg","gram","grams",
        "ml","l",
        "tbsp","tablespoon","tablespoons",
        "tsp","teaspoon","teaspoons",
        "cup","cups",
        "oz","ounce","ounces",
        "clove","cloves",
        "slice","slices",
        "can","cans",
        "packet","packets","tin","tins"
    ]
    
    let descriptors: Set<String> = [
        // Prep / texture
        "fresh","freshly","dried","chopped","sliced","diced","minced","crushed",
        "peeled","grated","shredded","cooked","uncooked","steamed","boiled","fried","roasted","baked",
        "beaten","whisked","mixed","mashed",
        // State / leftovers
        "cold","warm","hot","leftover","leftovers","frozen",
        // Size / amount adjectives
        "large","small","medium","extra","fine","coarse","roughly","finely","thinly","thickly","lightly",
        // Filler / stop-words
        "to","taste","of","and","or","from","for","the","a","an","about","approx","approximately","around",
        "plus","into","with","on","in",
        // Time-ish
        "yesterday","today","tomorrow",
        // Misc
        "optional","preferably"
    ]
    
    let tokens = text
        .components(separatedBy: .whitespacesAndNewlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    
    var core: [String] = []
    for token in tokens {
        // Skip tokens that are measurement-ish or descriptive
        if units.contains(token) || descriptors.contains(token) {
            continue
        }
        // Skip pure numbers
        if Double(token) != nil {
            continue
        }
        // Keep this as a candidate noun-ish token
        core.append(token)
    }
    
    guard !core.isEmpty else { return nil }
    
    // Focus on the "tail" of the phrase, where the actual ingredient noun usually is.
    func singularised(_ word: String) -> String {
        // Very light singularisation for simple plurals: "eggs" -> "egg", "peas" -> "pea"
        if word.hasSuffix("es"), word.count > 4 {
            return String(word.dropLast(2))
        }
        if word.hasSuffix("s"), word.count > 3 {
            return String(word.dropLast())
        }
        return word
    }
    
    let lastRaw = core.last!
    let last = singularised(lastRaw)
    let secondLastRaw: String? = core.count >= 2 ? core[core.count - 2] : nil
    let secondLast = secondLastRaw.map(singularised)
    
    // For generic container words like "sauce" or "broth", include one word before it
    let compoundTails: Set<String> = ["sauce","powder","paste","stock","broth","cream","cheese"]
    
    var keyParts: [String] = []
    if compoundTails.contains(last), let secondLast = secondLast {
        keyParts.append(secondLast)
        keyParts.append(last)
    } else {
        keyParts.append(last)
    }
    
    let key = keyParts.joined(separator: " ")
    return key.trimmingCharacters(in: .whitespacesAndNewlines)
}

