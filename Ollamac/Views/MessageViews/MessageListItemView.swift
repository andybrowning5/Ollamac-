//
//  MessageListItemView.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 04/11/23.
//  Edited by Andy Browning on 05/11/24.
//

import SwiftUI
import MarkdownUI
import ViewCondition
import Highlightr
import AVFoundation

class AudioPlayerDelegate: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isAudioPlaying: Bool = false
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isAudioPlaying = false
    }
}

struct MessageListItemView: View {
    private var isAssistant: Bool = false
    private var isGenerating: Bool = false
    private var isFinalMessage: Bool = false
    private var isError: Bool = false
    private var errorMessage: String? = nil
    
    let text: String
    let regenerateAction: () -> Void
    
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isHovered: Bool = false
    @State private var isCopied: Bool = false
    @State private var isAudioLoading: Bool = false
    @State private var isAudioPlaying: Bool = false
    
    @StateObject private var audioPlayerDelegate = AudioPlayerDelegate()
    
    init(_ text: String, regenerateAction: @escaping () -> Void = {}) {
        self.text = text
        self.regenerateAction = regenerateAction
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isAssistant ? "Assistant" : "You")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.accent)
                
                
                if isAssistant {
                    Button(action: togglePlayPause) {
                        GeometryReader { geometry in
                            if isAudioLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.5)
                                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                            } else {
                                Image(systemName: audioPlayerDelegate.isAudioPlaying ? "pause.fill" : "play.fill")
                                    .foregroundColor(.white)
                                    .frame(width: 12, height: 12)
                                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                            }
                        }
                        .frame(width: 20, height: 20)
                        .background(Color.gray)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            if isGenerating {
                ProgressView()
                    .controlSize(.small)
            } else if let errorMessage = errorMessage, isError {
                TextError(errorMessage)
            } else {
                Markdown(text)
                    .textSelection(.enabled)
                    .markdownTextStyle(\.text) {
                        FontSize(NSFont.preferredFont(forTextStyle: .title3).pointSize)
                    }
                    .markdownTextStyle(\.code) {
                        FontFamily(.system(.monospaced))
                    }
                    .markdownBlockStyle(\.codeBlock) { configuration in
                        HighlightedCodeBlock(code: configuration.content, theme: "nord")
                    }
            }
            if isAssistant {
                HStack(alignment: .center, spacing: 8) {
                    Button(action: copyAction) {
                        Image(systemName: isCopied ? "list.clipboard.fill" : "clipboard")
                    }
                    .buttonStyle(.accessoryBar)
                    .clipShape(.circle)
                    .help("Copy")
                    .visible(if: isCopyButtonVisible)
                    
                    Button(action: regenerateAction) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.accessoryBar)
                    .clipShape(.circle)
                    .help("Regenerate")
                    .visible(if: isRegenerateButtonVisible)
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onHover { isHovered = $0; isCopied = false }
    }
    
    private var isCopyButtonVisible: Bool {
        isHovered && isAssistant && !isGenerating
    }
    
    private var isRegenerateButtonVisible: Bool {
        isCopyButtonVisible && isFinalMessage
    }
    
    private func copyAction() {
        let content = MarkdownContent(text)
        let plainText = content.renderPlainText()
        
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(plainText, forType: .string)
        
        isCopied = true
    }
    
    private func playSpeech() {
        isAudioLoading = true
        
        let urlString = "https://api.openai.com/v1/audio/speech"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Use the API key from AppSettings
        let apiKey = AppSettings.shared.openAIAPIKey
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "tts-1",
            "input": text,
            "voice": "alloy"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            print("Failed to serialize data:", error)
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error fetching audio: \(error?.localizedDescription ?? "No error description.")")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    isAudioLoading = false
                    self.playAudio(data: data)
                }
            } else {
                print("Received an invalid response: \(String(describing: response))")
            }
        }
        
        task.resume()
    }
    
    private func playAudio(data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            audioPlayerDelegate.isAudioPlaying = true
            
            audioPlayer?.delegate = audioPlayerDelegate
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    private func togglePlayPause() {
        if audioPlayerDelegate.isAudioPlaying {
            audioPlayer?.pause()
            audioPlayerDelegate.isAudioPlaying = false
        } else if !isAudioLoading {
            if audioPlayer?.isPlaying == false {
                audioPlayer?.play()
                audioPlayerDelegate.isAudioPlaying = true
            } else {
                playSpeech()
            }
        }
    }
    
    
    // MARK: - Modifiers
    public func assistant(_ isAssistant: Bool) -> MessageListItemView {
        var view = self
        view.isAssistant = isAssistant
        return view
    }
    
    public func generating(_ isGenerating: Bool) -> MessageListItemView {
        var view = self
        view.isGenerating = isGenerating
        return view
    }
    
    public func finalMessage(_ isFinalMessage: Bool) -> MessageListItemView {
        var view = self
        view.isFinalMessage = isFinalMessage
        return view
    }
    
    public func error(_ isError: Bool, message: String?) -> MessageListItemView {
        var view = self
        view.isError = isError
        view.errorMessage = message ?? "An error occurred"
        return view
    }
}


