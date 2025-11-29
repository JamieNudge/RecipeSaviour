import SwiftUI

struct MealPlannerView: View {
    @EnvironmentObject var recipeManager: RecipeManager
    @State private var selectedRecipes: Set<UUID> = []
    @State private var showingShoppingList = false
    @State private var autoMealCount: Int = 3
    @State private var lastGeneratedPlan: Set<UUID> = []
    
    var body: some View {
        NavigationView {
            ZStack {
                RSTheme.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if recipeManager.savedRecipes.isEmpty {
                        emptyStateView
                    } else {
                        recipeSelectionView
                    }
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
                ShoppingListView(recipes: selectedRecipesArray, allowSaving: true)
                    .environmentObject(recipeManager)
            }
        }
    }
    
    private var selectedRecipesArray: [Recipe] {
        recipeManager.savedRecipes.filter { selectedRecipes.contains($0.id) }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: RSTheme.Spacing.lg) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(RSTheme.Colors.primary.opacity(0.7))
            Text("No saved recipes yet")
                .font(RSTheme.Typography.sectionTitle)
                .foregroundColor(RSTheme.Colors.textPrimary)
            Text("Save some recipes first to start meal planning")
                .rsSecondary()
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var recipeSelectionView: some View {
        VStack(alignment: .leading, spacing: RSTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: RSTheme.Spacing.sm) {
                Text("Plan your week's meals")
                    .rsSectionTitle()
                Text("We'll pick meals with variety but shared ingredients to make shopping easier")
                    .rsSecondary()

                // Auto-planning controls
                HStack(spacing: RSTheme.Spacing.md) {
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
                        if !selectedRecipesArray.isEmpty {
                            showingShoppingList = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Plan My Week")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RSTheme.Colors.accent)
                    .disabled(recipeManager.savedRecipes.count < 1)
                }
                .font(.footnote)
            }
            .padding()
            
            List {
                ForEach(recipeManager.savedRecipes.sorted(by: { $0.dateSaved > $1.dateSaved })) { recipe in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedRecipes.contains(recipe.id) {
                                selectedRecipes.remove(recipe.id)
                            } else {
                                selectedRecipes.insert(recipe.id)
                            }
                        }
                    }) {
                        HStack(spacing: RSTheme.Spacing.md) {
                            Image(systemName: selectedRecipes.contains(recipe.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedRecipes.contains(recipe.id) ? RSTheme.Colors.accent : .secondary)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recipe.title)
                                    .font(.headline)
                                Text("\(recipe.ingredients.count) ingredients")
                                    .rsCaption()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollContentBackground(.hidden)
            .background(RSTheme.Colors.background)
            .listStyle(.insetGrouped)
            
            if !selectedRecipes.isEmpty {
            VStack(alignment: .leading, spacing: RSTheme.Spacing.sm) {
                    Text("\(selectedRecipesArray.count) meals selected")
                    .font(.subheadline.weight(.semibold))
                    Text("View your planned meals and full shopping list with all the shared ingredients.")
                    .rsCaption()
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Button {
                        showingShoppingList = true
                    } label: {
                        Text("View Plan & Shopping List")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                        .background(RSTheme.Colors.primary)
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
        
        // For reasonably-sized libraries, search combinations to maximise shared ingredients.
        // If too many recipes, fall back to greedy selection.
        let useBruteForce = recipes.count <= 14 && targetCount > 1
        
        let chosenIndices: [Int]
        
        if useBruteForce {
            // Score for a group of indices = sum of pairwise overlaps
            func totalOverlapScore(for indices: [Int]) -> Int {
                var score = 0
                if indices.count < 2 { return 0 }
                for i in 0..<(indices.count - 1) {
                    for j in (i + 1)..<indices.count {
                        score += overlapScore(between: indices[i], and: indices[j])
                    }
                }
                return score
            }
            
            var bestCombos: [[Int]] = []
            var bestScore = -1
            
            var current: [Int] = []
            func generate(start: Int) {
                if current.count == targetCount {
                    let score = totalOverlapScore(for: current)
                    if score > bestScore {
                        bestScore = score
                        bestCombos = [current]
                    } else if score == bestScore {
                        bestCombos.append(current)
                    }
                    return
                }
                guard start < recipes.count else { return }
                
                for i in start..<recipes.count {
                    current.append(i)
                    generate(start: i + 1)
                    current.removeLast()
                }
            }
            
            generate(start: 0)
            
            // Choose the best combination; if there are multiple best, prefer one
            // that differs from the last plan to give variety.
            if !bestCombos.isEmpty {
                var candidateSets: [Set<UUID>] = bestCombos.map { combo in
                    Set(combo.map { recipes[$0].id })
                }
                
                if candidateSets.count > 1, !lastGeneratedPlan.isEmpty {
                    if let idx = candidateSets.firstIndex(where: { $0 != lastGeneratedPlan }) {
                        chosenIndices = bestCombos[idx]
                    } else {
                        chosenIndices = bestCombos[0]
                    }
                } else {
                    chosenIndices = bestCombos[0]
                }
            } else {
                // Fallback: if for some reason no combo found, just take the first N
                chosenIndices = Array(0..<targetCount)
            }
        } else {
            // Greedy fallback for large libraries
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
            
            while selectedIndices.count < targetCount,
                  let nextIndex = remaining.max(by: { a, b in
                      let scoreA = selectedIndices.reduce(0) { $0 + overlapScore(between: a, and: $1) }
                      let scoreB = selectedIndices.reduce(0) { $0 + overlapScore(between: b, and: $1) }
                      if scoreA == scoreB {
                          return ingredientSets[a].count < ingredientSets[b].count
                      }
                      return scoreA < scoreB
                  }) {
                selectedIndices.append(nextIndex)
                remaining.remove(nextIndex)
            }
            
            chosenIndices = selectedIndices
        }
        
        let chosenSet = Set(chosenIndices.map { recipes[$0].id })
        
        withAnimation(.easeInOut) {
            selectedRecipes = chosenSet
        }
        lastGeneratedPlan = chosenSet
    }
    
}

struct ShoppingListView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var recipeManager: RecipeManager
    let recipes: [Recipe]
    let allowSaving: Bool
    
    @State private var showingSavedAlert = false
    
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
                                        .rsCaption()
                                        .lineLimit(2)
                                    Text("\(recipe.ingredients.count) ingredients")
                                        .rsCaption()
                                }
                                .padding(8)
                                .background(RSTheme.Colors.card)
                                .cornerRadius(8)
                                .frame(width: 140)
                            }
                        }
                        .padding()
                    }
                    .background(RSTheme.Colors.background)
                    
                    Divider()
                }
                
                // Full shopping list with common-ingredient analysis
                ShoppingListContentView(recipes: recipes, isPreview: false)
            }
            .navigationTitle("Meal Plan & Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if allowSaving {
                        Button {
                            recipeManager.saveMealPlan(recipes)
                            showingSavedAlert = true
                        } label: {
                            Image(systemName: "star.circle.fill")
                                .foregroundColor(RSTheme.Colors.accent)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Plan Saved", isPresented: $showingSavedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This meal plan has been added to Favourite Plans.")
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
                                    .rsBody()
                                Spacer()
                                Text("\(count) recipes")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(RSTheme.Colors.accent)
                                    .cornerRadius(8)
                            }
                            if !isPreview {
                                Text("Used in: \(ingredientAnalysis.unique[ingredient]?.joined(separator: ", ") ?? "")")
                                    .rsCaption()
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
                                .rsBody()
                            Text("For: \(ingredientAnalysis.unique[ingredient]?.first ?? "")")
                                .rsCaption()
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

