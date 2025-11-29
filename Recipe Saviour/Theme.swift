import SwiftUI

/// Central design system for Recipe Saviour
struct RSTheme {
    
    struct Colors {
        /// Main accent color for primary actions
        static let primary = Color(red: 0.97, green: 0.45, blue: 0.20) // warm recipe orange
        
        /// Secondary accent for highlights
        static let accent = Color(red: 0.16, green: 0.58, blue: 0.45) // fresh green
        
        /// Background for main screens
        static let background = Color(red: 0.98, green: 0.97, blue: 0.94) // soft warm off-white
        
        /// Subtle background for cards / panels
        static let card = Color(.secondarySystemBackground)
        
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        
        static let error = Color.red
    }
    
    struct Typography {
        static let appTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let sectionTitle = Font.system(.title3, design: .rounded).weight(.semibold)
        static let body = Font.system(.body, design: .default)
        static let secondary = Font.system(.subheadline, design: .default)
        static let caption = Font.system(.caption, design: .default)
    }
    
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
}

// Convenience modifiers for common text styles
extension Text {
    func rsAppTitle() -> some View {
        self.font(RSTheme.Typography.appTitle)
            .foregroundColor(RSTheme.Colors.textPrimary)
    }
    
    func rsSectionTitle() -> some View {
        self.font(RSTheme.Typography.sectionTitle)
            .foregroundColor(RSTheme.Colors.textPrimary)
    }
    
    func rsBody() -> some View {
        self.font(RSTheme.Typography.body)
            .foregroundColor(RSTheme.Colors.textPrimary)
    }
    
    func rsSecondary() -> some View {
        self.font(RSTheme.Typography.secondary)
            .foregroundColor(RSTheme.Colors.textSecondary)
    }
    
    func rsCaption() -> some View {
        self.font(RSTheme.Typography.caption)
            .foregroundColor(RSTheme.Colors.textSecondary)
    }
}


