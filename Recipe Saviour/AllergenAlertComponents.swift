//
//  AllergenAlertComponents.swift
//  Recipe Saviour
//
//  Reusable UI components for allergen warnings
//

import SwiftUI

// MARK: - Allergen Warning Banner

/// A prominent banner shown when allergens are detected
struct AllergenWarningBanner: View {
    let matchCount: Int
    let allergenNames: [String]
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("⚠️ \(matchCount) Allergen Warning\(matchCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Contains: \(allergenNames.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }
                
                Spacer()
                
                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.red, Color.orange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Allergen Match Detail View

/// Shows details about a specific allergen match with substitution options
struct AllergenMatchDetailView: View {
    @EnvironmentObject var allergenManager: AllergenManager
    @Environment(\.dismiss) var dismiss
    
    let match: AllergenMatch
    let recipeId: UUID?
    
    @State private var showingDismissConfirmation = false
    
    var substitutions: [Substitution] {
        allergenManager.getSubstitutions(for: match)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Warning header
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(match.allergen.name)
                                .font(.headline)
                            
                            Text("Detected in this recipe")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    
                    // What was detected
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Detected Ingredient")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Text(match.ingredientText)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        HStack {
                            Text("Matched keyword:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\"\(match.matchedKeyword)\"")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Substitution suggestions
                    if !substitutions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Substitution Suggestions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            ForEach(substitutions) { sub in
                                SubstitutionSuggestionCard(substitution: sub)
                            }
                            
                            Text("⚠️ Always verify substitutions are safe for your specific allergy. Consult your allergist if unsure.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                                .background(Color.yellow.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    // Dismiss warning option (with confirmation)
                    if let recipeId = recipeId {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dismiss Warning")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            Button(action: { showingDismissConfirmation = true }) {
                                HStack {
                                    Image(systemName: "eye.slash")
                                    Text("Dismiss for this recipe only")
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            Text("This will hide the warning for this specific ingredient in this recipe. You can restore it in your allergen settings.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Allergen Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Dismiss This Warning?", isPresented: $showingDismissConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Dismiss", role: .destructive) {
                    if let recipeId = recipeId {
                        allergenManager.dismissWarning(forRecipeId: recipeId, ingredientIndex: match.ingredientIndex)
                        dismiss()
                    }
                }
            } message: {
                Text("This will hide the warning for \"\(match.matchedKeyword)\" in this recipe. You can restore it later in allergen settings.\n\nMake sure you have verified this ingredient is safe for you.")
            }
        }
    }
}

// MARK: - Substitution Suggestion Card

struct SubstitutionSuggestionCard: View {
    let substitution: Substitution
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(substitution.originalKeyword)
                    .strikethrough()
                    .foregroundColor(.red)
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(substitution.substitutionText)
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            }
            
            if let notes = substitution.notes {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Highlighted Ingredient Row

/// An ingredient row that highlights allergen matches
struct HighlightedIngredientRow: View {
    let ingredient: String
    let index: Int
    let matches: [AllergenMatch]
    let recipeId: UUID?
    
    @State private var showingDetail = false
    
    private var matchForThisIngredient: AllergenMatch? {
        matches.first { $0.ingredientIndex == index }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if let match = matchForThisIngredient {
                // Has allergen - show warning
                Button(action: { showingDetail = true }) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(highlightedText(ingredient, keyword: match.matchedKeyword))
                            
                            Text("Contains: \(match.allergen.name)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingDetail) {
                    AllergenMatchDetailView(match: match, recipeId: recipeId)
                }
            } else {
                // No allergen - normal display
                Text("• \(ingredient)")
            }
        }
    }
    
    /// Creates attributed text with the keyword highlighted
    private func highlightedText(_ text: String, keyword: String) -> AttributedString {
        var attributedString = AttributedString("• " + text)
        
        // Find the keyword (case insensitive) and highlight it
        if let range = attributedString.range(of: keyword, options: .caseInsensitive) {
            attributedString[range].backgroundColor = .orange.opacity(0.3)
            attributedString[range].foregroundColor = .red
        }
        
        return attributedString
    }
}

// MARK: - Allergen Matches Summary Sheet

/// Shows all allergen matches for a recipe
struct AllergenMatchesSummarySheet: View {
    @Environment(\.dismiss) var dismiss
    
    let matches: [AllergenMatch]
    let recipeId: UUID?
    
    var body: some View {
        NavigationView {
            List {
                // Safety reminder
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(AllergenManager.shortDisclaimer)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Matches
                Section {
                    ForEach(matches) { match in
                        NavigationLink {
                            AllergenMatchDetailView(match: match, recipeId: recipeId)
                                .navigationBarBackButtonHidden(false)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(match.allergen.name)
                                        .fontWeight(.medium)
                                    
                                    Text(match.ingredientText)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                } header: {
                    Text("\(matches.count) Allergen\(matches.count == 1 ? "" : "s") Detected")
                }
            }
            .navigationTitle("Allergen Warnings")
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

// MARK: - Shopping List Allergen Badge

/// Small badge shown next to shopping list items with allergens
struct AllergenBadge: View {
    let allergenNames: [String]
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
            
            if allergenNames.count == 1 {
                Text(allergenNames[0])
                    .font(.caption2)
            } else {
                Text("\(allergenNames.count) allergens")
                    .font(.caption2)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.orange)
        .cornerRadius(4)
    }
}

