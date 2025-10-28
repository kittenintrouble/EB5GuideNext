//
//  ContentView.swift
//  EB5GuideNext
//
//  Created by Vadim Alexeev on 28.10.25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false

    var body: some View {
        Group {
            if hasOnboarded {
                MainTabView()
            } else {
                OnboardingView(onComplete: {
                    hasOnboarded = true
                })
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LanguageManager())
}
