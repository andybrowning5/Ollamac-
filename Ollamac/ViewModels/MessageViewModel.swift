//  MessageViewModel.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 04/11/23.
//

import Combine
import Foundation
import OllamaKit
import SwiftData
import ViewState

@Observable
final class MessageViewModel {
    private var generation: AnyCancellable?
    private var modelContext: ModelContext
    private var ollamaKit: OllamaKit
    
    var messages: [Message] = []
    var sendViewState: ViewState? = nil
    
    init(modelContext: ModelContext, ollamaKit: OllamaKit) {
        self.modelContext = modelContext
        self.ollamaKit = ollamaKit
    }
    
    deinit {
        stopGenerate()
    }
    
    func fetch(for chat: Chat) throws {
        let chatId = chat.id
        let predicate = #Predicate<Message>{ $0.chat?.id == chatId }
        let sortDescriptor = SortDescriptor(\Message.createdAt)
        let fetchDescriptor = FetchDescriptor<Message>(predicate: predicate, sortBy: [sortDescriptor])
        
        messages = try modelContext.fetch(fetchDescriptor)
    }
    
    @MainActor
    func send(_ message: Message) async {
        sendViewState = .loading
        
        messages.append(message)
        modelContext.insert(message)
        try? modelContext.saveChanges()
        
        if let model = message.chat?.model {
            if model.isAPI {
                do {
                    if model.name == "claude3-Opus" {
                        let response = try await sendClaudeRequest(message.prompt ?? "")
                        handleClaudeResponse(response, for: message)
                    } else {
                        let response = try await sendChatGPTRequest(message.prompt ?? "")
                        handleChatGPTResponse(response, for: message)
                    }
                } catch {
                    handleError(error.localizedDescription)
                }
            } else {
                if await ollamaKit.reachable() {
                    let data = message.convertToOKGenerateRequestData()
                    
                    generation = ollamaKit.generate(data: data)
                        .sink(receiveCompletion: { [weak self] completion in
                            switch completion {
                            case .finished:
                                self?.handleComplete()
                            case .failure(let error):
                                self?.handleError(error.localizedDescription)
                            }
                        }, receiveValue: { [weak self] response in
                            self?.handleReceive(response)
                        })
                } else {
                    handleError(AppMessages.ollamaServerUnreachable)
                }
            }
        } else {
            handleError("No chat or model found for the message")
        }
    }
    
    @MainActor
    func regenerate(_ message: Message) async {
        sendViewState = .loading
        
        messages[messages.endIndex - 1] = message
        try? modelContext.saveChanges()
        
        if let model = message.chat?.model {
            if model.isAPI {
                do {
                    let response = try await sendChatGPTRequest(message.prompt ?? "")
                    handleChatGPTResponse(response, for: message)
                } catch {
                    handleChatGPTError(error.localizedDescription as! Error, for: message)
                }
            } else {
                if await ollamaKit.reachable() {
                    let data = message.convertToOKGenerateRequestData()
                    
                    generation = ollamaKit.generate(data: data)
                        .sink(receiveCompletion: { [weak self] completion in
                            switch completion {
                            case .finished:
                                self?.handleComplete()
                            case .failure(let error):
                                self?.handleError(error.localizedDescription)
                            }
                        }, receiveValue: { [weak self] response in
                            self?.handleReceive(response)
                        })
                } else {
                    handleError(AppMessages.ollamaServerUnreachable)
                }
            }
        } else {
            handleError("No chat or model found for the message")
        }
    }
    
    
    func stopGenerate() {
        sendViewState = nil
        generation?.cancel()
        try? modelContext.saveChanges()
    }
    
    private func handleReceive(_ response: OKGenerateResponse) {
        if messages.isEmpty { return }
        
        let lastIndex = messages.count - 1
        let lastMessageResponse = messages[lastIndex].response ?? ""
        messages[lastIndex].context = response.context
        messages[lastIndex].response = lastMessageResponse + response.response
        
        sendViewState = .loading
    }
    
    private func handleError(_ errorMessage: String) {
        if messages.isEmpty { return }
        
        let lastIndex = messages.count - 1
        messages[lastIndex].error = true
        messages[lastIndex].done = false
        
        try? modelContext.saveChanges()
        sendViewState = .error(message: errorMessage)
    }
    
    private func handleComplete() {
        if messages.isEmpty { return }
        
        let lastIndex = messages.count - 1
        messages[lastIndex].error = false
        messages[lastIndex].done = true
        
        try? modelContext.saveChanges()
        sendViewState = nil
    }
    
    private func sendChatGPTRequest(_ prompt: String) async throws -> ChatGPTResponse {
        let endpoint = "https://api.openai.com/v1/chat/completions"
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }
        
        let apiKey = AppSettings.shared.openAIAPIKey
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Collect chat history
        var chatHistory: [[String: String]] = []
        for message in messages {
            if let prompt = message.prompt {
                chatHistory.append(["role": "user", "content": prompt])
            }
            if let response = message.response {
                chatHistory.append(["role": "assistant", "content": response])
            }
        }
        // Append the current message
        chatHistory.append(["role": "user", "content": prompt])
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": chatHistory
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.invalidAPIKey
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let chatGPTResponse = try JSONDecoder().decode(ChatGPTResponse.self, from: data)
        return chatGPTResponse
    }
    
    private func handleChatGPTResponse(_ response: ChatGPTResponse, for message: Message) {
        if let choice = response.choices.first,
           let content = choice.message.content {
            Task {
                await displayTypingEffect(for: message, content: content)
            }
        } else {
            handleChatGPTError("Invalid ChatGPT response" as! Error, for: message)
        }
    }
    
    @MainActor
    private func displayTypingEffect(for message: Message, content: String) async {
        let words = content.split(separator: " ")
        message.response = ""
        message.done = false
        
        for word in words {
            message.response! += (message.response!.isEmpty ? "" : " ") + word
            try? modelContext.saveChanges()
            try? await Task.sleep(nanoseconds: 10_000_000) // Adjust delay as needed
        }
        
        message.done = true
        try? modelContext.saveChanges()
        sendViewState = nil
    }
    
    private func handleChatGPTError(_ error: Error, for message: Message) {
        message.error = true
        message.done = false
        
        if let apiError = error as? APIError {
            switch apiError {
            case .invalidAPIKey:
                sendViewState = .error(message: "Please enter a valid API key in the settings to use this model")
            case .invalidURL, .invalidResponse:
                sendViewState = .error(message: apiError.errorDescription ?? "Unknown error")
            }
        } else {
            sendViewState = .error(message: error.localizedDescription)
        }
        
        try? modelContext.saveChanges()
    }
    
    private func sendClaudeRequest(_ prompt: String) async throws -> ClaudeResponse {
        let endpoint = "https://api.anthropic.com/v1/messages"
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }
        
        let apiKey = AppSettings.shared.claudeAPIKey
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Collect chat history
        var chatHistory: [[String: String]] = []
        for message in messages {
            if let prompt = message.prompt {
                chatHistory.append(["role": "user", "content": prompt])
            }
            if let response = message.response {
                chatHistory.append(["role": "assistant", "content": response])
            }
        }
        
        let requestBody: [String: Any] = [
            "model": "claude-3-opus-20240229",
            "max_tokens": 1024,
            "messages": chatHistory // Include the chat history in the request body
        ]
        
        print("Request Body: \(requestBody)")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody, options: [.prettyPrinted])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.invalidAPIKey
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        
        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return claudeResponse
    }
    
    private func handleClaudeResponse(_ response: ClaudeResponse, for message: Message) {
        if let content = response.content.first {
            let responseText = content.text
            if responseText.isEmpty {
                print("Empty Claude response")
                handleClaudeError("Received an empty response from Claude" as! Error, for: message)
            } else {
                Task {
                    await displayTypingEffect(for: message, content: responseText)
                }
            }
        } else {
            print("Missing content in Claude response")
            handleClaudeError("Received a response without content from Claude" as! Error, for: message)
        }
    }

    private func handleClaudeError(_ error: Error, for message: Message) {
        message.error = true
        message.done = false
        
        if let apiError = error as? APIError {
            switch apiError {
            case .invalidAPIKey:
                sendViewState = .error(message: "Please enter a valid API key in the settings to use this model")
            case .invalidURL, .invalidResponse:
                sendViewState = .error(message: apiError.errorDescription ?? "Unknown error")
            }
        } else {
            sendViewState = .error(message: error.localizedDescription)
        }
        
        try? modelContext.saveChanges()
    }
    
    struct ChatGPTResponse: Codable {
        let choices: [ChatGPTChoice]
    }
    
    struct ChatGPTChoice: Codable {
        let message: ChatGPTMessage
    }
    
    struct ChatGPTMessage: Codable {
        let content: String?
    }
    
    enum APIError: LocalizedError {
        case invalidURL
        case invalidResponse
        case invalidAPIKey
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response"
            case .invalidAPIKey:
                return "Invalid API key (restart app and update the api key in settings)"
            }
        }
    }
    
    struct ClaudeResponse: Codable {
        let id: String
        let type: String
        let role: String
        let model: String
        let stopSequence: String?
        let usage: ClaudeUsage
        let content: [ClaudeContent]
        let stopReason: String
        
        enum CodingKeys: String, CodingKey {
            case id, type, role, model
            case stopSequence = "stop_sequence"
            case usage, content
            case stopReason = "stop_reason"
        }
    }
    
    struct ClaudeUsage: Codable {
        let inputTokens: Int
        let outputTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }
    
    struct ClaudeContent: Codable {
        let type: String
        let text: String
    }
}
