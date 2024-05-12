import ChatField
import SwiftUI
import SwiftUIIntrospect
import ViewCondition
import ViewState

import Speech

struct MessageView: View {
    private var chat: Chat
    private let recordingColor = Color.red
    
    @State private var speechRecognizer: SFSpeechRecognizer?
    @State private var speechRecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var speechRecognitionTask: SFSpeechRecognitionTask?
    @State private var isRecognizing = false
    @State private var audioEngine: AVAudioEngine?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(ChatViewModel.self) private var chatViewModel
    @Environment(MessageViewModel.self) private var messageViewModel
    @Environment(OllamaViewModel.self) private var ollamaViewModel
    
    @State private var viewState: ViewState? = nil
    
    @FocusState private var promptFocused: Bool
    @State private var prompt: String = ""
    
    init(for chat: Chat) {
        self.chat = chat
    }
    
    var isGenerating: Bool {
        messageViewModel.sendViewState == .loading
    }
    
    var body: some View {
        ScrollViewReader { scrollViewProxy in
            List(messageViewModel.messages.indices, id: \.self) { index in
                let message = messageViewModel.messages[index]
                
                MessageListItemView(message.prompt ?? "")
                    .assistant(false)
                
                MessageListItemView(message.response ?? "") {
                    regenerateAction(for: message)
                }
                .assistant(true)
                .generating(message.response.isNil && isGenerating)
                .finalMessage(index == messageViewModel.messages.endIndex - 1)
                .error(message.error, message: messageViewModel.sendViewState?.errorMessage)
                .id(message)
            }
            .onAppear {
                scrollToBottom(scrollViewProxy)
            }
            .onChange(of: messageViewModel.messages) {
                if !isGenerating {
                    scrollToBottom(scrollViewProxy)
                }
            }
            .onChange(of: messageViewModel.messages.last?.response) {
                if !isGenerating {
                    scrollToBottom(scrollViewProxy)
                }
            }
            
            HStack(alignment: .bottom) {
                
                Button(action: {
                    if isRecognizing {
                        print("Stopping recognition, should keep text.")
                        stopSpeechRecognition() // Ensure text is kept when stopping recognition
                    } else {
                        print("Starting recognition, requesting microphone access.")
                        requestMicrophoneAccess()
                    }
                }) {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 28, height: 28)
                        if isRecognizing {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(recordingColor)
                                .frame(width: 10, height: 10)
                        } else {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 10, height: 10)
                        }
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Circle()) // Correctly set the hitbox to the outer circle
                .help(isRecognizing ? "Stop recording" : "Start recording")
                .hide(if: isGenerating, removeCompletely: true)

                
                
                ChatField("Message", text: $prompt, action: sendAction)
                    .textFieldStyle(CapsuleChatFieldStyle())
                    .focused($promptFocused)
                
                Button(action: sendAction) {
                    Image(systemName: "arrow.up.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Send message")
                .hide(if: isGenerating, removeCompletely: true)
                
                Button(action: messageViewModel.stopGenerate) {
                    Image(systemName: "stop.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Stop generation")
                .visible(if: isGenerating, removeCompletely: true)
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
            .padding(.horizontal)
        }
        .navigationTitle(chat.name)
        .navigationSubtitle(chat.model?.name ?? "")
        .task {
            initAction()
        }
        .onChange(of: chat) {
            initAction()
        }
    }
    
    // MARK: - Actions
    private func initAction() {
        try? messageViewModel.fetch(for: chat)
        
        promptFocused = true
    }
    
    private func sendAction() {
        guard messageViewModel.sendViewState.isNil else { return }
        guard prompt.trimmingCharacters(in: .whitespacesAndNewlines).count > 0 else { return }
        
        let message = Message(prompt: prompt, response: nil)
        message.context = chat.messages.last?.context ?? []
        message.chat = chat
        
        Task {
            try chatViewModel.modify(chat)
            prompt = ""
            await messageViewModel.send(message)
        }
    }
    
    private func regenerateAction(for message: Message) {
        guard messageViewModel.sendViewState.isNil else { return }
        
        message.context = []
        message.response = nil
        
        let lastIndex = messageViewModel.messages.count - 1
        
        if lastIndex > 0 {
            message.context = messageViewModel.messages[lastIndex - 1].context
        }
        
        Task {
            try chatViewModel.modify(chat)
            await messageViewModel.regenerate(message)
        }
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard messageViewModel.messages.count > 0 else { return }
        let lastIndex = messageViewModel.messages.count - 1
        let lastMessage = messageViewModel.messages[lastIndex]
        
        proxy.scrollTo(lastMessage, anchor: .bottom)
    }
    
    private func requestMicrophoneAccess() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if granted {
                // Microphone access granted, start speech recognition
                DispatchQueue.main.async {
                    self.startSpeechRecognition()
                }
            } else {
                // Microphone access denied, handle accordingly
                print("Microphone access denied")
            }
        }
    }
    
    private func startSpeechRecognition() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

        guard let recognizer = speechRecognizer, !isRecognizing else {
            print("Speech recognition already started or not supported")
            return
        }

        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.isRecognizing = true
                    self.setupAudioEngineAndRecognition(recognizer)
                default:
                    print("Speech recognition authorization denied or restricted")
                    self.isRecognizing = false
                }
            }
        }
    }

    private func setupAudioEngineAndRecognition(_ recognizer: SFSpeechRecognizer) {
        self.audioEngine = AVAudioEngine()
        guard let inputNode = self.audioEngine?.inputNode else { return }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        self.speechRecognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.speechRecognitionRequest?.append(buffer)
        }

        do {
            try self.audioEngine?.start()
        } catch {
            print("Audio engine failed to start: \(error)")
            self.stopSpeechRecognition()
            return
        }

        self.speechRecognitionTask = recognizer.recognitionTask(with: self.speechRecognitionRequest!) { result, error in
            if let result = result {
                let recognizedText = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.prompt = recognizedText
                    print("Recognized Text Updated: \(recognizedText)")
                }
                
                if result.isFinal {
                    self.stopSpeechRecognition()
                }
            }
            if error != nil {
                self.stopSpeechRecognition()
            }
        }
    }

    private func stopSpeechRecognition() {
        isRecognizing = false
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        speechRecognitionTask?.finish()
        
        // Delay the cleanup of speechRecognitionRequest to allow the final result to be processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.speechRecognitionRequest = nil
        }
        
        audioEngine = nil
        speechRecognitionTask = nil
    }

}
