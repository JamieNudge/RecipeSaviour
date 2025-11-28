import Foundation

enum RecipeExtractor {
    static func extract(from html: String, url: URL) -> Recipe? {
        // 1) Look for <script type="application/ld+json"> blocks
        let pattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }

        let nsRange = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: nsRange)

        for match in matches {
            guard match.numberOfRanges >= 2,
                  let range = Range(match.range(at: 1), in: html) else { continue }

            let jsonFragment = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)

            if let recipe = parseJSONLDSnippet(jsonFragment, sourceURL: url) {
                return recipe
            }
        }

        // 2) Fallback: try to heuristically parse plain HTML structure
        if let fallbackRecipe = extractFromHTMLStructure(html, sourceURL: url) {
            return fallbackRecipe
        }

        return nil
    }

    private static func parseJSONLDSnippet(_ json: String, sourceURL: URL) -> Recipe? {
        guard let data = json.data(using: .utf8) else { return nil }

        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [])
            return extractFromJSONObject(object, sourceURL: sourceURL)
        } catch {
            return nil
        }
    }

    private static func extractFromJSONObject(_ object: Any, sourceURL: URL) -> Recipe? {
        if let dict = object as? [String: Any] {
            // Direct recipe object
            if let type = dict["@type"] as? String,
               type.lowercased().contains("recipe"),
               let recipe = makeRecipe(from: dict, sourceURL: sourceURL) {
                return recipe
            }

            // Sometimes recipe is nested in @graph
            if let graph = dict["@graph"] as? [Any] {
                for item in graph {
                    if let recipe = extractFromJSONObject(item, sourceURL: sourceURL) {
                        return recipe
                    }
                }
            }
        } else if let array = object as? [Any] {
            // Array of things, find the recipe in there
            for item in array {
                if let recipe = extractFromJSONObject(item, sourceURL: sourceURL) {
                    return recipe
                }
            }
        }

        return nil
    }

    private static func makeRecipe(from dict: [String: Any], sourceURL: URL) -> Recipe? {
        let title = (dict["name"] as? String) ?? "Recipe"

        var ingredients: [String] = []
        if let ing = dict["recipeIngredient"] as? [String] {
            ingredients = ing
        }

        var steps: [String] = []

        if let instructionsString = dict["recipeInstructions"] as? String {
            // Single big string: split into lines
            steps = instructionsString
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        } else if let instructionsArray = dict["recipeInstructions"] as? [Any] {
            for item in instructionsArray {
                if let stepDict = item as? [String: Any],
                   let text = stepDict["text"] as? String {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        steps.append(trimmed)
                    }
                } else if let text = item as? String {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        steps.append(trimmed)
                    }
                }
            }
        }

        guard !ingredients.isEmpty || !steps.isEmpty else {
            return nil
        }

        return Recipe(
            title: title,
            ingredients: ingredients,
            steps: steps,
            sourceURL: sourceURL,
            dateSaved: Date()
        )
    }

    // MARK: - Heuristic HTML Fallback (for pages without JSON-LD)

    /// Try to pull out a reasonable recipe from plain HTML using headings
    /// like "Ingredients" and "Instructions" and their nearby lists.
    private static func extractFromHTMLStructure(_ html: String, sourceURL: URL) -> Recipe? {
        // Title: prefer <h1>, then <title>
        let titleHTML = firstMatch(
            in: html,
            pattern: "(?is)<h1[^>]*>([\\s\\S]*?)</h1>"
        ) ?? firstMatch(
            in: html,
            pattern: "(?is)<title[^>]*>([\\s\\S]*?)</title>"
        )

        let title: String
        if let rawTitle = titleHTML,
           let stripped = stripHTMLTags(rawTitle),
           !stripped.isEmpty {
            title = stripped
        } else {
            title = "Recipe"
        }

        // Ingredients block: between an "Ingredients" heading and the next heading
        let ingredientsHTML = extractSection(
            from: html,
            headingKeywords: ["ingredients"]
        )

        // Instructions block: between an "Instructions / Method / Directions" heading and next heading
        let instructionsHTML = extractSection(
            from: html,
            headingKeywords: ["instructions", "method", "directions", "preparation", "steps"]
        )

        var ingredients: [String] = []
        if let block = ingredientsHTML {
            // Prefer list items under the ingredients section
            let liItems = allMatches(
                in: block,
                pattern: "(?is)<li[^>]*>([\\s\\S]*?)</li>"
            )
            ingredients = liItems
                .compactMap { stripHTMLTags($0) }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            // Fallback: split plain text by newlines if no <li> items found
            if ingredients.isEmpty {
                let textBlock = stripHTMLTags(block) ?? ""
                ingredients = textBlock
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }

        var steps: [String] = []
        if let block = instructionsHTML {
            let liItems = allMatches(
                in: block,
                pattern: "(?is)<li[^>]*>([\\s\\S]*?)</li>"
            )
            steps = liItems
                .compactMap { stripHTMLTags($0) }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if steps.isEmpty {
                let textBlock = stripHTMLTags(block) ?? ""
                steps = textBlock
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }

        // Require at least *something* useful
        guard !ingredients.isEmpty || !steps.isEmpty else {
            return nil
        }

        return Recipe(
            title: title,
            ingredients: ingredients,
            steps: steps,
            sourceURL: sourceURL,
            dateSaved: Date()
        )
    }

    /// Extract the HTML block that follows a heading containing one of the given keywords,
    /// up until the next heading or end of document.
    private static func extractSection(from html: String, headingKeywords: [String]) -> String? {
        let keywordPattern = headingKeywords.joined(separator: "|")
        let pattern = "(?is)<h[1-6][^>]*>[^<]*(?:\(keywordPattern))[^<]*</h[1-6]>([\\s\\S]*?)(?=<h[1-6][^>]*>[^<]*</h[1-6]>|$)"
        return firstMatch(in: html, pattern: pattern)
    }

    /// Return the first captured group 1 match for the regex pattern.
    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    /// Return all captured group 1 matches for the regex pattern.
    private static func allMatches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, options: [], range: nsRange).compactMap { match in
            guard match.numberOfRanges >= 2,
                  let range = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return String(text[range])
        }
    }

    /// Very lightweight HTML tag stripper for small fragments.
    private static func stripHTMLTags(_ html: String) -> String? {
        // Remove tags
        let withoutTags: String
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            let range = NSRange(html.startIndex..., in: html)
            withoutTags = regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: " ")
        } else {
            withoutTags = html
        }

        // Decode a few common entities
        let decoded = withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")

        let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}


