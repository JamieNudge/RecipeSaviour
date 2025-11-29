import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            RSTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("🥘")
                    .font(.system(size: 80))
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
                    .onAppear {
                        isAnimating = true
                    }
                
                Text("Recipe Saviour")
                    .rsAppTitle()
            }
        }
        .drawingGroup() // Optimize rendering
    }
}

