// Heavily inspired from: https://www.youtube.com/watch?v=UraPKevc8MI

import SwiftUI

struct LaunchScreen<RootView: View, Logo: View>: Scene {
    @ViewBuilder var logo: () -> Logo
    @ViewBuilder var rootContent: RootView
    
    var config: LaunchScreenConfig = .init()
    
    var body: some Scene {
        WindowGroup {
           rootContent
                .modifier(LaunchScreenModifier(logo: logo, config: config))
        }
    }
}

fileprivate struct LaunchScreenModifier<Logo: View>: ViewModifier {
    @ViewBuilder var logo: Logo
    
    var config: LaunchScreenConfig
    
    // View Props
    @Environment(\.scenePhase) private var scenePhase
    @State private var splashWindow: UIWindow?
    
    func body(content: Content) -> some View {
        content
        
        // adding overlay window so splash screen visible on top of entire app
            .onAppear() {
                let scenes = UIApplication.shared.connectedScenes
                
                for scene in scenes {
                    guard let windowScene = scene as? UIWindowScene,
                            checkStates(windowScene.activationState), // same activation states?
                            !windowScene.windows.contains(where: { $0.tag == 1009 }) // no splash screen already?
                    else {
                        print("Already has splash window for this scene")
                        continue
                    }
                    
                    let window = UIWindow(windowScene: windowScene)
                    window.backgroundColor = .clear
                    window.isHidden = false
                    window.isUserInteractionEnabled = true
                    let rootViewController = UIHostingController(rootView: LaunchScreenView(config: config) {
                        logo
                    } isCompleted: {
                        window.isHidden = true
                        window.isUserInteractionEnabled = false
                    })
                    window.tag = 1009 // if several screens opened
                    rootViewController.view.backgroundColor = .clear
                    window.rootViewController = rootViewController
                    
                    self.splashWindow = window
                    print("Splash Window added")
                }
            }
    }
    
    /// Checking ScenePhase and WindowScene activation states are same
    private func checkStates(_ state: UIWindowScene.ActivationState) -> Bool {
        switch scenePhase {
        case .active: return state == .foregroundActive
        case .inactive: return state == .foregroundInactive
        case .background: return state == .background
        default: return state.hashValue == scenePhase.hashValue
        }
    }
}

struct LaunchScreenConfig {
    var initialDelay: Double = 0.35
    var backgroundColor: Color = .accent
    
    var forceHideLogo: Bool = false
    var logoScale: CGFloat = 1
    
    var initialOffset: CGFloat = 200
    var bounceOffset: CGFloat = 100
    var flyOutOffset: CGFloat = 1200
    
    var bounceAnimation: Animation = .interpolatingSpring(duration: 0.38, bounce: 0.45)
    var flyOutAnimation: Animation = .interpolatingSpring(duration: 1, bounce: 0)
}

fileprivate struct LaunchScreenView<Logo: View>: View {
    var config: LaunchScreenConfig
    @ViewBuilder var logo: Logo
    var isCompleted: () -> ()
    
    // View Props
    @State private var bounceUp: Bool = false
    @State private var flyOut: Bool = false

    var body: some View {
        Rectangle()
            .fill(config.backgroundColor.opacity(flyOut ? 0 : 1))
            .overlay {
                if !config.forceHideLogo {
                    logo
                        .scaleEffect(config.logoScale)
                        .offset(y: flyOut ? config.flyOutOffset : (bounceUp ? config.bounceOffset : config.initialOffset))
                }
            }
            .ignoresSafeArea()
            .task {
                guard !bounceUp else { return }
                try? await Task.sleep(for: .seconds(config.initialDelay))
                
                withAnimation(config.bounceAnimation) {
                    bounceUp = true
                }
                
                try? await Task.sleep(for: .seconds(0.22))
                
                withAnimation(config.flyOutAnimation, completionCriteria: .logicallyComplete) {
                    flyOut = true
                } completion: {
                    isCompleted()
                }
            }
    }
}
