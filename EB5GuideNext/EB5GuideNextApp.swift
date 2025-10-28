//
//  EB5GuideNextApp.swift
//  EB5GuideNext
//
//  Created by Vadim Alexeev on 28.10.25.
//

import SwiftUI

@main
struct EB5GuideNextApp: App {
    @StateObject private var languageManager = LanguageManager()
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(languageManager)
                .environment(\.locale, languageManager.currentLocale)
        }
    }
}
