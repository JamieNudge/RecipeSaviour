//
//  AllergenProfileView.swift
//  Recipe Saviour
//
//  UI for setting up and managing allergen profile
//

import SwiftUI

// MARK: - Main Allergen Profile View

struct AllergenProfileView: View {
    @EnvironmentObject var allergenManager: AllergenManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showingDisclaimer = false
    @State private var showingAddAllergen = false
    @State private var showingAddSubstitution = false
    @State private var selectedAllergen: Allergen?
    
    var body: some View {
        NavigationView {
            Group {
                if !allergenManager.profile.acknowledgedDisclaimer {
                    // First-time setup: show disclaimer first
                    DisclaimerAcceptView()
                } else {
                    // Normal view: show allergen management
                    allergenListView
                }
            }
            .navigationTitle("Allergen Profile")
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
    
    // MARK: - Allergen List View
    
    private var allergenListView: some View {
        List {
            // Safety reminder banner
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    Text(AllergenManager.shortDisclaimer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            // Active allergens summary
            if allergenManager.profile.hasActiveAllergens {
                Section {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                        Text("Tracking \(allergenManager.profile.activeAllergens.count) allergen(s)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                } header: {
                    Text("Status")
                }
            }
            
            // Common allergens (FDA Big 9)
            Section {
                ForEach(allergenManager.profile.allergens.filter { !$0.builtInKeywords.isEmpty }.prefix(9)) { allergen in
                    AllergenRow(allergen: allergen)
                }
            } header: {
                Text("Common Allergens")
            } footer: {
                Text("FDA's \"Big 9\" allergens - the most common food allergies")
            }
            
            // Other allergens
            Section {
                ForEach(allergenManager.profile.allergens.filter { !$0.builtInKeywords.isEmpty }.dropFirst(9)) { allergen in
                    AllergenRow(allergen: allergen)
                }
            } header: {
                Text("Other Allergens")
            }
            
            // Custom allergens
            let customAllergens = allergenManager.profile.allergens.filter { $0.builtInKeywords.isEmpty }
            if !customAllergens.isEmpty {
                Section {
                    ForEach(customAllergens) { allergen in
                        AllergenRow(allergen: allergen, isCustom: true)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            allergenManager.deleteAllergen(customAllergens[index])
                        }
                    }
                } header: {
                    Text("Your Custom Allergens")
                }
            }
            
            // Add custom allergen button
            Section {
                Button(action: { showingAddAllergen = true }) {
                    Label("Add Custom Allergen", systemImage: "plus.circle.fill")
                }
            }
            
            // Substitutions section
            Section {
                NavigationLink(destination: SubstitutionsListView()) {
                    HStack {
                        Image(systemName: "arrow.triangle.swap")
                            .foregroundColor(.blue)
                        Text("Manage Substitutions")
                    }
                }
            } header: {
                Text("Substitution Suggestions")
            } footer: {
                Text("Add or edit ingredient substitution suggestions")
            }
            
            // Reset section
            Section {
                Button(role: .destructive) {
                    allergenManager.resetToDefaults()
                } label: {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                }
                
                Button(action: { showingDisclaimer = true }) {
                    Label("View Full Disclaimer", systemImage: "doc.text")
                }
            } header: {
                Text("Settings")
            }
        }
        .sheet(isPresented: $showingAddAllergen) {
            AddCustomAllergenView()
        }
        .sheet(item: $selectedAllergen) { allergen in
            AllergenDetailView(allergen: allergen)
        }
        .alert("Allergen Detection Disclaimer", isPresented: $showingDisclaimer) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(AllergenManager.disclaimerText)
        }
    }
}

// MARK: - Allergen Row

struct AllergenRow: View {
    @EnvironmentObject var allergenManager: AllergenManager
    let allergen: Allergen
    var isCustom: Bool = false
    
    @State private var showingDetail = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(allergen.name)
                        .fontWeight(allergen.isActive ? .medium : .regular)
                    
                    if isCustom {
                        Text("(Custom)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("\(allergen.allKeywords.count) detection keywords")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { showingDetail = true }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            
            Toggle("", isOn: Binding(
                get: { allergen.isActive },
                set: { _ in allergenManager.toggleAllergen(allergen) }
            ))
            .labelsHidden()
        }
        .sheet(isPresented: $showingDetail) {
            AllergenDetailView(allergen: allergen)
        }
    }
}

// MARK: - Allergen Detail View (shows keywords, allows adding custom)

struct AllergenDetailView: View {
    @EnvironmentObject var allergenManager: AllergenManager
    @Environment(\.dismiss) var dismiss
    
    let allergen: Allergen
    @State private var newKeyword: String = ""
    
    private var currentAllergen: Allergen {
        allergenManager.profile.allergens.first { $0.id == allergen.id } ?? allergen
    }
    
    var body: some View {
        NavigationView {
            List {
                // Status
                Section {
                    Toggle("Active", isOn: Binding(
                        get: { currentAllergen.isActive },
                        set: { _ in allergenManager.toggleAllergen(currentAllergen) }
                    ))
                }
                
                // Built-in keywords
                if !currentAllergen.builtInKeywords.isEmpty {
                    Section {
                        ForEach(currentAllergen.builtInKeywords, id: \.self) { keyword in
                            HStack {
                                Text(keyword)
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Built-in Keywords")
                    } footer: {
                        Text("These keywords cannot be removed but you can add more below")
                    }
                }
                
                // Custom keywords
                Section {
                    ForEach(currentAllergen.customKeywords, id: \.self) { keyword in
                        Text(keyword)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            allergenManager.removeCustomKeyword(currentAllergen.customKeywords[index], from: currentAllergen)
                        }
                    }
                    
                    HStack {
                        TextField("Add keyword", text: $newKeyword)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        
                        Button(action: addKeyword) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                        .disabled(newKeyword.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Your Custom Keywords")
                } footer: {
                    Text("Add words that should trigger a warning for this allergen")
                }
                
                // Substitutions for this allergen
                let subs = allergenManager.getSubstitutions(for: currentAllergen)
                if !subs.isEmpty {
                    Section {
                        ForEach(subs) { sub in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(sub.originalKeyword)
                                        .strikethrough()
                                        .foregroundColor(.red)
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                    Text(sub.substitutionText)
                                        .foregroundColor(.green)
                                }
                                .font(.subheadline)
                                
                                if let notes = sub.notes {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Substitution Suggestions")
                    }
                }
            }
            .navigationTitle(allergen.name)
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
    
    private func addKeyword() {
        allergenManager.addCustomKeyword(newKeyword, to: currentAllergen)
        newKeyword = ""
    }
}

// MARK: - Add Custom Allergen View

struct AddCustomAllergenView: View {
    @EnvironmentObject var allergenManager: AllergenManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    @State private var keywordsText: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Allergen name", text: $name)
                } header: {
                    Text("Name")
                } footer: {
                    Text("e.g., \"Lupin\", \"Alpha-gal (Red Meat)\"")
                }
                
                Section {
                    TextField("Keywords (comma separated)", text: $keywordsText, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Detection Keywords")
                } footer: {
                    Text("Enter words that should trigger a warning, separated by commas.\ne.g., \"lupin, lupine, lupini beans\"")
                }
            }
            .navigationTitle("Add Allergen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let keywords = keywordsText.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                        allergenManager.addCustomAllergen(name: name, keywords: keywords)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Substitutions List View

struct SubstitutionsListView: View {
    @EnvironmentObject var allergenManager: AllergenManager
    @State private var showingAddSubstitution = false
    
    var body: some View {
        List {
            Section {
                Text("Substitution suggestions help you find alternatives to allergen-containing ingredients. Always verify substitutions are safe for your specific needs.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Group by allergen
            let grouped = Dictionary(grouping: allergenManager.profile.substitutions) { $0.allergenName }
            
            ForEach(grouped.keys.sorted(), id: \.self) { allergenName in
                Section {
                    ForEach(grouped[allergenName] ?? []) { sub in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(sub.originalKeyword)
                                    .strikethrough()
                                    .foregroundColor(.red)
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                Text(sub.substitutionText)
                                    .foregroundColor(.green)
                            }
                            .font(.subheadline)
                            
                            if let notes = sub.notes {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if sub.isUserAdded {
                                Text("Custom")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            if let sub = grouped[allergenName]?[index] {
                                allergenManager.deleteSubstitution(sub)
                            }
                        }
                    }
                } header: {
                    Text(allergenName)
                }
            }
            
            Section {
                Button(action: { showingAddSubstitution = true }) {
                    Label("Add Custom Substitution", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("Substitutions")
        .sheet(isPresented: $showingAddSubstitution) {
            AddSubstitutionView()
        }
    }
}

// MARK: - Add Substitution View

struct AddSubstitutionView: View {
    @EnvironmentObject var allergenManager: AllergenManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedAllergenName: String = ""
    @State private var originalKeyword: String = ""
    @State private var substitutionText: String = ""
    @State private var notes: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("For Allergen", selection: $selectedAllergenName) {
                        Text("Select...").tag("")
                        ForEach(allergenManager.profile.allergens) { allergen in
                            Text(allergen.name).tag(allergen.name)
                        }
                    }
                }
                
                Section {
                    TextField("Original ingredient", text: $originalKeyword)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Replace This")
                } footer: {
                    Text("e.g., \"butter\", \"milk\"")
                }
                
                Section {
                    TextField("Substitution", text: $substitutionText)
                } header: {
                    Text("With This")
                } footer: {
                    Text("e.g., \"dairy-free spread\", \"oat milk\"")
                }
                
                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Optional warnings or tips about this substitution")
                }
            }
            .navigationTitle("Add Substitution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        allergenManager.addSubstitution(
                            allergenName: selectedAllergenName,
                            originalKeyword: originalKeyword,
                            substitutionText: substitutionText,
                            notes: notes.isEmpty ? nil : notes
                        )
                        dismiss()
                    }
                    .disabled(selectedAllergenName.isEmpty || originalKeyword.isEmpty || substitutionText.isEmpty)
                }
            }
        }
    }
}

// MARK: - Disclaimer Accept View (First-time setup)

struct DisclaimerAcceptView: View {
    @EnvironmentObject var allergenManager: AllergenManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Before You Begin")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Please read this important information carefully")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Disclaimer content
                VStack(alignment: .leading, spacing: 16) {
                    Text(AllergenManager.disclaimerText)
                        .font(.callout)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Accept button
                Button(action: {
                    allergenManager.acknowledgeDisclaimer()
                    allergenManager.completeSetup()
                }) {
                    Text("I Understand - Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RSTheme.Colors.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

