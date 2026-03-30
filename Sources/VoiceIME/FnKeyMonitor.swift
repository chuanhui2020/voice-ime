import CoreGraphics
import Carbon.HIToolbox

class FnKeyMonitor {
    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnIsDown = false

    func start() {
        let eventMask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let fnFlag = flags.contains(.maskSecondaryFn)

        // Fn key: flagsChanged with keyCode 63
        if type == .flagsChanged && keyCode == 0x3F {
            if fnFlag && !fnIsDown {
                fnIsDown = true
                DispatchQueue.main.async { self.onFnDown?() }
                return nil
            } else if !fnFlag && fnIsDown {
                fnIsDown = false
                DispatchQueue.main.async { self.onFnUp?() }
                return nil
            }
            return Unmanaged.passRetained(event)
        }

        // Also detect Fn via flagsChanged without specific keyCode (some keyboards)
        if type == .flagsChanged {
            if fnFlag && !fnIsDown {
                let otherModifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
                let hasOtherModifiers = !flags.intersection(otherModifiers).isEmpty
                if !hasOtherModifiers {
                    fnIsDown = true
                    DispatchQueue.main.async { self.onFnDown?() }
                    return nil
                }
            } else if !fnFlag && fnIsDown {
                fnIsDown = false
                DispatchQueue.main.async { self.onFnUp?() }
                return nil
            }
        }

        return Unmanaged.passRetained(event)
    }
}
