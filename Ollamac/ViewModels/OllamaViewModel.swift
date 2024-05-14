//
//  OllamaViewModel.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 04/11/23.
//
import SwiftData
import SwiftUI
import ViewState
import OllamaKit

@Observable
final class OllamaViewModel {
    private var modelContext: ModelContext
    private var ollamaKit: OllamaKit
    
    var models: [OllamaModel] = []
    
    init(modelContext: ModelContext, ollamaKit: OllamaKit) {
        self.modelContext = modelContext
        self.ollamaKit = ollamaKit
        
        // Add the hardcoded ChatGPT model during initialization
        self.addChatGPTModel()
        self.addClaudeModel()
    }
    
    func isReachable() async -> Bool {
        await ollamaKit.reachable()
    }
    
    @MainActor
    func fetch() async throws {
        let prevModels = try self.fetchFromLocal()
        let newModels = try await self.fetchFromRemote()
        
        for model in prevModels {
            if newModels.contains(where: { $0.name == model.name }) {
                model.isAvailable = true
            } else if !model.isAPI {
                model.isAvailable = false
            }
        }
        
        for newModel in newModels {
            let model = OllamaModel(name: newModel.name, isAPI: false, apiKey: "", apiURL: "", modelVersion: "")
            model.isAvailable = true
            self.modelContext.insert(model)
        }
        
        try self.modelContext.saveChanges()
        
        // Fetch the models from the local storage, including the ChatGPT model
        models = try self.fetchFromLocal()
    }
    
    private func fetchFromRemote() async throws -> [OKModelResponse.Model] {
        let response = try await ollamaKit.models()
        let models = response.models
        
        return models
    }
    
    private func fetchFromLocal() throws -> [OllamaModel] {
        let sortDescriptor = SortDescriptor(\OllamaModel.name)
        let fetchDescriptor = FetchDescriptor<OllamaModel>(sortBy: [sortDescriptor])
        let models = try modelContext.fetch(fetchDescriptor)
        
        return models
    }
    
    private func addChatGPTModel() {
        // Create the ChatGPT model
        let chatGPTModel = OllamaModel(name: "gpt-4o", isAPI: true, apiKey: AppSettings.shared.openAIAPIKey, apiURL: "https://api.openai.com/v1/chat/completions", modelVersion: "gpt-4o")
        chatGPTModel.isAvailable = true
        
        // Save the ChatGPT model to the local storage
        modelContext.insert(chatGPTModel)
        do {
            try modelContext.saveChanges()
        } catch {
            print("Error saving ChatGPT model: \(error)")
        }
    }
    
    private func addClaudeModel() {
        // Create the ChatGPT model
        let claudeModel = OllamaModel(name: "claude3-Opus", isAPI: true, apiKey: AppSettings.shared.claudeAPIKey, apiURL: "https://api.anthropic.com/v1/messages", modelVersion: "claude-3-opus-20240229")
        claudeModel.isAvailable = true
        
        // Save the ChatGPT model to the local storage
        modelContext.insert(claudeModel)
        do {
            try modelContext.saveChanges()
        } catch {
            print("Error saving Claude model: \(error)")
        }
    }
    
}
