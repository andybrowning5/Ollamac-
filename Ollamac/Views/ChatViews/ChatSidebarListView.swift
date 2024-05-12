//
//  ChatSidebarListView.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 05/11/23.
//

import SwiftUI
import ViewCondition

struct ChatSidebarListView: View {
    @Environment(CommandViewModel.self) private var commandViewModel
    @Environment(ChatViewModel.self) private var chatViewModel
    
    @State private var isHoveredNewChat = false
    @State private var isHoveredMic = false
    
    private var todayChats: [Chat] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return chatViewModel.chats.filter {
            calendar.isDate($0.modifiedAt, inSameDayAs: today)
        }
    }
    
    private var yesterdayChats: [Chat] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        return chatViewModel.chats.filter {
            calendar.isDate($0.modifiedAt, inSameDayAs: yesterday)
        }
    }
    
    private var previousDays: [Chat] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        return chatViewModel.chats.filter {
            !calendar.isDate($0.modifiedAt, inSameDayAs: today) && !calendar.isDate($0.modifiedAt, inSameDayAs: yesterday)
        }
    }
    
    var body: some View {
        @Bindable var commandViewModelBindable = commandViewModel
        VStack {
            Button(action: {
                commandViewModel.isAddChatViewPresented = true
            }) {
                Image(systemName: "plus.bubble.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isHoveredNewChat ? Color.purple : .white)
            }
            .buttonStyle(PlainButtonStyle())

            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHoveredNewChat ? Color.purple : Color.white, lineWidth: 1)
                    .frame(width: 24, height: 24)
            )
            .padding(.top, 15)  // Reduced padding around the button
            .padding(.trailing, 70)
            .onHover { hover in
                isHoveredNewChat = hover
            }

            Divider()
                .padding(.top, 10)
            List(selection: $commandViewModelBindable.selectedChat) {
                Section(header: Text("Today")) {
                    ForEach(todayChats) { chat in
                        VStack(alignment: .leading, spacing: 2) {
                            Label(chat.name, systemImage: "bubble.right")
                            if let modelName = chat.model?.name {
                                Text(modelName)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .contextMenu {
                            ChatContextMenu(commandViewModel, for: chat)
                        }
                        .tag(chat)
                    }
                }
                .hide(if: todayChats.isEmpty, removeCompletely: true)

                Section(header: Text("Yesterday")) {
                    ForEach(yesterdayChats) { chat in
                        VStack(alignment: .leading, spacing: 2) {
                            Label(chat.name, systemImage: "bubble.right")
                            if let modelName = chat.model?.name {
                                Text(modelName)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .contextMenu {
                            ChatContextMenu(commandViewModel, for: chat)
                        }
                        .tag(chat)
                    }
                }
                .hide(if: yesterdayChats.isEmpty, removeCompletely: true)

                Section(header: Text("Previous Days")) {
                    ForEach(previousDays) { chat in
                        VStack(alignment: .leading, spacing: 2) {
                            Label(chat.name, systemImage: "bubble.right")
                            if let modelName = chat.model?.name {
                                Text(modelName)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .contextMenu {
                            ChatContextMenu(commandViewModel, for: chat)
                        }
                        .tag(chat)
                    }
                }
                .hide(if: previousDays.isEmpty, removeCompletely: true)
            }
            .listStyle(.sidebar)
            .task {
                try? chatViewModel.fetch()
            }

        }
        .toolbar {
            ToolbarItemGroup {
                Spacer()
                
                Button("New Chat", systemImage: "square.and.pencil") {
                    commandViewModel.isAddChatViewPresented = true
                }
                .buttonStyle(.accessoryBar)
                .help("New Chat (⌘ + N)")
            }
        }
        .navigationDestination(for: Chat.self) { chat in
            MessageView(for: chat)
        }
        .sheet(
            isPresented: $commandViewModelBindable.isAddChatViewPresented
        ) {
            AddChatView() { createdChat in
                self.commandViewModel.selectedChat = createdChat
            }
        }
        .sheet(
            isPresented: $commandViewModelBindable.isRenameChatViewPresented
        ) {
            if let chatToRename = commandViewModel.chatToRename {
                RenameChatView(for: chatToRename)
            }
        }
        .confirmationDialog(
            AppMessages.chatDeletionTitle,
            isPresented: $commandViewModelBindable.isDeleteChatConfirmationPresented
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: deleteAction)
        } message: {
            Text(AppMessages.chatDeletionMessage)
        }
        .dialogSeverity(.critical)
    }

    
    // MARK: - Actions
    func deleteAction() {
        guard let chatToDelete = commandViewModel.chatToDelete else { return }
        try? chatViewModel.delete(chatToDelete)
        
        commandViewModel.chatToDelete = nil
        commandViewModel.selectedChat = nil
    }
}
