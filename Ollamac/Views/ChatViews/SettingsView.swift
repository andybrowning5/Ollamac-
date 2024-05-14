//  SettingsView.swift
//  Ollamac
//
//  Created by Andy Browning on 5/12/24.
//

import Foundation
import SwiftUI

class AppSettings {
    static let shared = AppSettings()
    
    private init() {}
    
    private let openAIAPIKeyKey = "openAIAPIKey"
    private let claudeAPIKeyKey = "claudeAPIKey"
    
    var openAIAPIKey: String {
        get {
            UserDefaults.standard.string(forKey: openAIAPIKeyKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: openAIAPIKeyKey)
        }
    }
    
    var claudeAPIKey: String {
        get {
            UserDefaults.standard.string(forKey: claudeAPIKeyKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: claudeAPIKeyKey)
        }
    }
}

struct SettingsView: View {
    @State private var openAIAPIKey = AppSettings.shared.openAIAPIKey
    @State private var claudeAPIKey = AppSettings.shared.claudeAPIKey
    
    var body: some View {
        VStack {
            Text("Settings")
                .font(.title)
                .padding(2)
            
            VStack {
                Text("OpenAI API Key")
                    .font(.headline)
                    .padding(.bottom, 8)
                
                SecureField("Enter OpenAI API Key", text: $openAIAPIKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 20)
                
                Button("Save OpenAI API Key") {
                    AppSettings.shared.openAIAPIKey = openAIAPIKey
                }
                .padding(.top, 10)
                
                Text("Claude API Key")
                    .font(.headline)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                
                SecureField("Enter Claude API Key", text: $claudeAPIKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 20)
                
                Button("Save Claude API Key") {
                    AppSettings.shared.claudeAPIKey = claudeAPIKey
                }
                .padding(.top, 10)
            }
            .padding(.vertical, 20)
            .cornerRadius(10)
            .padding(.horizontal, 20)
            
            Spacer()
            
            Text("Make sure to enter valid API keys to use the app's features.")
                .font(.footnote)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(width: 500, height: 400)
    }
}

extension View {
    func centerHorizontally() -> some View {
        HStack {
            Spacer()
            self
            Spacer()
        }
    }
}
