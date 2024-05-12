import SwiftUI
import Sparkle
import OllamaKit
import SwiftData

@main
struct OllamacApp: App {
    private var updater: SPUUpdater
    static var statusBar: StatusBarController?

    @State private var updaterViewModel: UpdaterViewModel
    @State private var commandViewModel: CommandViewModel
    @State private var ollamaViewModel: OllamaViewModel
    @State private var chatViewModel: ChatViewModel
    @State private var messageViewModel: MessageViewModel

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Chat.self, Message.self, OllamaModel.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        let modelContext = sharedModelContainer.mainContext
        let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        updater = updaterController.updater

        _updaterViewModel = State(wrappedValue: UpdaterViewModel(updater))
        _commandViewModel = State(wrappedValue: CommandViewModel())
        _ollamaViewModel = State(wrappedValue: OllamaViewModel(modelContext: modelContext, ollamaKit: OllamaKit(baseURL: URL(string: "http://localhost:11434")!)))
        _messageViewModel = State(wrappedValue: MessageViewModel(modelContext: modelContext, ollamaKit: OllamaKit(baseURL: URL(string: "http://localhost:11434")!)))
        _chatViewModel = State(wrappedValue: ChatViewModel(modelContext: modelContext))

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 600, height: 900)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: AppView()
            .environment(updaterViewModel)
            .environment(commandViewModel)
            .environment(chatViewModel)
            .environment(messageViewModel)
            .environment(ollamaViewModel))

        OllamacApp.statusBar = StatusBarController(popover: popover)
    }

    var body: some Scene {
        Settings {
            // Optional: Provide a settings view or empty view if necessary.
            Text("Settings and information")
                .padding()
        }
    }
}

