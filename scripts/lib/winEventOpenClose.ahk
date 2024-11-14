#Requires AutoHotkey v2.0

global gOpenWindows := Map()
global EVENT_OBJECT_CREATE := 0x8000
global EVENT_OBJECT_DESTROY := 0x8001
global OBJID_WINDOW := 0
global INDEXID_CONTAINER := 0

; Set up our hook. Putting it in a variable is necessary to keep the hook alive, since once it gets
; rewritten (for example with hook := "") the hook is automatically destroyed.
hook := WinEventHook(HandleWinEvent)
; We have no hotkeys, so Persistent is required to keep the script going.
Persistent()

/**
 * Our event handler which needs to accept 7 arguments. To ignore some of them use the * character,
 * for example HandleWinEvent(hWinEventHook, event, hwnd, idObject, idChild, *)
 * @param hWinEventHook Handle to an event hook function. This isn't useful for our purposes 
 * @param event Specifies the event that occurred. This value is one of the event constants (https://learn.microsoft.com/en-us/windows/win32/winauto/event-constants).
 * @param hwnd Handle to the window that generates the event, or NULL if no window is associated with the event.
 * @param idObject Identifies the object associated with the event.
 * @param idChild Identifies whether the event was triggered by an object or a child element of the object.
 * @param idEventThread Id of the thread that triggered this event.
 * @param dwmsEventTime Specifies the time, in milliseconds, that the event was generated.
 */
HandleWinEvent(hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime) {
    Critical -1
    idObject := idObject << 32 >> 32, idChild := idChild << 32 >> 32, event &= 0xFFFFFFFF, idEventThread &= 0xFFFFFFFF,
        dwmsEventTime &= 0xFFFFFFFF ; convert to INT/UINT

    global gOpenWindows
    if (idObject = OBJID_WINDOW && idChild = INDEXID_CONTAINER) { ; Filters out only windows
        ; GetAncestor checks that we are dealing with a top-level window, not a control. This doesn't work
        ; for EVENT_OBJECT_DESTROY events.
        if (event = EVENT_OBJECT_CREATE && DllCall("IsTopLevelWindow", "Ptr", hwnd)) {
            ; open event
        } else if (event = EVENT_OBJECT_DESTROY) {
            if gOpenWindows.Has(hwnd) {
                ; Delete info about windows that have been destroyed to avoid unnecessary memory usage
                gOpenWindows.Delete(hwnd)
            }
        }
        SetTimer(ToolTip, -3000) ; Remove created ToolTip in 3 seconds
    }
}

class WinEventHook {
    /**
     * Sets a new WinEventHook and returns on object describing the hook. 
     * When the object is released, the hook is also released. Alternatively use WinEventHook.Stop()
     * to stop the hook.
     * @param callback The function that will be called, which needs to accept 7 arguments:
     *    hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime
     * @param eventMin Optional: Specifies the event constant for the lowest event value in the range of events that are handled by the hook function.
     *  Default is the lowest possible event value.
     *  See more about event constants: https://learn.microsoft.com/en-us/windows/win32/winauto/event-constants
     *  Msaa Events List: Https://Msdn.Microsoft.Com/En-Us/Library/Windows/Desktop/Dd318066(V=Vs.85).Aspx
     *  System-Level And Object-Level Events: Https://Msdn.Microsoft.Com/En-Us/Library/Windows/Desktop/Dd373657(V=Vs.85).Aspx
     *  Console Accessibility: Https://Msdn.Microsoft.Com/En-Us/Library/Ms971319.Aspx
     * @param eventMax Optional: Specifies the event constant for the highest event value in the range of events that are handled by the hook function.
     *  If eventMin is omitted then the default is the highest possible event value.
     *  If eventMin is specified then the default is eventMin.
     * @param winTitle Optional: WinTitle of a certain window to hook to. Default is system-wide hook.
     * @param PID Optional: process ID of the process for which threads to hook to. Default is system-wide hook.
     * @param skipOwnProcess Optional: whether to skip windows (eg Tooltips) from the running script. 
     *  Default is not to skip.
     * @returns {WinEventHook} 
     */
    __New(callback, eventMin?, eventMax?, winTitle := 0, PID := 0, skipOwnProcess := false) {
        if !HasMethod(callback)
            throw ValueError("The callback argument must be a function", -1)
        if !IsSet(eventMin)
            eventMin := 0x00000001, eventMax := IsSet(eventMax) ? eventMax : 0x7fffffff
        else if !IsSet(eventMax)
            eventMax := eventMin
        this.callback := callback, this.winTitle := winTitle, this.flags := skipOwnProcess ? 2 : 0, this.eventMin :=
            eventMin, this.eventMax := eventMax, this.threadId := 0
        if winTitle != 0 {
            if !(this.winTitle := WinExist(winTitle))
                throw TargetError("Window not found", -1)
            this.threadId := DllCall("GetWindowThreadProcessId", "Int", this.winTitle, "UInt*", &PID)
        }
        this.pCallback := CallbackCreate(callback, "C", 7)
        , this.hHook := DllCall("SetWinEventHook", "UInt", eventMin, "UInt", eventMax, "Ptr", 0, "Ptr", this.pCallback,
            "UInt", this.PID := PID, "UInt", this.threadId, "UInt", this.flags)
    }
    Stop() => this.__Delete()
    __Delete() {
        if (this.pCallback)
            DllCall("UnhookWinEvent", "Ptr", this.hHook), CallbackFree(this.pCallback), this.hHook := 0, this.pCallback :=
            0
    }
}
