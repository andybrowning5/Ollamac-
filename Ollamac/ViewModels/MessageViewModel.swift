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
                    let response = try await sendChatGPTRequest(message.prompt ?? "")
                    handleChatGPTResponse(response, for: message)
                } catch {
                    handleChatGPTError(error.localizedDescription, for: message)
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
                    handleChatGPTError(error.localizedDescription, for: message)
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

        let apiKey = AppSettings.shared.apiKey

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

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
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
            handleChatGPTError("Invalid ChatGPT response", for: message)
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

    private func handleChatGPTError(_ errorMessage: String, for message: Message) {
        message.error = true
        message.done = false

        try? modelContext.saveChanges()
        sendViewState = .error(message: errorMessage)
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

    enum APIError: Error {
        case invalidURL
        case invalidResponse
    }
}
