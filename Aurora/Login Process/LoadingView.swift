//
//  LoadingView.swift
//  Aurora
//
//  Created by Zifan Deng on 1/29/25.
//
import SwiftUI

@MainActor
class LoadingManager: ObservableObject {
    static let shared = LoadingManager()
    @Published var isLoading = false
    private init() {}
    
    func show() {
        isLoading = true
    }
    
    func hide() {
        isLoading = false
    }
}

struct LoadingOverlay: ViewModifier {
    @ObservedObject var manager = LoadingManager.shared
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if manager.isLoading {
                Image("splashscreen")
                    .resizable()
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaledToFill()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: manager.isLoading)
    }
}

extension View {
    func loadingOverlay() -> some View {
        modifier(LoadingOverlay())
    }
}
