// AppView.swift
// Ollamac
//
// Created by Kevin Hermawan on 03/11/23.
//
import SwiftUI
import ViewState

struct AppView: View {
    @Environment(CommandViewModel.self) private var commandViewModel
    @State private var isHoveredNewChat = false
    @State private var isHoveredMic = false
    
    var body: some View {
        NavigationSplitView {
            ChatSidebarListView()
                .navigationSplitViewColumnWidth(min: 120, ideal: 120)
        } detail: {
            if let selectedChat = commandViewModel.selectedChat {
                MessageView(for: selectedChat)
            } else {
                ContentUnavailableView {
                    Text("No Chat Selected")
                }
            }
        }
    }
}

