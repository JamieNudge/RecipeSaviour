//
//  ShareHelper.swift
//  Recipe Saviour
//
//  Sharing utilities for recipes, shopping lists, and meal plans
//

import SwiftUI
import UIKit

// MARK: - Share Helper

struct ShareHelper {
    
    // MARK: - Format Recipe for Sharing
    
    static func formatRecipe(_ recipe: Recipe) -> String {
        var text = "🍽️ \(recipe.title)\n"
        text += String(repeating: "─", count: 30) + "\n\n"
        
        if !recipe.ingredients.isEmpty {
            text += "📝 INGREDIENTS:\n"
            for ingredient in recipe.ingredients {
                text += "• \(ingredient)\n"
            }
            text += "\n"
        }
        
        if !recipe.steps.isEmpty {
            text += "👨‍🍳 METHOD:\n"
            for (index, step) in recipe.steps.enumerated() {
                text += "\(index + 1). \(step)\n\n"
            }
        }
        
        text += "─────────────────────────────\n"
        text += "📱 Shared from Recipe Saviour"
        
        return text
    }
    
    // MARK: - Format Shopping List for Sharing
    
    static func formatShoppingList(items: [ShoppingListItem], recipes: [Recipe]) -> String {
        var text = "🛒 SHOPPING LIST\n"
        text += String(repeating: "─", count: 30) + "\n\n"
        
        // Add recipe names
        if !recipes.isEmpty {
            text += "📋 For: \(recipes.map { $0.title }.joined(separator: ", "))\n\n"
        }
        
        // Common ingredients (used in multiple recipes)
        let commonItems = items.filter { $0.isCommon }
        if !commonItems.isEmpty {
            text += "🔄 COMMON INGREDIENTS:\n"
            for item in commonItems {
                text += "☐ \(item.displayText)"
                if item.recipeCount > 1 {
                    text += " (\(item.recipeCount) recipes)"
                }
                text += "\n"
            }
            text += "\n"
        }
        
        // Unique ingredients
        let uniqueItems = items.filter { !$0.isCommon }
        if !uniqueItems.isEmpty {
            let header = commonItems.isEmpty ? "INGREDIENTS:" : "OTHER INGREDIENTS:"
            text += "📝 \(header)\n"
            for item in uniqueItems {
                text += "☐ \(item.displayText)\n"
            }
            text += "\n"
        }
        
        text += "─────────────────────────────\n"
        text += "📱 Shared from Recipe Saviour"
        
        return text
    }
    
    // MARK: - Format Meal Plan for Sharing
    
    static func formatMealPlan(recipes: [Recipe], shoppingItems: [ShoppingListItem]) -> String {
        var text = "🗓️ MEAL PLAN\n"
        text += String(repeating: "─", count: 30) + "\n\n"
        
        // List the meals
        text += "🍽️ MEALS (\(recipes.count)):\n"
        for (index, recipe) in recipes.enumerated() {
            text += "\(index + 1). \(recipe.title)\n"
        }
        text += "\n"
        
        // Shopping list summary
        text += "🛒 SHOPPING LIST (\(shoppingItems.count) items):\n"
        
        let commonItems = shoppingItems.filter { $0.isCommon }
        let uniqueItems = shoppingItems.filter { !$0.isCommon }
        
        if !commonItems.isEmpty {
            text += "\n🔄 Shared ingredients:\n"
            for item in commonItems {
                text += "☐ \(item.displayText)\n"
            }
        }
        
        if !uniqueItems.isEmpty {
            text += "\n📝 Other ingredients:\n"
            for item in uniqueItems {
                text += "☐ \(item.displayText)\n"
            }
        }
        
        text += "\n─────────────────────────────\n"
        text += "📱 Shared from Recipe Saviour"
        
        return text
    }
    
    // MARK: - Format Simple Ingredients List
    
    static func formatSimpleIngredients(_ ingredients: [String], title: String) -> String {
        var text = "🛒 \(title)\n"
        text += String(repeating: "─", count: 30) + "\n\n"
        
        for ingredient in ingredients {
            text += "☐ \(ingredient)\n"
        }
        
        text += "\n─────────────────────────────\n"
        text += "📱 Shared from Recipe Saviour"
        
        return text
    }
}

// MARK: - Share Sheet View (SwiftUI wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Share Button Style

struct ShareButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Convenience View Modifier for Sharing

extension View {
    func shareSheet(isPresented: Binding<Bool>, items: [Any]) -> some View {
        self.sheet(isPresented: isPresented) {
            ShareSheet(items: items)
        }
    }
}

// MARK: - Copied Toast View

struct CopiedToastView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Copied to clipboard")
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(25)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .padding(.bottom, 20)
    }
}

