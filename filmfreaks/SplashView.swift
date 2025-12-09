//
//  SplashView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 30.11.25.
//

internal import SwiftUI

struct SplashView: View {
    
    /// Wird aufgerufen, wenn die Animation fertig ist
    var onAnimationCompleted: () -> Void
    
    @State private var isOpen = false
    @State private var fadeOut = false
    @State private var scale: CGFloat = 0.9   // für den leichten Bounce
    
    var body: some View {
        ZStack {
            // Hintergrund mit leichtem Verlauf
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                clapperView
                    .scaleEffect(scale)   // Bounce-Skalierung
                
                Text("TMC - The Movie Club")
                    .foregroundStyle(.white)
                    .font(.title2.bold())
            }
            .opacity(fadeOut ? 0 : 1)
        }
        .onAppear {
            runAnimation()
        }
    }
    
    // MARK: - Filmklappe
    
    private var clapperView: some View {
        ZStack(alignment: .topLeading) {
            // Unterer Teil der Klappe
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .frame(width: 180, height: 110)
                .shadow(radius: 10)
            
            // Oberer beweglicher Teil
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .frame(width: 180, height: 40)
                .offset(y: -26)
                .rotationEffect(.degrees(isOpen ? -30 : 0), anchor: .leading)
                .shadow(radius: 6)
            
            // Kleine Streifen auf der Oberklappe (Deko)
            HStack(spacing: 4) {
                ForEach(0..<6) { index in
                    Rectangle()
                        .fill(index.isMultiple(of: 2) ? Color.black : Color.clear)
                        .frame(width: 20, height: 8)
                }
            }
            .offset(x: 10, y: -18)
        }
    }
    
    // MARK: - Animation
    
    private func runAnimation() {
        // Start: etwas kleiner
        scale = 0.9
        
        // 1. Klappe auf + Bounce nach oben
        withAnimation(.interpolatingSpring(stiffness: 200, damping: 18)) {
            isOpen = true
            scale = 1.05
        }
        
        // 2. kurz halten, dann wieder schließen + auf Endgröße gehen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.interpolatingSpring(stiffness: 220, damping: 20)) {
                isOpen = false
                scale = 1.0
            }
        }
        
        // 3. ausfaden
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                fadeOut = true
            }
        }
        
        // 4. SplashView beenden
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            onAnimationCompleted()
        }
    }
}

#Preview {
    SplashView(onAnimationCompleted: {})
}
