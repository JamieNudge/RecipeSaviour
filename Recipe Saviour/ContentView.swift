import SwiftUI

struct ContentView: View {
    @StateObject private var recipeManager = RecipeManager.shared
    @State private var showingDisclaimer = false
    
    var body: some View {
        TabView {
            ExtractRecipeView()
                .tabItem {
                    Label("Extract", systemImage: "link")
                }
                .environmentObject(recipeManager)
            
            SavedRecipesView()
                .tabItem {
                    Label("My Recipes", systemImage: "book.fill")
                }
                .badge(recipeManager.savedRecipes.count)
                .environmentObject(recipeManager)
            
            MealPlannerView()
                .tabItem {
                    Label("Meal Planner", systemImage: "cart.fill")
                }
                .environmentObject(recipeManager)
        }
    }
}

struct ExtractRecipeView: View {
    @EnvironmentObject var recipeManager: RecipeManager
    @State private var urlString: String = ""
    @State private var isLoading = false
    @State private var recipe: Recipe?
    @State private var errorMessage: String?
    @State private var showingDisclaimer = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Paste a recipe web link and Recipe Saviour will strip the waffle and show just the ingredients and method.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        TextField("Paste Recipe URL here!", text: $urlString)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                            .onSubmit {
                                hideKeyboard()
                            }
                        
                        if !urlString.isEmpty {
                            Button(action: {
                                urlString = ""
                                recipe = nil
                                errorMessage = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button(action: { 
                        hideKeyboard()
                        Task { await fetchRecipe() } 
                    }) {
                        if isLoading {
                            HStack(spacing: 8) {
                                Text("🥘")
                                    .font(.title2)
                                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isLoading)
                                Text("Cooking up your recipe...")
                                    .fontWeight(.semibold)
                            }
                        } else {
                            Text("Save Recipe From The Endless Waffle")
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }

                    if let recipe {
                        RecipeView(recipe: recipe, showSaveButton: true)
                    } else if !isLoading && errorMessage == nil {
                        Text("No recipe yet. Paste a link and tap “Clean recipe”.")
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Recipe Saviour")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingDisclaimer = true
                    }) {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingDisclaimer) {
                DisclaimerView(isPresented: $showingDisclaimer)
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func fetchRecipe() async {
        var trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Auto-add https:// if missing
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "https://" + trimmed
        }

        guard let url = URL(string: trimmed) else {
            await MainActor.run {
                self.errorMessage = "That doesn't look like a valid URL."
                self.recipe = nil
            }
            return
        }

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let html = String(data: data, encoding: .utf8) else {
                throw URLError(.cannotDecodeRawData)
            }

            if let parsed = RecipeExtractor.extract(from: html, url: url) {
                await MainActor.run {
                    self.recipe = parsed
                    self.errorMessage = nil
                }
            } else {
                await MainActor.run {
                    self.recipe = nil
                    self.errorMessage = "You'll have to scan through the life story around this one. Sorry. Next!"
                }
            }
        } catch {
            await MainActor.run {
                self.recipe = nil
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .unsupportedURL:
                        self.errorMessage = "This URL format isn't supported. Try copying the full URL from your browser."
                    case .cannotFindHost:
                        self.errorMessage = "Can't reach this website. Check the URL and your internet connection."
                    case .timedOut:
                        self.errorMessage = "The website took too long to respond. Try again."
                    default:
                        self.errorMessage = "Network error: \(error.localizedDescription)"
                    }
                } else {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                }
            }
        }

        await MainActor.run {
            self.isLoading = false
        }
    }
}

struct RecipeView: View {
    @EnvironmentObject var recipeManager: RecipeManager
    let recipe: Recipe
    let showSaveButton: Bool
    
    @State private var showingSavedAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(recipe.title)
                    .font(.title2.bold())
                Spacer()
                if showSaveButton {
                    Button(action: {
                        recipeManager.saveRecipe(recipe)
                        showingSavedAlert = true
                    }) {
                        Image(systemName: recipeManager.isRecipeSaved(recipe) ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(recipeManager.isRecipeSaved(recipe) ? .green : .blue)
                    }
                    .disabled(recipeManager.isRecipeSaved(recipe))
                    .help(recipeManager.isRecipeSaved(recipe) ? "Already saved" : "Save recipe")
                }
            }

            if !recipe.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ingredients")
                        .font(.headline)
                    ForEach(recipe.ingredients, id: \.self) { line in
                        Text("• \(line)")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !recipe.steps.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Method")
                        .font(.headline)
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.headline)
                            Text(step)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Link("View original", destination: recipe.sourceURL)
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .alert("Recipe Saved!", isPresented: $showingSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(recipe.title) has been added to your collection.")
        }
    }
}

struct SavedRecipesView: View {
    @EnvironmentObject var recipeManager: RecipeManager
    @State private var selectedRecipe: Recipe?
    
    var body: some View {
        NavigationView {
            Group {
                if recipeManager.savedRecipes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No saved recipes yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Extract a recipe and tap the + button to save it")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(recipeManager.savedRecipes.sorted(by: { $0.dateSaved > $1.dateSaved })) { recipe in
                            Button(action: {
                                selectedRecipe = recipe
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recipe.title)
                                        .font(.headline)
                                    Text("\(recipe.ingredients.count) ingredients • \(recipe.steps.count) steps")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Saved \(recipe.dateSaved.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    recipeManager.deleteRecipe(recipe)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("My Recipes")
            .sheet(item: $selectedRecipe) { recipe in
                NavigationView {
                    ScrollView {
                        RecipeView(recipe: recipe, showSaveButton: false)
                            .padding()
                    }
                    .navigationTitle("Recipe")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                selectedRecipe = nil
                            }
                        }
                    }
                }
            }
        }
    }
}
