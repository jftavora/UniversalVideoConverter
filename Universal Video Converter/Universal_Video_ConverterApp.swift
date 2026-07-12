//
//  Universal_Video_ConverterApp.swift
//  Universal Video Converter
//
//  Created by João Fernando Távora on 12/06/26.
//

import SwiftUI

@main
struct Universal_Video_ConverterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Forces the window to clear background focus glitches
                .frame(minWidth: 500, minHeight: 340)
        }
        // Tells macOS this is a standard, user-controlled interactive window
        .windowStyle(.hiddenTitleBar)
    }
}
