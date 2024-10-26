#Requires AutoHotkey v2.0

CoordMode('Mouse', 'Screen')  ; Set coordinate mode to 'Screen' for mouse position tracking
DetectHiddenWindows(0)

; Map out all open windows so we can keep track of their names when they're closed.
; After the window close event the windows no longer have their titles, so we can't do it afterwards.
; global gOpenWindows := Map()

;map out all monitor and windows to track;
global gMonitors := Map()
global EVENT_OBJECT_CREATE := 0x8000
global EVENT_OBJECT_DESTROY := 0x8001
global EVENT_SYSTEM_FOREGROUND := 0x0003
global EVENT_SYSTEM_MOVESIZEEND := 0x000B
global EVENT_SYSTEM_MOVESIZESTART := 0x000A
global EVENT_SYSTEM_MINIMIZEEND := 0x0017
global EVENT_SYSTEM_MINIMIZESTART := 0x0016
global OBJID_WINDOW := 0
global INDEXID_CONTAINER := 0
global monitorCount := SysGet(80)

; Classes to ignore
global exceptionClass :=
    '(Shell_TrayWnd|Shell_SecondaryTrayWnd|WorkerW|Windows.UI.Core.CoreWindow|#32770|TaskListThumbnailWnd|ApplicationManager_DesktopShellWindow|MultitaskingViewFrame|ForegroundStaging)'

loop monitorCount {
    gMonitors[A_Index] := Array()
}

for hwnd in WinGetList() {
    try {
        winclass := WinGetClass(hwnd)
        if (!RegExMatch(winclass, exceptionClass)) {
            ; gOpenWindows[hwnd] := {
            ;     title: WinGetTitle(hwnd),
            ;     class: winclass,
            ;     processName: WinGetProcessName(hwnd),
            ;     monitorID: GetMonitorIndexFromWindow(hwnd)
            ; }

            gMonitors[GetMonitorIndexFromWindow(hwnd)].Push({
                id: hwnd,
                title: WinGetTitle(hwnd),
                class: winclass,
                processName: WinGetProcessName(hwnd),
            })
        }
    }
}

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
    idObject := idObject << 32 >> 32
    idChild := idChild << 32 >> 32
    event &= 0xFFFFFFFF
    idEventThread &= 0xFFFFFFFF
    dwmsEventTime &= 0xFFFFFFFF ; convert to INT/UINT

    global gMonitors
    if (idObject = OBJID_WINDOW && idChild = INDEXID_CONTAINER) { ; Filters out only windows
        ; GetAncestor checks that we are dealing with a top-level window, not a control. This doesn't work
        ; for EVENT_OBJECT_DESTROY events.
        if (event = EVENT_OBJECT_CREATE && DllCall("IsTopLevelWindow", "Ptr", hwnd)) {
            try {
                winclass := WinGetClass(hwnd)
                if (!RegExMatch(winclass, exceptionClass)) {
                    ; Update gOpenWindows accordingly
                    monitorIndex := GetMonitorIndexFromWindow(hwnd)

                    gMonitors[monitorIndex].Push({
                        id: hwnd,
                        title: WinGetTitle(hwnd),
                        class: winclass,
                        processName: WinGetProcessName(hwnd),
                    })



                    OutputDebug(gMonitors[monitorIndex].get(gMonitors[monitorIndex].Length).processName " <<== New Open, monitor ==>> " monitorIndex)
                    ; OutputDebug(gMonitors[GetMonitorIndexFromWindow(hwnd)][1].processName " <<== New Open, monitor ==>> " gMonitors[
                    ;     hwnd].monitorID
                    ; )
                }
            }
        } else if (event = EVENT_SYSTEM_FOREGROUND) {
            if gMonitors.Has(hwnd) {

                ; OutputDebug(WinGetProcessName(hwnd) " <<== active monitor ==>> " gMonitors[hwnd].monitorID)
            }
        } else if (event = EVENT_SYSTEM_MINIMIZESTART) {
            ; OutputDebug(WinGetProcessName(hwnd) " <<== minimized monitor ==>> " gMonitors[hwnd].monitorID)
        } else if (event = EVENT_SYSTEM_MINIMIZEEND) {
            ; OutputDebug(WinGetProcessName(hwnd) " <<== maximized monitor ==>> " gMonitors[hwnd].monitorID)
        } else if (event = EVENT_SYSTEM_MOVESIZEEND) {

            ; gMonitors[hwnd] := {
            ;     title: WinGetTitle(hwnd),
            ;     class: WinGetClass(hwnd),
            ;     processName: WinGetProcessName(hwnd),
            ;     monitorID: GetMonitorIndexFromWindow(hwnd)
            ; }

            ; OutputDebug(WinGetProcessName(hwnd) " <<== moveEnd monitor ==>> " gMonitors[hwnd].monitorID)
        } else if (event = EVENT_SYSTEM_MOVESIZESTART) {
            ; OutputDebug(WinGetProcessName(hwnd) " <<== MoveStart monitor ==>> " gMonitors[hwnd].monitorID)

        } else if (event = EVENT_OBJECT_DESTROY) {
            monitorIndex := GetMonitorIndexFromWindow(hwnd)
            if gMonitors.Has(monitorIndex) {
                winId := gMonitors[monitorIndex].Has({ID:hwnd})
                OutputDebug(gMonitors[monitorIndex].get())
                ; OutputDebug(gMonitors[hwnd].processName " <<== Closed, monitor ==>> " gMonitors[hwnd].monitorID)
                ; Delete info about windows that have been destroyed to avoid unnecessary memory usage
                ; gMonitors.Delete(hwnd)

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

GetMonitorIndexFromWindow(hWnd) {
    global monitorCount

    if (monitorCount = 1) {
        return 1  ; If only one monitor, return the first monitor
    }

    try {
        ; Get monitor handle based on the window ID
        monitorHandle := DllCall("User32.dll\MonitorFromWindow", "Ptr", hWnd, "UInt", 2, "Ptr")
        if !monitorHandle {
            throw Error("Error in DllCall - Unable to get MonitorHandle")
        }

        ; Prepare MONITORINFO structure to retrieve monitor dimensions
        monitorInfo := Buffer(40)
        NumPut("UInt", monitorInfo.Size, monitorInfo)

        ; Get monitor information based on OS version (ANSI for Windows 10, Unicode for others)
        if (SubStr(A_OSVersion, 1, 2) = "10") {
            DllCall("User32.dll\GetMonitorInfoA", "Ptr", monitorHandle, "Ptr", monitorInfo)
        } else {
            DllCall("User32.dll\GetMonitorInfoW", "Ptr", monitorHandle, "Ptr", monitorInfo)
        }

        ; Get monitor bounds
        monitorLeft := NumGet(monitorInfo, 4, "Int")
        monitorTop := NumGet(monitorInfo, 8, "Int")
        monitorRight := NumGet(monitorInfo, 12, "Int")
        monitorBottom := NumGet(monitorInfo, 16, "Int")

        ; Compare monitor dimensions with each monitor on the system
        loop monitorCount {
            MonitorGet(A_Index, &tempMonLeft, &tempMonTop, &tempMonRight, &tempMonBottom)
            if (monitorLeft = tempMonLeft && monitorTop = tempMonTop && monitorRight = tempMonRight && monitorBottom =
                tempMonBottom) {
                return A_Index  ; Return the monitor index if it matches the window's monitor
            }
        }
    }

    return false  ; Return false if no matching monitor is found
}

; Function to get the monitor index based on the current mouse position
GetMonitorIndexFromMouse() {
    global monitorCount

    if (monitorCount = 1) {
        return 1  ; If only one monitor, return the first monitor
    }

    ; Compare mouse position with each monitor's bounds
    loop monitorCount {
        MonitorGet(A_Index, &tempMonLeft, &tempMonTop, &tempMonRight, &tempMonBottom)
        MouseGetPos(&mousePosX, &mousePosY)  ; Get current mouse position

        if (mousePosX >= tempMonLeft && mousePosY >= tempMonTop && mousePosX <= tempMonRight && mousePosY <=
            tempMonBottom) {
            return A_Index  ; Return the monitor index where the mouse is located
        }
    }

    return false  ; Return false if no matching monitor is found
}

; Function to check if a value exists in an array (returns index if found)
HasValue(haystack, needle) {
    if !(IsObject(haystack)) || (haystack.Length = 0){
        return 0
    }
    for index, value in haystack{
        if (value = needle){
            return index
        }
    }
    return 0
}

; activeNextWindow(initialState := 2) {
;     activeMonitor := GetMonitorIndexFromMouse()
;     state := initialState

;     while (true) {

;         if (activeMonitor = 1) {

;             if (monitor1WindowList.Length = 0) {
;                 return
;             }

;             if (monitor1WindowList.Length = 1) {
;                 state := 1
;             }

;             if !WinExist(monitor1WindowList[state]) {

;                 monitor1WindowList.RemoveAt(state)

;                 state++
;                 if (state > monitor1WindowList.Length) {
;                     break
;                 }
;                 continue
;             }
;             WinActivate(monitor1WindowList[state])
;             break
;         }

;         if (activeMonitor = 2) {

;             if (monitor2WindowList.Length = 0) {
;                 return
;             }

;             if (monitor2WindowList.Length = 1) {
;                 state := 1
;             }

;             if !WinExist(monitor2WindowList[state]) {

;                 monitor2WindowList.RemoveAt(state)

;                 state++
;                 if (state > monitor2WindowList.Length) {
;                     break
;                 }
;                 continue
;             }

;             WinActivate(monitor2WindowList[state])
;             break
;         }
;     }
; }

; F1:: activeNextWindow()
