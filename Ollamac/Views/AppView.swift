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
    @State private var isSidebarVisible = true
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                if isSidebarVisible {
                    ChatSidebarListView()
                        .frame(width: 140)
                        .transition(.move(edge: .leading))
                }
                
                Group {
                    if let selectedChat = commandViewModel.selectedChat {
                        MessageView(for: selectedChat)
                    } else {
                        ContentUnavailableView {
                            Text("No Chat Selected")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            VStack {
                HStack {
                    Spacer()
                    SidebarToggleButton(isSidebarVisible: $isSidebarVisible)
                        .padding()
                }
                Spacer()
            }
        }
        .animation(.default, value: isSidebarVisible)
    }
}

struct SidebarToggleButton: View {
    @Binding var isSidebarVisible: Bool
    @State private var isHovering = false  // State to track hover status

    var body: some View {
        Button(action: {
            isSidebarVisible.toggle()
        }) {
            Image(systemName: isSidebarVisible ? "sidebar.left" : "sidebar.right")
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovering ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}


