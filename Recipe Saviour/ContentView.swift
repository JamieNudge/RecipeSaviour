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
            
            FavouritePlansView()
                .tabItem {
                    Label("Plans", systemImage: "list.bullet.rectangle")
                }
                .badge(recipeManager.favouritePlans.count)
                .environmentObject(recipeManager)
            
            MealPlannerView()
                .tabItem {
                    Label("Meal Planner", systemImage: "cart.fill")
                }
                .badge("Plan my week")
                .environmentObject(recipeManager)
        }
        .background(RSTheme.Colors.background.ignoresSafeArea())
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
            ZStack {
                RSTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: RSTheme.Spacing.lg) {
                        VStack(alignment: .leading, spacing: RSTheme.Spacing.sm) {
                            Text("Save recipes from the endless waffle")
                                .rsSectionTitle()
                            Text("Paste a recipe link and we'll keep only the ingredients and method so you can actually cook.")
                                .rsSecondary()
                        }

                        VStack(spacing: RSTheme.Spacing.sm) {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                    .foregroundColor(RSTheme.Colors.primary)
                                    .font(.title2)
                                
                                TextField("Paste recipe URL here", text: $urlString)
                                    .keyboardType(.URL)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        hideKeyboard()
                                        Task { await fetchRecipe() }
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
                            .padding(.horizontal, RSTheme.Spacing.md)
                            .padding(.vertical, RSTheme.Spacing.sm)
                            .background(RSTheme.Colors.card)
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundColor(RSTheme.Colors.error)
                                .rsCaption()
                        }

                        if let recipe {
                            RecipeView(recipe: recipe, showSaveButton: true)
                                .padding()
                                .background(RSTheme.Colors.card)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                        } else if !isLoading && errorMessage == nil {
                            VStack(alignment: .leading, spacing: RSTheme.Spacing.sm) {
                                Text("No recipe yet")
                                    .font(.headline)
                                Text("Paste a link and hit return to see it without the life story.")
                                    .rsSecondary()
                            }
                        }

                        Spacer(minLength: RSTheme.Spacing.xl)
                    }
                    .padding()
                }
                
                if isLoading {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                    VStack(spacing: RSTheme.Spacing.sm) {
                        ProgressView()
                            .tint(RSTheme.Colors.primary)
                        Text("Cooking up your recipe...")
                            .rsCaption()
                    }
                }
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
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.recipe = parsed
                    }
                    self.errorMessage = nil
                }
            } else {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.recipe = nil
                    }
                    self.errorMessage = "You'll have to scan through the life story around this one. Sorry. Next!"
                }
            }
        } catch {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.recipe = nil
                }
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
        VStack(alignment: .leading, spacing: RSTheme.Spacing.lg) {
            HStack {
                Text(recipe.title)
                    .font(RSTheme.Typography.sectionTitle)
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
                VStack(alignment: .leading, spacing: RSTheme.Spacing.sm) {
                    Text("Ingredients")
                        .rsSectionTitle()
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(recipe.ingredients, id: \.self) { line in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .font(.body.bold())
                                Text(line)
                                    .rsBody()
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            
            if !recipe.ingredients.isEmpty && !recipe.steps.isEmpty {
                Divider()
            }
            
            if !recipe.steps.isEmpty {
                VStack(alignment: .leading, spacing: RSTheme.Spacing.sm) {
                    Text("Method")
                        .rsSectionTitle()
                    VStack(alignment: .leading, spacing: RSTheme.Spacing.sm) {
                        ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.headline)
                                    .foregroundColor(RSTheme.Colors.accent)
                                    .frame(width: 22, alignment: .leading)
                                Text(step)
                                    .rsBody()
                                    .fixedSize(horizontal: false, vertical: true)
                            }
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
            ZStack {
                RSTheme.Colors.background
                    .ignoresSafeArea()
                
                Group {
                    if recipeManager.savedRecipes.isEmpty {
                        VStack(spacing: RSTheme.Spacing.lg) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 60))
                                .foregroundColor(RSTheme.Colors.primary.opacity(0.7))
                            Text("No saved recipes yet")
                                .font(RSTheme.Typography.sectionTitle)
                                .foregroundColor(RSTheme.Colors.textPrimary)
                            Text("Extract a recipe and tap the + button to save it")
                                .rsSecondary()
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        List {
                            ForEach(recipeManager.savedRecipes.sorted(by: { $0.dateSaved > $1.dateSaved })) { recipe in
                                Button(action: {
                                    selectedRecipe = recipe
                                }) {
                                    HStack(alignment: .top, spacing: RSTheme.Spacing.md) {
                                        Image(systemName: "fork.knife.circle.fill")
                                            .foregroundColor(RSTheme.Colors.accent)
                                            .font(.title2)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(recipe.title)
                                                .font(.headline)
                                            Text("\(recipe.ingredients.count) ingredients • \(recipe.steps.count) steps")
                                                .rsCaption()
                                            Text("Saved \(recipe.dateSaved.formatted(date: .abbreviated, time: .omitted))")
                                                .rsCaption()
                                        }
                                    }
                                    .padding(.vertical, RSTheme.Spacing.sm)
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
                        .scrollContentBackground(.hidden)
                        .background(RSTheme.Colors.background)
                        .listStyle(.insetGrouped)
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
