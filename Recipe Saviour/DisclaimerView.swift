import SwiftUI

struct DisclaimerView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Welcome to Recipe Saviour!")
                        .font(.title.bold())
                    
                    Text("Recipe Saviour helps you extract and organize recipes from websites for your personal use.")
                        .font(.body)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Important Information:")
                            .font(.headline)
                        
                        Text("• Recipe Saviour extracts publicly available recipe data (ingredients and cooking instructions) from websites you provide.")
                        
                        Text("• All recipes remain the property of their original publishers. We provide links back to the source.")
                        
                        Text("• This app is intended for personal, non-commercial use to help with meal planning and organization.")
                        
                        Text("• Recipe data (ingredients and basic instructions) are factual information and not subject to copyright. However, original creative content belongs to the recipe authors.")
                    }
                    .font(.subheadline)
                    
                    Text("By using this app, you agree to respect the intellectual property rights of recipe creators and use extracted recipes for personal purposes only.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .padding()
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

