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
                        .onChange(of: recipeManager.savedRecipes.count) { oldCount, newCount in
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
    @State private var showingShareSheet = false
    @State private var showingCopiedToast = false
    @State private var shareMode: ShareMode = .shoppingList
    
    enum ShareMode {
        case shoppingList
        case mealPlan
    }
    
    /// Compute shopping items for sharing (same logic as ShoppingListContentView)
    private var shoppingItems: [ShoppingListItem] {
        ShoppingListItemBuilder.buildItems(from: recipes)
    }
    
    /// Get formatted text for current share mode
    private func getShareText(mode: ShareMode) -> String {
        switch mode {
        case .shoppingList:
            return ShareHelper.formatShoppingList(items: shoppingItems, recipes: recipes)
        case .mealPlan:
            return ShareHelper.formatMealPlan(recipes: recipes, shoppingItems: shoppingItems)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
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
                
                // Toast overlay
                if showingCopiedToast {
                    VStack {
                        Spacer()
                        CopiedToastView()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.spring(response: 0.3), value: showingCopiedToast)
                }
            }
            .navigationTitle("Meal Plan & Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        if allowSaving {
                            Button {
                                recipeManager.saveMealPlan(recipes)
                                showingSavedAlert = true
                            } label: {
                                Image(systemName: "star.circle.fill")
                                    .foregroundColor(RSTheme.Colors.accent)
                            }
                        }
                        
                        // Copy menu
                        Menu {
                            Button(action: {
                                UIPasteboard.general.string = getShareText(mode: .shoppingList)
                                showingCopiedToast = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showingCopiedToast = false
                                }
                            }) {
                                Label("Copy Shopping List", systemImage: "doc.on.doc")
                            }
                            
                            if recipes.count > 1 {
                                Button(action: {
                                    UIPasteboard.general.string = getShareText(mode: .mealPlan)
                                    showingCopiedToast = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        showingCopiedToast = false
                                    }
                                }) {
                                    Label("Copy Meal Plan + List", systemImage: "doc.on.doc.fill")
                                }
                            }
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(RSTheme.Colors.primary.opacity(0.7))
                        }
                        
                        // Share menu
                        Menu {
                            Button(action: {
                                shareMode = .shoppingList
                                showingShareSheet = true
                            }) {
                                Label("Share Shopping List", systemImage: "cart")
                            }
                            
                            if recipes.count > 1 {
                                Button(action: {
                                    shareMode = .mealPlan
                                    showingShareSheet = true
                                }) {
                                    Label("Share Meal Plan + List", systemImage: "list.bullet.rectangle")
                                }
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(RSTheme.Colors.primary)
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
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [getShareText(mode: shareMode)])
            }
        }
    }
}

// MARK: - Shopping List Item Model

struct ShoppingListItem: Identifiable {
    let id = UUID()
    let normalizedKey: String       // For grouping/sorting
    let displayText: String         // What to show in the list
    let originalTexts: [String]     // All original ingredient lines
    let recipeNames: [String]       // Which recipes use this
    let quantity: Double?           // Combined quantity if parseable
    let unit: String?               // Common unit
    
    var recipeCount: Int { recipeNames.count }
    var isCommon: Bool { recipeCount > 1 }
}

// MARK: - Shopping List Item Builder (shared logic)

enum ShoppingListItemBuilder {
    static func buildItems(from recipes: [Recipe]) -> [ShoppingListItem] {
        var groups: [String: (originals: [String], recipes: [String], quantities: [(Double, String?)])] = [:]
        
        for recipe in recipes {
            for ingredient in recipe.ingredients {
                guard let key = normalizedIngredientKey(from: ingredient) else { continue }
                
                let parsed = parseQuantity(from: ingredient)
                
                if groups[key] == nil {
                    groups[key] = (originals: [], recipes: [], quantities: [])
                }
                groups[key]!.originals.append(ingredient)
                groups[key]!.recipes.append(recipe.title)
                if let qty = parsed.quantity {
                    groups[key]!.quantities.append((qty, parsed.unit))
                }
            }
        }
        
        return groups.map { key, data in
            let (displayText, totalQty, unit) = buildDisplayText(
                key: key,
                originals: data.originals,
                quantities: data.quantities
            )
            
            return ShoppingListItem(
                normalizedKey: key,
                displayText: displayText,
                originalTexts: data.originals,
                recipeNames: data.recipes,
                quantity: totalQty,
                unit: unit
            )
        }.sorted { $0.recipeCount > $1.recipeCount || ($0.recipeCount == $1.recipeCount && $0.normalizedKey < $1.normalizedKey) }
    }
    
    /// Parse quantity and unit from an ingredient string
    static func parseQuantity(from ingredient: String) -> (quantity: Double?, unit: String?) {
        let text = ingredient.lowercased()
        
        let fractionMap: [Character: Double] = ["½": 0.5, "⅓": 0.333, "⅔": 0.667, "¼": 0.25, "¾": 0.75]
        
        var quantity: Double? = nil
        var unit: String? = nil
        
        let tokens = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let firstToken = tokens.first else { return (nil, nil) }
        
        if let fractionValue = fractionMap[firstToken.first!], firstToken.count == 1 {
            quantity = fractionValue
        }
        else if firstToken.count >= 2, let lastChar = firstToken.last, let fractionValue = fractionMap[lastChar] {
            if let wholeNumber = Double(String(firstToken.dropLast())) {
                quantity = wholeNumber + fractionValue
            }
        }
        else if firstToken.contains("/") {
            let parts = firstToken.split(separator: "/")
            if parts.count == 2, let num = Double(parts[0]), let denom = Double(parts[1]), denom != 0 {
                quantity = num / denom
            }
        }
        else if firstToken.contains("-") {
            let parts = firstToken.split(separator: "-")
            if parts.count == 2, let low = Double(parts[0]), let high = Double(parts[1]) {
                quantity = (low + high) / 2
            }
        }
        else if let num = Double(firstToken) {
            quantity = num
        }
        
        if tokens.count >= 2 {
            let unitCandidates: Set<String> = [
                "g", "kg", "gram", "grams", "ml", "l", "litre", "litres", "liter", "liters",
                "tbsp", "tablespoon", "tablespoons", "tsp", "teaspoon", "teaspoons",
                "cup", "cups", "oz", "ounce", "ounces", "lb", "lbs", "pound", "pounds"
            ]
            let secondToken = tokens[1].trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            if unitCandidates.contains(secondToken) {
                unit = secondToken
            }
        }
        
        return (quantity, unit)
    }
    
    /// Build display text for a shopping list item
    static func buildDisplayText(key: String, originals: [String], quantities: [(Double, String?)]) -> (String, Double?, String?) {
        if originals.count == 1 {
            let cleaned = cleanForShoppingList(originals[0])
            return (cleaned, quantities.first?.0, quantities.first?.1)
        }
        
        if !quantities.isEmpty {
            let total = quantities.reduce(0.0) { $0 + $1.0 }
            let commonUnit = quantities.compactMap { $0.1 }.first
            
            let formattedQty = total.truncatingRemainder(dividingBy: 1) == 0 
                ? String(Int(total)) 
                : String(format: "%.1f", total)
            
            let baseName = extractIngredientName(from: originals[0])
            
            if let unit = commonUnit {
                return ("\(formattedQty)\(unit) \(baseName)", total, unit)
            } else {
                let displayName = total > 1 ? pluralize(baseName) : baseName
                return ("\(formattedQty) \(displayName)", total, nil)
            }
        }
        
        return (cleanForShoppingList(originals[0]), nil, nil)
    }
    
    /// Clean an ingredient string for shopping list display
    static func cleanForShoppingList(_ ingredient: String) -> String {
        var text = ingredient
        
        while let open = text.firstIndex(of: "(") {
            if let close = text[open...].firstIndex(of: ")") {
                text.removeSubrange(open...close)
            } else {
                break
            }
        }
        
        let commaParts = text.components(separatedBy: ",")
        if commaParts.count > 1 {
            let firstPart = commaParts[0].trimmingCharacters(in: .whitespaces)
            if containsIngredientNoun(firstPart) {
                text = firstPart
            }
        }
        
        if let forRange = text.range(of: " for ", options: .caseInsensitive) {
            text = String(text[..<forRange.lowerBound])
        }
        
        let prepWords = [
            "beaten", "whisked", "chopped", "diced", "minced", "sliced", "crushed",
            "peeled", "grated", "shredded", "melted", "softened", "sifted",
            "halved", "quartered", "cubed", "mashed", "mixed"
        ]
        
        var words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        while let lastWord = words.last?.lowercased().trimmingCharacters(in: .punctuationCharacters),
              prepWords.contains(lastWord) {
            words.removeLast()
        }
        
        text = words.joined(separator: " ")
        
        text = text.trimmingCharacters(in: .whitespaces)
        while text.hasSuffix(",") || text.hasSuffix(";") {
            text = String(text.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        
        return text.isEmpty ? ingredient : text
    }
    
    static func containsIngredientNoun(_ text: String) -> Bool {
        let units: Set<String> = ["g", "kg", "ml", "l", "tbsp", "tsp", "cup", "cups", "oz", "lb", "fl"]
        let fractionChars = CharacterSet(charactersIn: "½⅓⅔¼¾/0123456789.-")
        
        let words = text.lowercased().components(separatedBy: .whitespaces)
        for word in words {
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            if cleaned.isEmpty { continue }
            if units.contains(cleaned) { continue }
            if cleaned.unicodeScalars.allSatisfy({ fractionChars.contains($0) }) { continue }
            return true
        }
        return false
    }
    
    static func extractIngredientName(from ingredient: String) -> String {
        let cleaned = cleanForShoppingList(ingredient).lowercased()
        
        let tokens = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        let units: Set<String> = [
            "g", "kg", "gram", "grams", "ml", "l", "litre", "litres",
            "tbsp", "tablespoon", "tablespoons", "tsp", "teaspoon", "teaspoons",
            "cup", "cups", "oz", "ounce", "ounces", "lb", "lbs", "fl"
        ]
        let fractionChars = CharacterSet(charactersIn: "½⅓⅔¼¾/0123456789.-")
        
        var nameTokens: [String] = []
        var foundName = false
        
        for token in tokens {
            if !foundName && token.unicodeScalars.allSatisfy({ fractionChars.contains($0) }) {
                continue
            }
            if !foundName && units.contains(token) {
                continue
            }
            foundName = true
            nameTokens.append(token)
        }
        
        return nameTokens.joined(separator: " ")
    }
    
    static func pluralize(_ word: String) -> String {
        let lower = word.lowercased()
        
        if lower.hasSuffix("s") && !lower.hasSuffix("ss") {
            return word
        }
        
        let irregulars: [String: String] = [
            "leaf": "leaves", "loaf": "loaves", "half": "halves",
            "potato": "potatoes", "tomato": "tomatoes",
            "berry": "berries", "cherry": "cherries"
        ]
        if let plural = irregulars[lower] {
            return plural
        }
        
        if lower.hasSuffix("y") && lower.count > 2 {
            let beforeY = lower[lower.index(lower.endIndex, offsetBy: -2)]
            if !"aeiou".contains(beforeY) {
                return String(word.dropLast()) + "ies"
            }
        }
        
        return word + "s"
    }
}

struct ShoppingListContentView: View {
    let recipes: [Recipe]
    let isPreview: Bool
    
    /// Build a proper shopping list with combined quantities
    var shoppingItems: [ShoppingListItem] {
        ShoppingListItemBuilder.buildItems(from: recipes)
    }
    
    var body: some View {
        let commonItems = shoppingItems.filter { $0.isCommon }
        let uniqueItems = shoppingItems.filter { !$0.isCommon }
        
        List {
            if !commonItems.isEmpty {
                Section {
                    ForEach(commonItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.displayText)
                                    .rsBody()
                                Spacer()
                                Text("\(item.recipeCount) recipes")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(RSTheme.Colors.accent)
                                    .cornerRadius(8)
                            }
                            if !isPreview {
                                Text("For: \(item.recipeNames.joined(separator: ", "))")
                                    .rsCaption()
                            }
                        }
                    }
                } header: {
                    Text("Common Ingredients (\(commonItems.count))")
                } footer: {
                    Text("These ingredients are used in multiple recipes - buy in bulk!")
                }
            } else if !recipes.isEmpty && recipes.count > 1 {
                Section {
                    Text("These recipes don't share any ingredients yet.\n\nFor an easier shop, try swapping one of the meals or tap \"Auto Plan\" in Meal Planner.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Unique ingredients (used in 1 recipe only)
            if !uniqueItems.isEmpty && !isPreview {
                Section {
                    ForEach(uniqueItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayText)
                                .rsBody()
                            Text("For: \(item.recipeNames.first ?? "")")
                                .rsCaption()
                        }
                    }
                } header: {
                    Text(recipes.count == 1 ? "Ingredients (\(uniqueItems.count))" : "Unique Ingredients (\(uniqueItems.count))")
                } footer: {
                    if recipes.count > 1 {
                        Text("These ingredients are only needed for one recipe")
                    }
                }
            }
            
            // Summary (only for multiple recipes)
            if recipes.count > 1 {
                Section {
                    HStack {
                        Text("Ingredients shared between recipes")
                        Spacer()
                        Text("\(commonItems.count)")
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
}

// MARK: - Ingredient Normalisation Helper (for grouping only)

/// Turn a free-text ingredient line into a coarse "ingredient key" for GROUPING purposes.
/// This is used to match similar ingredients across recipes (e.g., "2 chicken breasts" 
/// and "3 free-range chicken breasts" should group together as "chicken breast").
/// The key is NOT displayed - original text is shown in the shopping list.
fileprivate func normalizedIngredientKey(from raw: String) -> String? {
    var text = raw.lowercased()
    
    // Remove parenthetical content like "(optional)" or "(alternatively use...)"
    while let open = text.firstIndex(of: "(") {
        if let close = text[open...].firstIndex(of: ")") {
            text.removeSubrange(open...close)
        } else {
            break
        }
    }
    
    // Keep only letters and spaces
    let allowed = CharacterSet.letters.union(.whitespaces)
    text = String(text.unicodeScalars.filter { allowed.contains($0) })
    
    // Words to skip when building the grouping key
    let skipWords: Set<String> = [
        // Units
        "g", "kg", "gram", "grams", "ml", "l", "litre", "litres", "liter", "liters",
        "tbsp", "tablespoon", "tablespoons", "tsp", "teaspoon", "teaspoons",
        "cup", "cups", "oz", "ounce", "ounces", "fl", "lb", "lbs", "pound", "pounds",
        "slice", "slices", "can", "cans", "packet", "packets", "tin", "tins",
        "bunch", "bunches", "handful", "handfuls", "pinch", "pinches", "clove", "cloves",
        // Descriptors
        "fresh", "freshly", "dried", "chopped", "sliced", "diced", "minced", "crushed",
        "peeled", "grated", "shredded", "cooked", "uncooked", "steamed", "boiled", 
        "fried", "roasted", "baked", "beaten", "whisked", "mixed", "mashed", "softened",
        "melted", "sifted", "cubed", "halved", "quartered",
        "cold", "warm", "hot", "leftover", "leftovers", "frozen", "room", "temperature", "chilled",
        "large", "small", "medium", "extra", "fine", "coarse", "roughly", "finely", 
        "thinly", "thickly", "lightly", "whole", "half", "quarter",
        "to", "taste", "of", "and", "or", "from", "for", "the", "a", "an", "about",
        "approx", "approximately", "around", "plus", "into", "with", "on", "in", "as",
        "needed", "some", "few", "optional", "preferably", "alternatively", "use", "more",
        "free", "range", "plain", "light", "dark", "good", "quality"
    ]
    
    // Purpose words that shouldn't be the key alone
    let purposeWords: Set<String> = [
        "glazing", "glaze", "coating", "topping", "garnish", "serving", "decoration", "dusting"
    ]
    
    let tokens = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    
    // Extract core ingredient words
    var core: [String] = []
    for token in tokens {
        if skipWords.contains(token) { continue }
        if Double(token) != nil { continue }
        if purposeWords.contains(token) { continue }
        core.append(token)
    }
    
    // If empty, try to find noun before "for"
    if core.isEmpty {
        var foundFor = false
        for token in tokens.reversed() {
            if token == "for" { foundFor = true; continue }
            if foundFor && !skipWords.contains(token) && Double(token) == nil {
                core.append(token)
                break
            }
        }
    }
    
    guard !core.isEmpty else { return nil }
    
    // Singularize for consistent grouping
    func singularize(_ word: String) -> String {
        let irregulars: [String: String] = [
            "leaves": "leaf", "loaves": "loaf", "halves": "half",
            "potatoes": "potato", "tomatoes": "tomato",
            "berries": "berry", "cherries": "cherry", "anchovies": "anchovy",
            "breasts": "breast", "thighs": "thigh", "wings": "wing", "legs": "leg"
        ]
        if let irregular = irregulars[word] { return irregular }
        
        if word.hasSuffix("ies") && word.count > 4 {
            return String(word.dropLast(3)) + "y"
        }
        if word.hasSuffix("ves") && word.count > 4 {
            return String(word.dropLast(3)) + "f"
        }
        if word.hasSuffix("es") && word.count > 4 {
            let base = String(word.dropLast(2))
            if base.hasSuffix("s") || base.hasSuffix("x") || base.hasSuffix("z") ||
               base.hasSuffix("ch") || base.hasSuffix("sh") {
                return base
            }
        }
        if word.hasSuffix("s") && word.count > 3 && !word.hasSuffix("ss") {
            return String(word.dropLast())
        }
        return word
    }
    
    // Build key from last 2-3 meaningful words (where the actual ingredient usually is)
    let normalized = core.map { singularize($0) }
    
    // Compound tails that need preceding context
    let compoundTails: Set<String> = [
        "sauce", "powder", "paste", "stock", "broth", "cream", "cheese",
        "cube", "leaf", "bean", "seed", "oil", "flour", "sugar", "milk",
        "juice", "zest", "peel", "extract", "essence", "breast", "thigh", "wing", "leg"
    ]
    
    let lastIdx = normalized.count - 1
    let lastWord = normalized[lastIdx]
    
    if compoundTails.contains(lastWord) && normalized.count >= 2 {
        let startIdx = max(0, lastIdx - 2)
        return Array(normalized[startIdx...lastIdx]).joined(separator: " ")
    } else if normalized.count >= 2 {
        let startIdx = max(0, lastIdx - 1)
        return Array(normalized[startIdx...lastIdx]).joined(separator: " ")
    } else {
        return lastWord
    }
}

