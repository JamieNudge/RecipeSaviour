import SwiftUI

struct FavouritePlansView: View {
    @EnvironmentObject var recipeManager: RecipeManager
    @State private var selectedPlan: MealPlan?
    
    var body: some View {
        NavigationView {
            ZStack {
                RSTheme.Colors.background
                    .ignoresSafeArea()
                
                Group {
                    if recipeManager.favouritePlans.isEmpty {
                        VStack(spacing: RSTheme.Spacing.lg) {
                            Image(systemName: "list.bullet.rectangle.portrait")
                                .font(.system(size: 60))
                                .foregroundColor(RSTheme.Colors.primary.opacity(0.7))
                            Text("No favourite plans yet")
                                .font(RSTheme.Typography.sectionTitle)
                                .foregroundColor(RSTheme.Colors.textPrimary)
                            Text("Create a meal plan, then save it from the shopping list screen.")
                                .rsSecondary()
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        List {
                            ForEach(recipeManager.favouritePlans.sorted(by: { $0.createdAt > $1.createdAt })) { plan in
                                Button {
                                    selectedPlan = plan
                                } label: {
                                    HStack(spacing: RSTheme.Spacing.md) {
                                        Image(systemName: "calendar")
                                            .foregroundColor(RSTheme.Colors.accent)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Plan from \(plan.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.headline)
                                            Text("\(plan.recipes.count) meals")
                                                .rsCaption()
                                        }
                                    }
                                    .padding(.vertical, RSTheme.Spacing.sm)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        recipeManager.deleteMealPlan(plan)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .background(RSTheme.Colors.background)
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("Favourite Plans")
            .sheet(item: $selectedPlan) { plan in
                NavigationView {
                    ShoppingListView(recipes: plan.recipes, allowSaving: false)
                        .environmentObject(recipeManager)
                }
            }
        }
    }
}


