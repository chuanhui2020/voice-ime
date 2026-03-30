import AppKit

let app = NSApplication.shared

// Standard Edit menu so Cmd+C/V/X/A work in text fields
let mainMenu = NSMenu()
let editMenuItem = NSMenuItem()
editMenuItem.submenu = {
    let m = NSMenu(title: "Edit")
    m.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    m.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
    m.addItem(.separator())
    m.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    m.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    m.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    m.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    return m
}()
mainMenu.addItem(editMenuItem)
app.mainMenu = mainMenu

let delegate = AppDelegate()
app.delegate = delegate
app.run()
