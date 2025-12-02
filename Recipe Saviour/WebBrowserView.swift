//
//  WebBrowserView.swift
//  Recipe Saviour
//
//  In-app web browser for browsing recipe websites
//

import SwiftUI
import WebKit

// MARK: - WebView (UIViewRepresentable wrapper for WKWebView)

struct WebView: UIViewRepresentable {
    let url: URL?
    @Binding var currentURL: URL?
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var pageTitle: String
    
    let webView: WKWebView
    
    init(url: URL?, 
         currentURL: Binding<URL?>,
         isLoading: Binding<Bool>,
         canGoBack: Binding<Bool>,
         canGoForward: Binding<Bool>,
         pageTitle: Binding<String>,
         webView: WKWebView) {
        self.url = url
        self._currentURL = currentURL
        self._isLoading = isLoading
        self._canGoBack = canGoBack
        self._canGoForward = canGoForward
        self._pageTitle = pageTitle
        self.webView = webView
    }
    
    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        if let url = url {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Only load if URL changed and is different from current
        if let url = url, url != currentURL {
            uiView.load(URLRequest(url: url))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.currentURL = webView.url
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
            parent.pageTitle = webView.title ?? ""
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}

// MARK: - Browser View with Controls

struct BrowserView: View {
    @Binding var isPresented: Bool
    let onExtractRecipe: (URL) -> Void
    
    @State private var urlText: String = "https://www.google.com/search?q=recipes"
    @State private var currentURL: URL? = nil
    @State private var isLoading: Bool = false
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var pageTitle: String = ""
    @State private var navigateToURL: URL? = URL(string: "https://www.google.com/search?q=recipes")
    
    @StateObject private var webViewStore = WebViewStore()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // URL Bar
                HStack(spacing: 8) {
                    // URL input
                    HStack {
                        Image(systemName: isLoading ? "arrow.triangle.2.circlepath" : "globe")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        
                        TextField("Enter URL or search", text: $urlText)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                            .submitLabel(.go)
                            .onSubmit {
                                navigateToEnteredURL()
                            }
                        
                        if !urlText.isEmpty {
                            Button(action: { urlText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Go button
                    Button(action: navigateToEnteredURL) {
                        Text("Go")
                            .fontWeight(.medium)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                Divider()
                
                // Web View
                ZStack {
                    WebView(
                        url: navigateToURL,
                        currentURL: $currentURL,
                        isLoading: $isLoading,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward,
                        pageTitle: $pageTitle,
                        webView: webViewStore.webView
                    )
                    
                    if isLoading {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.8))
                    }
                }
                
                Divider()
                
                // Bottom toolbar
                HStack(spacing: 0) {
                    // Back
                    Button(action: { webViewStore.webView.goBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canGoBack)
                    
                    // Forward
                    Button(action: { webViewStore.webView.goForward() }) {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canGoForward)
                    
                    // Refresh
                    Button(action: { webViewStore.webView.reload() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                    }
                    
                    // Extract Recipe Button
                    Button(action: {
                        if let url = currentURL {
                            onExtractRecipe(url)
                            isPresented = false
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "fork.knife")
                            Text("Extract")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(currentURL != nil ? RSTheme.Colors.primary : Color.gray)
                        .cornerRadius(20)
                    }
                    .disabled(currentURL == nil)
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
            }
            .navigationTitle(pageTitle.isEmpty ? "Browse Recipes" : pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onChange(of: currentURL) { _, newURL in
                if let url = newURL {
                    urlText = url.absoluteString
                }
            }
        }
    }
    
    private func navigateToEnteredURL() {
        var urlString = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If no scheme, add https://
        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            // Check if it looks like a URL or a search query
            if urlString.contains(".") && !urlString.contains(" ") {
                urlString = "https://" + urlString
            } else {
                // Treat as search query
                let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
                urlString = "https://www.google.com/search?q=\(encoded)"
            }
        }
        
        if let url = URL(string: urlString) {
            navigateToURL = url
        }
    }
}

// MARK: - WebView Store (to maintain WKWebView instance)

class WebViewStore: ObservableObject {
    let webView: WKWebView
    
    init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        self.webView = WKWebView(frame: .zero, configuration: configuration)
    }
}

// MARK: - Quick Recipe Sites

struct QuickSiteButton: View {
    let name: String
    let urlString: String
    let action: (URL) -> Void
    
    var body: some View {
        Button(action: {
            if let url = URL(string: urlString) {
                action(url)
            }
        }) {
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray5))
                .cornerRadius(15)
        }
        .buttonStyle(.plain)
    }
}

