import SwiftUI

struct DisclaimerView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: RSTheme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: RSTheme.Spacing.sm) {
                        Text("Welcome to Recipe Saviour!")
                            .rsSectionTitle()
                        
                        Text("Recipe Saviour helps you extract and organize recipes from websites for your personal use.")
                            .rsBody()
                    }
                    
                    VStack(alignment: .leading, spacing: RSTheme.Spacing.sm) {
                        Text("Important Information")
                            .rsSectionTitle()
                        
                        VStack(alignment: .leading, spacing: RSTheme.Spacing.sm) {
                            Text("• Recipe Saviour extracts publicly available recipe data (ingredients and cooking instructions) from websites you provide.")
                                .rsSecondary()
                            Text("• All recipes remain the property of their original publishers. We provide links back to the source.")
                                .rsSecondary()
                            Text("• This app is intended for personal, non-commercial use to help with meal planning and organization.")
                                .rsSecondary()
                            Text("• Recipe data (ingredients and basic instructions) are factual information and not subject to copyright. However, original creative content belongs to the recipe authors.")
                                .rsSecondary()
                        }
                    }
                    .padding()
                    .background(RSTheme.Colors.card)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                    
                    Text("By using this app, you agree to respect the intellectual property rights of recipe creators and use extracted recipes for personal purposes only.")
                        .rsCaption()
                        .padding(.top, RSTheme.Spacing.sm)
                }
                .padding()
                .background(RSTheme.Colors.background.ignoresSafeArea())
            }
            .navigationTitle("Legal Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

