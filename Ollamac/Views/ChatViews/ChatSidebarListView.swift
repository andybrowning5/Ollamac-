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
    @State private var isHoveredSettings = false
    @State private var isHoveredMic = false
    @State private var isSettingsPopoverPresented = false
    
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
        VStack(alignment: .leading) {
            HStack(){
                Button(action: {
                    self.isSettingsPopoverPresented = true
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .padding(.bottom, 6)
                        .padding(.leading, 8)
                        .padding(.trailing, 8)
                        .padding(.top, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isHoveredSettings ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                        )
                        .onHover { hovering in
                            isHoveredSettings = hovering
                        }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 16)
                .padding(.leading, 16)
                .padding(.trailing, 4)
                .padding(.bottom, 0)
                .popover(isPresented: $isSettingsPopoverPresented) {
                    SettingsView()
                }
   
                
                Button(action: {
                    commandViewModel.isAddChatViewPresented = true
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .padding(.bottom, 8)
                        .padding(.leading, 8)
                        .padding(.trailing, 8)
                        .padding(.top, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isHoveredNewChat ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                        )
                        .onHover { hovering in
                            isHoveredNewChat = hovering
                        }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 16)
                .padding(.trailing, 16)
                .padding(.leading, 4)
                .padding(.bottom, 0)
            }

            
            List(selection: $commandViewModelBindable.selectedChat) {
                Section(header: Text("Today")) {
                    ForEach(todayChats) { chat in
                        VStack(alignment: .leading, spacing: 2) {
                            Label(chat.name, systemImage: "bubble.right")
                            if let modelName = chat.model?.name {
                                Text(modelName)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
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
                                    .frame(maxWidth: .infinity, alignment: .leading)
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
                                    .frame(maxWidth: .infinity, alignment: .leading)
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





