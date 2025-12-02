//
//  AllergenModels.swift
//  Recipe Saviour
//
//  Data models for allergen tracking and substitution suggestions.
//
//  ⚠️ SAFETY NOTE: This feature is an ASSISTANCE tool only.
//  It cannot guarantee detection of all allergens and cannot detect
//  cross-contamination risks. Users must ALWAYS read food labels.
//

import Foundation

// MARK: - Allergen

/// Represents a single allergen category (e.g., "Tree Nuts", "Dairy")
struct Allergen: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var isActive: Bool
    
    /// Built-in keywords for this allergen (cannot be removed, but user can add more)
    var builtInKeywords: [String]
    
    /// User-added keywords for this allergen
    var customKeywords: [String]
    
    /// All keywords combined (built-in + custom)
    var allKeywords: [String] {
        builtInKeywords + customKeywords
    }
    
    init(id: UUID = UUID(), name: String, isActive: Bool = false, builtInKeywords: [String], customKeywords: [String] = []) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.builtInKeywords = builtInKeywords
        self.customKeywords = customKeywords
    }
}

// MARK: - Allergen Match Result

/// Represents a detected allergen in an ingredient
struct AllergenMatch: Identifiable, Equatable {
    var id: String { "\(ingredientIndex)-\(matchedKeyword)" }
    
    let allergen: Allergen
    let matchedKeyword: String      // The specific word that triggered the match
    let ingredientText: String       // The full ingredient line
    let ingredientIndex: Int         // Position in ingredient list (for UI highlighting)
    
    static func == (lhs: AllergenMatch, rhs: AllergenMatch) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Substitution Suggestion

/// A suggested substitution for an allergen-containing ingredient
struct Substitution: Identifiable, Codable, Equatable {
    let id: UUID
    var allergenName: String         // Which allergen this applies to
    var originalKeyword: String      // e.g., "milk", "butter"
    var substitutionText: String     // e.g., "oat milk", "coconut oil"
    var notes: String?               // Optional notes/warnings
    var isUserAdded: Bool            // User-added vs built-in
    
    init(id: UUID = UUID(), allergenName: String, originalKeyword: String, substitutionText: String, notes: String? = nil, isUserAdded: Bool = false) {
        self.id = id
        self.allergenName = allergenName
        self.originalKeyword = originalKeyword
        self.substitutionText = substitutionText
        self.notes = notes
        self.isUserAdded = isUserAdded
    }
}

// MARK: - Allergen Profile

/// The user's complete allergen profile
struct AllergenProfile: Codable {
    var allergens: [Allergen]
    var substitutions: [Substitution]
    var hasCompletedSetup: Bool
    var acknowledgedDisclaimer: Bool
    var lastUpdated: Date
    
    /// IDs of ingredients the user has dismissed for specific recipes
    /// Format: "recipeID-ingredientIndex"
    var dismissedWarnings: [String]
    
    init(
        allergens: [Allergen] = [],
        substitutions: [Substitution] = [],
        hasCompletedSetup: Bool = false,
        acknowledgedDisclaimer: Bool = false,
        lastUpdated: Date = Date(),
        dismissedWarnings: [String] = []
    ) {
        self.allergens = allergens
        self.substitutions = substitutions
        self.hasCompletedSetup = hasCompletedSetup
        self.acknowledgedDisclaimer = acknowledgedDisclaimer
        self.lastUpdated = lastUpdated
        self.dismissedWarnings = dismissedWarnings
    }
    
    /// Returns only active allergens
    var activeAllergens: [Allergen] {
        allergens.filter { $0.isActive }
    }
    
    /// Check if any allergens are active
    var hasActiveAllergens: Bool {
        allergens.contains { $0.isActive }
    }
}

// MARK: - Default Allergens (FDA Big 9 + Common)

/// Pre-populated allergens based on FDA's "Big 9" plus common additions
/// Users can toggle these on/off and add their own keywords
enum DefaultAllergens {
    
    static func createDefaultProfile() -> AllergenProfile {
        AllergenProfile(
            allergens: allDefaults,
            substitutions: defaultSubstitutions,
            hasCompletedSetup: false,
            acknowledgedDisclaimer: false
        )
    }
    
    static let allDefaults: [Allergen] = [
        // FDA Big 9
        milk,
        eggs,
        fish,
        shellfish,
        treeNuts,
        peanuts,
        wheat,
        soybeans,
        sesame,
        // Common additions
        gluten,
        mustard,
        celery,
        sulphites
    ]
    
    static let milk = Allergen(
        name: "Milk / Dairy",
        builtInKeywords: [
            "milk", "cream", "butter", "cheese", "yogurt", "yoghurt",
            "whey", "casein", "lactose", "ghee", "curd", "custard",
            "buttermilk", "sour cream", "ice cream", "cottage cheese",
            "mascarpone", "ricotta", "mozzarella", "parmesan", "cheddar",
            "brie", "camembert", "feta", "halloumi", "paneer", "quark",
            "crème fraîche", "creme fraiche", "double cream", "single cream",
            "clotted cream", "evaporated milk", "condensed milk", "dairy"
        ]
    )
    
    static let eggs = Allergen(
        name: "Eggs",
        builtInKeywords: [
            "egg", "eggs", "yolk", "albumin", "mayonnaise", "mayo",
            "meringue", "aioli", "hollandaise", "béarnaise", "bearnaise",
            "custard", "eggnog", "quiche", "frittata", "omelette", "omelet"
        ]
    )
    
    static let fish = Allergen(
        name: "Fish",
        builtInKeywords: [
            "fish", "salmon", "tuna", "cod", "haddock", "mackerel",
            "sardine", "anchovy", "anchovies", "trout", "bass", "tilapia",
            "halibut", "sole", "plaice", "pollock", "snapper", "swordfish",
            "fish sauce", "worcestershire", "caesar dressing"
        ]
    )
    
    static let shellfish = Allergen(
        name: "Shellfish",
        builtInKeywords: [
            "shrimp", "prawn", "prawns", "lobster", "crab", "crayfish",
            "crawfish", "scallop", "scallops", "mussel", "mussels",
            "oyster", "oysters", "clam", "clams", "squid", "calamari",
            "octopus", "shellfish", "seafood"
        ]
    )
    
    static let treeNuts = Allergen(
        name: "Tree Nuts",
        builtInKeywords: [
            "almond", "almonds", "walnut", "walnuts", "cashew", "cashews",
            "pistachio", "pistachios", "pecan", "pecans", "hazelnut",
            "hazelnuts", "macadamia", "brazil nut", "brazil nuts",
            "pine nut", "pine nuts", "chestnut", "chestnuts",
            "praline", "marzipan", "frangipane", "nougat", "gianduja",
            "nut butter", "nut milk", "almond milk", "cashew milk"
        ]
    )
    
    static let peanuts = Allergen(
        name: "Peanuts",
        builtInKeywords: [
            "peanut", "peanuts", "groundnut", "groundnuts", "arachis",
            "peanut butter", "peanut oil", "satay", "pad thai"
        ]
    )
    
    static let wheat = Allergen(
        name: "Wheat",
        builtInKeywords: [
            "wheat", "flour", "bread", "pasta", "noodle", "noodles",
            "couscous", "bulgur", "semolina", "durum", "spelt", "kamut",
            "farina", "seitan", "breadcrumbs", "croutons", "tortilla",
            "pita", "pitta", "naan", "chapati", "roti", "bagel",
            "croissant", "pastry", "pie crust", "biscuit", "cookie",
            "cake", "muffin", "pancake", "waffle", "cracker"
        ]
    )
    
    static let soybeans = Allergen(
        name: "Soy / Soybeans",
        builtInKeywords: [
            "soy", "soya", "soybean", "soybeans", "tofu", "tempeh",
            "edamame", "miso", "soy sauce", "tamari", "teriyaki",
            "soy milk", "soy protein", "textured vegetable protein",
            "tvp", "lecithin"
        ]
    )
    
    static let sesame = Allergen(
        name: "Sesame",
        builtInKeywords: [
            "sesame", "tahini", "hummus", "halva", "halvah",
            "sesame oil", "sesame seeds", "gomashio", "furikake"
        ]
    )
    
    // Common additions (not FDA Big 9 but commonly tracked)
    
    static let gluten = Allergen(
        name: "Gluten",
        builtInKeywords: [
            "gluten", "wheat", "barley", "rye", "oats", "oat",
            "malt", "brewer's yeast", "triticale", "farro", "spelt",
            "kamut", "semolina", "durum", "bulgur", "couscous",
            "seitan", "flour", "bread", "pasta", "beer", "lager", "ale"
        ]
    )
    
    static let mustard = Allergen(
        name: "Mustard",
        builtInKeywords: [
            "mustard", "dijon", "wholegrain mustard", "english mustard",
            "mustard seed", "mustard powder"
        ]
    )
    
    static let celery = Allergen(
        name: "Celery",
        builtInKeywords: [
            "celery", "celeriac", "celery salt", "celery seed"
        ]
    )
    
    static let sulphites = Allergen(
        name: "Sulphites",
        builtInKeywords: [
            "sulphite", "sulfite", "sulphur dioxide", "sulfur dioxide",
            "wine", "dried fruit", "preserved"
        ]
    )
    
    // MARK: - Default Substitutions
    
    static let defaultSubstitutions: [Substitution] = [
        // Dairy
        Substitution(allergenName: "Milk / Dairy", originalKeyword: "milk", substitutionText: "oat milk, almond milk, or soy milk", notes: "Check for nut/soy allergies"),
        Substitution(allergenName: "Milk / Dairy", originalKeyword: "butter", substitutionText: "dairy-free spread or coconut oil", notes: nil),
        Substitution(allergenName: "Milk / Dairy", originalKeyword: "cream", substitutionText: "coconut cream or oat cream", notes: nil),
        Substitution(allergenName: "Milk / Dairy", originalKeyword: "cheese", substitutionText: "dairy-free cheese or nutritional yeast", notes: "Results may vary"),
        Substitution(allergenName: "Milk / Dairy", originalKeyword: "yogurt", substitutionText: "coconut yogurt or soy yogurt", notes: "Check for soy allergies"),
        
        // Eggs
        Substitution(allergenName: "Eggs", originalKeyword: "egg", substitutionText: "flax egg (1 tbsp ground flax + 3 tbsp water) or commercial egg replacer", notes: "For baking only"),
        Substitution(allergenName: "Eggs", originalKeyword: "mayonnaise", substitutionText: "vegan mayonnaise", notes: nil),
        
        // Wheat/Gluten
        Substitution(allergenName: "Wheat", originalKeyword: "flour", substitutionText: "gluten-free flour blend", notes: "May affect texture"),
        Substitution(allergenName: "Wheat", originalKeyword: "pasta", substitutionText: "rice pasta, corn pasta, or lentil pasta", notes: nil),
        Substitution(allergenName: "Wheat", originalKeyword: "bread", substitutionText: "gluten-free bread", notes: nil),
        Substitution(allergenName: "Wheat", originalKeyword: "breadcrumbs", substitutionText: "gluten-free breadcrumbs or crushed rice crackers", notes: nil),
        Substitution(allergenName: "Gluten", originalKeyword: "soy sauce", substitutionText: "tamari (check label) or coconut aminos", notes: "Tamari may still contain gluten"),
        
        // Soy
        Substitution(allergenName: "Soy / Soybeans", originalKeyword: "soy sauce", substitutionText: "coconut aminos", notes: nil),
        Substitution(allergenName: "Soy / Soybeans", originalKeyword: "tofu", substitutionText: "chickpea tofu or tempeh alternative", notes: "Tempeh contains soy"),
        
        // Tree Nuts
        Substitution(allergenName: "Tree Nuts", originalKeyword: "almond milk", substitutionText: "oat milk or rice milk", notes: nil),
        Substitution(allergenName: "Tree Nuts", originalKeyword: "almond", substitutionText: "sunflower seeds or pumpkin seeds", notes: "For similar texture"),
        
        // Peanuts
        Substitution(allergenName: "Peanuts", originalKeyword: "peanut butter", substitutionText: "sunflower seed butter or tahini", notes: "Check for sesame allergy if using tahini"),
        
        // Sesame
        Substitution(allergenName: "Sesame", originalKeyword: "tahini", substitutionText: "sunflower seed butter", notes: nil),
        Substitution(allergenName: "Sesame", originalKeyword: "sesame oil", substitutionText: "olive oil or grapeseed oil", notes: "Flavor will differ")
    ]
}

