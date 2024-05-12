//  Created by Andy Browning on 5/10/24.
//  StatusBarController.swift
//  Ollamac
import Foundation
import SwiftUI

class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var popover: NSPopover

    init(popover: NSPopover) {
        self.popover = popover
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)

        if let statusBarButton = statusItem.button {
            statusBarButton.image = NSImage(systemSymbolName: "bubble.right", accessibilityDescription: "Open Ollamac")
            statusBarButton.action = #selector(togglePopover(_:))
            statusBarButton.target = self
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            if let statusBarButton = statusItem.button {
                popover.show(relativeTo: statusBarButton.bounds, of: statusBarButton, preferredEdge: NSRectEdge.minY)
            }
        }
    }

    deinit {
        statusBar.removeStatusItem(statusItem)
    }
}
