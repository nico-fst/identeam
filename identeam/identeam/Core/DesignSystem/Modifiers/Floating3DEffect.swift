//
//  Floating3DEffect.swift
//  identeam
//
//  Created by Nico Stern on 20.05.26.
//

import SwiftUI

struct Floating3DEffect: ViewModifier {
    let isActive: Bool
    let animationFactor: CGFloat
    
    @State private var animate = false

    @State private var xAngle: Double = 5
    @State private var yAngle: Double = 5
    @State private var zAngle: Double = 1.5
    @State private var duration: Double = 4
    
    private func randomize() {
        xAngle = Double.random(in: 2...7) * animationFactor
        yAngle = Double.random(in: 2...7) * animationFactor
        zAngle = Double.random(in: 0.5...2) * animationFactor
        duration = Double.random(in: 3.5...5.5)
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(isActive
                    ? (animate ? xAngle : -xAngle)
                    : 0
                ),
                axis: (x: 1, y: 0, z: 0)
            )
            .rotation3DEffect(
                .degrees(isActive
                    ? (animate ? yAngle : -yAngle)
                    : 0
                ),
                axis: (x: 0, y: 1, z: 0)
            )
            .rotation3DEffect(
                .degrees(isActive
                    ? (animate ? zAngle : -zAngle)
                    : 0
                ),
                axis: (x: 0, y: 0, z: 1)
            )
            .animation(
                isActive
                    ? .easeInOut(duration: duration).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.2),
                value: animate
            )
            .animation(.easeOut(duration: 0.2), value: isActive)
            .onAppear {
                guard isActive else {
                    return
                }

                randomize()
                DispatchQueue.main.async {
                    animate.toggle()
                }
            }
            .onChange(of: isActive) { _, newValue in
                guard newValue else {
                    animate = false
                    return
                }

                randomize()
                DispatchQueue.main.async {
                    animate.toggle()
                }
            }
        
    }
}
