//
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
    
    private let apiKeyKey = "OpenAI_APIKey"
    
    var apiKey: String {
        get {
            UserDefaults.standard.string(forKey: apiKeyKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: apiKeyKey)
        }
    }
}

struct SettingsView: View {
    @State private var apiKey = AppSettings.shared.apiKey
    
    var body: some View {
        VStack {
            Text("Settings")
                .font(.title)
                .padding(2)
            
            VStack {
                Text("OpenAI API Key")
                    .font(.headline)
                    .padding(.bottom, 8)
                
                SecureField("Enter OpenAI API Key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 20)
                
                Button("Save") {
                    AppSettings.shared.apiKey = apiKey
                }
                .padding(.top, 20)
            }
            .padding(.vertical, 20)
            .cornerRadius(10)
            .padding(.horizontal, 20)
            
            Spacer()
            
            Text("Make sure to enter a valid OpenAI API key to use the app's text to speech feature.")
                .font(.footnote)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(width: 500, height: 300)
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
