//
//  WebBrowserView.swift
//  Recipe Saviour
//
//  In-app web browser for browsing recipe websites
//

import SwiftUI
import WebKit
import Combine

// MARK: - Simple WebView wrapper

struct SimpleWebView: UIViewRepresentable {
    let webView: WKWebView
    
    func makeUIView(context: Context) -> WKWebView {
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No-op - we control loading imperatively via webViewStore
    }
}

// MARK: - Browser View with Controls

struct BrowserView: View {
    @Binding var isPresented: Bool
    let onExtractRecipe: (URL) -> Void
    
    @StateObject private var webViewStore = WebViewStore()
    @State private var urlText: String = ""
    @State private var hasLoadedInitial: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // URL Bar
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: webViewStore.isLoading ? "arrow.triangle.2.circlepath" : "globe")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .rotationEffect(.degrees(webViewStore.isLoading ? 360 : 0))
                            .animation(webViewStore.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: webViewStore.isLoading)
                        
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
                    
                    Button(action: navigateToEnteredURL) {
                        Text("Go")
                            .fontWeight(.medium)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 2)
                        
                        Rectangle()
                            .fill(RSTheme.Colors.primary)
                            .frame(width: geometry.size.width * webViewStore.progress, height: 2)
                            .animation(.easeInOut(duration: 0.2), value: webViewStore.progress)
                    }
                }
                .frame(height: 2)
                .opacity(webViewStore.isLoading ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: webViewStore.isLoading)
                
                // Web View
                SimpleWebView(webView: webViewStore.webView)
                    .onAppear {
                        if !hasLoadedInitial {
                            hasLoadedInitial = true
                            urlText = "https://duckduckgo.com"
                            webViewStore.load(urlString: "https://duckduckgo.com")
                        }
                    }
                
                Divider()
                
                // Bottom toolbar
                HStack(spacing: 0) {
                    Button(action: { webViewStore.webView.goBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!webViewStore.canGoBack)
                    .opacity(webViewStore.canGoBack ? 1 : 0.4)
                    
                    Button(action: { webViewStore.webView.goForward() }) {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!webViewStore.canGoForward)
                    .opacity(webViewStore.canGoForward ? 1 : 0.4)
                    
                    Button(action: {
                        if webViewStore.isLoading {
                            webViewStore.webView.stopLoading()
                        } else {
                            webViewStore.webView.reload()
                        }
                    }) {
                        Image(systemName: webViewStore.isLoading ? "xmark" : "arrow.clockwise")
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                    }
                    
                    Button(action: {
                        if let url = webViewStore.currentURL {
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
                        .background(webViewStore.currentURL != nil ? RSTheme.Colors.primary : Color.gray)
                        .cornerRadius(20)
                    }
                    .disabled(webViewStore.currentURL == nil)
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
            }
            .navigationTitle(webViewStore.pageTitle.isEmpty ? "Browse Recipes" : webViewStore.pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onChange(of: webViewStore.currentURL) { _, newURL in
                if let url = newURL {
                    urlText = url.absoluteString
                }
            }
        }
    }
    
    private func navigateToEnteredURL() {
        var urlString = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty else { return }
        
        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            if urlString.contains(".") && !urlString.contains(" ") {
                urlString = "https://" + urlString
            } else {
                let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
                urlString = "https://duckduckgo.com/?q=\(encoded)"
            }
        }
        
        webViewStore.load(urlString: urlString)
    }
}

// MARK: - WebView Store (manages WKWebView and state)

class WebViewStore: NSObject, ObservableObject, WKNavigationDelegate {
    let webView: WKWebView
    
    @Published var currentURL: URL?
    @Published var pageTitle: String = ""
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var progress: Double = 0.0
    @Published var isLoading: Bool = false
    
    private var progressObservation: NSKeyValueObservation?
    private var urlObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?
    private var loadingObservation: NSKeyValueObservation?
    private var backObservation: NSKeyValueObservation?
    private var forwardObservation: NSKeyValueObservation?
    
    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.suppressesIncrementalRendering = false
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        
        super.init()
        
        webView.navigationDelegate = self
        webView.allowsLinkPreview = true
        
        setupObservers()
    }
    
    private func setupObservers() {
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.progress = webView.estimatedProgress
            }
        }
        
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.currentURL = webView.url
            }
        }
        
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.pageTitle = webView.title ?? ""
            }
        }
        
        loadingObservation = webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.isLoading = webView.isLoading
            }
        }
        
        backObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.canGoBack = webView.canGoBack
            }
        }
        
        forwardObservation = webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.canGoForward = webView.canGoForward
            }
        }
    }
    
    func load(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        webView.load(URLRequest(url: url))
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // State is updated via KVO observers
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Errors are handled gracefully - page just won't load
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // Provisional navigation failures (DNS, etc.) are handled gracefully
    }
    
    deinit {
        progressObservation?.invalidate()
        urlObservation?.invalidate()
        titleObservation?.invalidate()
        loadingObservation?.invalidate()
        backObservation?.invalidate()
        forwardObservation?.invalidate()
    }
}

// MARK: - Quick Recipe Sites (kept for potential future use)

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
