import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var allergenManager: AllergenManager
    
    @State private var showingDisclaimer = false
    @State private var showingAllergenProfile = false
    
    var body: some View {
        NavigationView {
            Form {
                // Allergen Profile Section
                Section {
                    Button(action: {
                        showingAllergenProfile = true
                    }) {
                        HStack {
                            Image(systemName: "allergens")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Allergen Profile")
                                    .foregroundColor(.primary)
                                if allergenManager.profile.hasActiveAllergens {
                                    Text("Tracking \(allergenManager.profile.activeAllergens.count) allergen(s)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Not configured")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Safety")
                } footer: {
                    Text("Set up allergen detection to highlight potentially unsafe ingredients in recipes")
                }
                
                Section {
                    Button(action: {
                        showingDisclaimer = true
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Disclaimer")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        if let url = URL(string: "https://jmclarenscripts.vercel.app/privacy/recipe-saviour") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.blue)
                            Text("Privacy Policy")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Legal")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recipe Saviour")
                            .font(.headline)
                        Text("Version 1.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAllergenProfile) {
                AllergenProfileView()
                    .environmentObject(allergenManager)
            }
            .alert("Disclaimer", isPresented: $showingDisclaimer) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("""
                Recipe Saviour is a personal recipe management tool that helps you save and organize recipes from websites you visit.
                
                Content Ownership: All recipes remain the property of their original creators. Recipe Saviour does not claim ownership of any extracted content.
                
                Intended Use: This app is for personal, non-commercial use only. We encourage visiting and supporting the original recipe creators.
                
                No Warranty: Recipe Saviour is provided "as is" without warranties. We are not responsible for the accuracy, safety, or quality of recipes.
                
                By using Recipe Saviour, you agree to use it responsibly and respect the intellectual property rights of recipe creators.
                """)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AllergenManager.shared)
}
