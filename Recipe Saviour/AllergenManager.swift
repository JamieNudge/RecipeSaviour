//
//  AllergenManager.swift
//  Recipe Saviour
//
//  Manages allergen profile, detection, and substitution suggestions.
//
//  ⚠️ CRITICAL SAFETY NOTES:
//  - This is an ASSISTANCE tool only, NOT a safety guarantee
//  - Cannot detect cross-contamination or "may contain" warnings
//  - Cannot guarantee complete detection of all allergen forms
//  - Users MUST always read food labels and verify ingredients
//

import Foundation
import Combine

@MainActor
class AllergenManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published var profile: AllergenProfile
    @Published var isLoading: Bool = false
    
    // MARK: - Persistence
    
    private let persistenceKey = "allergenProfile"
    
    // MARK: - Singleton
    
    static let shared = AllergenManager()
    
    // MARK: - Disclaimer Text (shown to user)
    
    static let disclaimerText = """
    ⚠️ IMPORTANT - PLEASE READ CAREFULLY
    
    Recipe Saviour's allergen detection is an ASSISTANCE TOOL ONLY. It is NOT a substitute for reading food labels or consulting with medical professionals.
    
    LIMITATIONS:
    • Cannot detect cross-contamination risks
    • Cannot detect "may contain traces of" warnings
    • Cannot guarantee detection of all allergen forms or derivatives
    • Recipe extraction may miss or misinterpret ingredients
    • Substitution suggestions may not be safe for all individuals
    
    YOUR RESPONSIBILITY:
    • ALWAYS read actual food labels before consuming
    • Verify all ingredients with original recipe sources
    • Consult your allergist or doctor about safe substitutions
    • When in doubt, do not consume
    
    By using this feature, you acknowledge that:
    1. You understand these limitations
    2. You will verify all allergen information independently
    3. Recipe Saviour is not liable for allergic reactions
    
    This feature is designed to HELP you spot potential allergens, not to replace proper food safety practices.
    """
    
    static let shortDisclaimer = "⚠️ Allergen detection is an assistance tool only. Always read food labels and verify ingredients. Cannot detect cross-contamination."
    
    // MARK: - Initialization
    
    private init() {
        self.profile = AllergenProfile()
        loadProfile()
    }
    
    // MARK: - Profile Management
    
    /// Reset profile to defaults (all allergens inactive)
    func resetToDefaults() {
        profile = DefaultAllergens.createDefaultProfile()
        profile.hasCompletedSetup = false
        profile.acknowledgedDisclaimer = false
        saveProfile()
    }
    
    /// Mark setup as complete
    func completeSetup() {
        profile.hasCompletedSetup = true
        profile.lastUpdated = Date()
        saveProfile()
    }
    
    /// Acknowledge disclaimer
    func acknowledgeDisclaimer() {
        profile.acknowledgedDisclaimer = true
        profile.lastUpdated = Date()
        saveProfile()
    }
    
    /// Toggle an allergen's active state
    func toggleAllergen(_ allergen: Allergen) {
        if let index = profile.allergens.firstIndex(where: { $0.id == allergen.id }) {
            profile.allergens[index].isActive.toggle()
            profile.lastUpdated = Date()
            saveProfile()
        }
    }
    
    /// Add a custom keyword to an allergen
    func addCustomKeyword(_ keyword: String, to allergen: Allergen) {
        let cleanedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanedKeyword.isEmpty else { return }
        
        if let index = profile.allergens.firstIndex(where: { $0.id == allergen.id }) {
            // Don't add duplicates
            if !profile.allergens[index].allKeywords.contains(cleanedKeyword) {
                profile.allergens[index].customKeywords.append(cleanedKeyword)
                profile.lastUpdated = Date()
                saveProfile()
            }
        }
    }
    
    /// Remove a custom keyword from an allergen
    func removeCustomKeyword(_ keyword: String, from allergen: Allergen) {
        if let index = profile.allergens.firstIndex(where: { $0.id == allergen.id }) {
            profile.allergens[index].customKeywords.removeAll { $0 == keyword }
            profile.lastUpdated = Date()
            saveProfile()
        }
    }
    
    /// Add a completely new allergen
    func addCustomAllergen(name: String, keywords: [String]) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return }
        
        let cleanedKeywords = keywords.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        
        let newAllergen = Allergen(
            name: cleanedName,
            isActive: true,
            builtInKeywords: [],
            customKeywords: cleanedKeywords
        )
        
        profile.allergens.append(newAllergen)
        profile.lastUpdated = Date()
        saveProfile()
    }
    
    /// Delete a custom allergen (only user-added allergens can be deleted)
    func deleteAllergen(_ allergen: Allergen) {
        // Check if it's a default allergen (has built-in keywords)
        // Default allergens can only be deactivated, not deleted
        if allergen.builtInKeywords.isEmpty {
            profile.allergens.removeAll { $0.id == allergen.id }
            profile.lastUpdated = Date()
            saveProfile()
        }
    }
    
    // MARK: - Substitution Management
    
    /// Add a custom substitution
    func addSubstitution(allergenName: String, originalKeyword: String, substitutionText: String, notes: String?) {
        let substitution = Substitution(
            allergenName: allergenName,
            originalKeyword: originalKeyword.lowercased(),
            substitutionText: substitutionText,
            notes: notes,
            isUserAdded: true
        )
        
        profile.substitutions.append(substitution)
        profile.lastUpdated = Date()
        saveProfile()
    }
    
    /// Delete a substitution
    func deleteSubstitution(_ substitution: Substitution) {
        profile.substitutions.removeAll { $0.id == substitution.id }
        saveProfile()
    }
    
    // MARK: - Allergen Detection
    
    /// Scan a list of ingredients for allergens
    /// Returns matches grouped by allergen
    func scanIngredients(_ ingredients: [String], forRecipe recipeId: UUID? = nil) -> [AllergenMatch] {
        guard profile.hasActiveAllergens else { return [] }
        
        var matches: [AllergenMatch] = []
        
        for (index, ingredient) in ingredients.enumerated() {
            let ingredientLower = ingredient.lowercased()
            
            // Check if this warning was dismissed for this specific recipe
            if let recipeId = recipeId {
                let dismissKey = "\(recipeId.uuidString)-\(index)"
                if profile.dismissedWarnings.contains(dismissKey) {
                    continue
                }
            }
            
            for allergen in profile.activeAllergens {
                for keyword in allergen.allKeywords {
                    // Use word boundary matching to avoid false positives
                    // e.g., "corn" shouldn't match "corner"
                    if ingredientContainsKeyword(ingredientLower, keyword: keyword) {
                        let match = AllergenMatch(
                            allergen: allergen,
                            matchedKeyword: keyword,
                            ingredientText: ingredient,
                            ingredientIndex: index
                        )
                        
                        // Avoid duplicate matches for the same ingredient/allergen combo
                        if !matches.contains(where: { 
                            $0.ingredientIndex == index && $0.allergen.id == allergen.id 
                        }) {
                            matches.append(match)
                        }
                        break // Only need one match per allergen per ingredient
                    }
                }
            }
        }
        
        return matches
    }
    
    /// Check if an ingredient contains a keyword (word boundary aware)
    private func ingredientContainsKeyword(_ ingredient: String, keyword: String) -> Bool {
        // Try exact word match first with word boundaries
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(ingredient.startIndex..., in: ingredient)
            if regex.firstMatch(in: ingredient, options: [], range: range) != nil {
                return true
            }
        }
        
        // Also check for common suffixes (e.g., "almond" matches "almonds")
        let keywordWithS = keyword + "s"
        let patternWithS = "\\b\(NSRegularExpression.escapedPattern(for: keywordWithS))\\b"
        if let regex = try? NSRegularExpression(pattern: patternWithS, options: .caseInsensitive) {
            let range = NSRange(ingredient.startIndex..., in: ingredient)
            if regex.firstMatch(in: ingredient, options: [], range: range) != nil {
                return true
            }
        }
        
        return false
    }
    
    /// Get substitution suggestions for a matched allergen keyword
    func getSubstitutions(for match: AllergenMatch) -> [Substitution] {
        return profile.substitutions.filter { substitution in
            // Match by allergen name or by the specific keyword
            substitution.allergenName == match.allergen.name ||
            substitution.originalKeyword == match.matchedKeyword
        }
    }
    
    /// Get all substitutions for a specific allergen
    func getSubstitutions(for allergen: Allergen) -> [Substitution] {
        return profile.substitutions.filter { $0.allergenName == allergen.name }
    }
    
    // MARK: - Warning Dismissal
    
    /// Dismiss a specific warning for a specific recipe
    /// Requires confirmation in the UI before calling
    func dismissWarning(forRecipeId recipeId: UUID, ingredientIndex: Int) {
        let key = "\(recipeId.uuidString)-\(ingredientIndex)"
        if !profile.dismissedWarnings.contains(key) {
            profile.dismissedWarnings.append(key)
            saveProfile()
        }
    }
    
    /// Restore a dismissed warning
    func restoreWarning(forRecipeId recipeId: UUID, ingredientIndex: Int) {
        let key = "\(recipeId.uuidString)-\(ingredientIndex)"
        profile.dismissedWarnings.removeAll { $0 == key }
        saveProfile()
    }
    
    /// Clear all dismissed warnings for a recipe
    func clearDismissedWarnings(forRecipeId recipeId: UUID) {
        let prefix = recipeId.uuidString
        profile.dismissedWarnings.removeAll { $0.hasPrefix(prefix) }
        saveProfile()
    }
    
    // MARK: - Persistence
    
    private func saveProfile() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(profile)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            print("❌ Failed to save allergen profile: \(error.localizedDescription)")
        }
    }
    
    private func loadProfile() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else {
            // First launch - create default profile
            profile = DefaultAllergens.createDefaultProfile()
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            profile = try decoder.decode(AllergenProfile.self, from: data)
            print("✅ Loaded allergen profile with \(profile.activeAllergens.count) active allergens")
        } catch {
            print("❌ Failed to load allergen profile: \(error.localizedDescription)")
            // Fall back to defaults
            profile = DefaultAllergens.createDefaultProfile()
        }
    }
}

