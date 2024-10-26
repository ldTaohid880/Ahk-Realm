#Requires AutoHotkey v2.0
#include ./lib/WinEvent.ahk
#include ./Lib/Misc.ahk
#include ./Lib/Array.ahk
CoordMode('Mouse', 'Screen')  ; Set coordinate mode to 'Screen' for mouse position tracking

global monitor1WindowList := []  ; List of window IDs that are being tracked
global monitor2WindowList := []  ; List of window IDs that are being tracked
global lastWindow := ''  ; ID of the last active window

exceptionClass :=
    '(Shell_TrayWnd|Shell_SecondaryTrayWnd|WorkerW|Windows.UI.Core.CoreWindow|#32770|TaskListThumbnailWnd|ApplicationManager_DesktopShellWindow|MultitaskingViewFrame|ForegroundStaging)'  ; Classes to ignore
exceptionEXE := '(LogiOverlay.exe|Zoom.exe)'  ; exe to ignore

; command := DllCall('GetCommandLineA','str')

; ;check if the script is running as Admin
; if (!A_IsAdmin || RegExMatch(command," /restart(?!\S)")) {
;     ; if not relaunce the script with admin rights
;     try {
;         if (A_IsCompiled) {
;             Run('*RunAs "' A_ScriptFullPath '" /restart')
;         } else {
;             Run('*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"')
;         }
;         ExitApp()
;     }
; }

WinEvent.Active(ActiveWindowChanged)
WinEvent.MoveEnd(ActiveWindowPositionChanged)
WinEvent.Close(WindowClosed)

Persistent()

WindowClosed(hWnd,*){
    OutputDebug(hWnd "Closed")
}

ActiveWindowChanged(hWnd, *) {

    try {
        global monitor1WindowList
        global monitor2WindowList

        activeWinClass := WinGetClass(hWnd)
        activeWinExe := WinGetProcessName(hWnd)

        if (RegExMatch(activeWinClass, exceptionClass) || RegExMatch(activeWinExe, exceptionEXE)) {

            return
        }

        windowPosition := GetMonitorIndexFromWindow(hWnd)

        ; Check current position in both monitor lists
        indexInMonitor1 := HasVal(monitor1WindowList, hWnd)
        indexInMonitor2 := HasVal(monitor2WindowList, hWnd)

        if (windowPosition = 1) {

            if (indexInMonitor1 = 0 && indexInMonitor2 > 0) {
                ; Move from Monitor 2 to Monitor 1
                monitor2WindowList.RemoveAt(indexInMonitor2)  ; Remove from Monitor 2

            } else if (indexInMonitor1 > 0 && indexInMonitor2 = 0) {
                ; Remove the window from its current position in the list
                monitor1WindowList.RemoveAt(indexInMonitor1)
            }

            ; Insert the window at the beginning of the list (most recently active)
            monitor1WindowList.InsertAt(1, hWnd)
        }

        if (windowPosition = 2) {

            if (indexInMonitor1 > 0 && indexInMonitor2 = 0) {
                ; Move from Monitor 1 to Monitor 2
                monitor1WindowList.RemoveAt(indexInMonitor1)  ; Remove from Monitor 1

            } else if (indexInMonitor1 = 0 && indexInMonitor2 > 0) {
                ; Remove the window from its current position in the list
                monitor2WindowList.RemoveAt(indexInMonitor2)
            }

            ; Insert the window at the beginning of the list (most recently active)
            monitor2WindowList.InsertAt(1, hWnd)
        }
    }catch (Error as err) {
        OutputDebug(err)
    }
}

ActiveWindowPositionChanged(hWnd, *) {
    global monitor1WindowList
    global monitor2WindowList

    activeWinClass := WinGetClass(hWnd)
    activeWinExe := WinGetProcessName(hWnd)

    if (RegExMatch(activeWinClass, exceptionClass) || RegExMatch(activeWinExe, exceptionEXE)) {
        return
    }

    currentWindowPosition := GetMonitorIndexFromWindow(hWnd)

    ; Check current position in both monitor lists
    indexInMonitor1 := HasVal(monitor1WindowList, hWnd)
    indexInMonitor2 := HasVal(monitor2WindowList, hWnd)

    ; If the window is in Monitor 1
    if (currentWindowPosition = 1) {
        if (indexInMonitor1 = 0 && indexInMonitor2 > 0) {
            ; Move from Monitor 2 to Monitor 1
            monitor2WindowList.RemoveAt(indexInMonitor2)  ; Remove from Monitor 2
            monitor1WindowList.InsertAt(1, hWnd)  ; Add to Monitor 1
        }
    }

    ; If the window is in Monitor 2
    if (currentWindowPosition = 2) {
        if (indexInMonitor2 = 0 && indexInMonitor1 > 0) {
            ; Move from Monitor 1 to Monitor 2
            monitor1WindowList.RemoveAt(indexInMonitor1)  ; Remove from Monitor 1
            monitor2WindowList.InsertAt(1, hWnd)  ; Add to Monitor 2
        }
    }
}

; Function to check if a value exists in an array (returns index if found)
HasVal(haystack, needle) {
    if !(IsObject(haystack)) || (haystack.Length = 0)
        return 0
    for index, value in haystack
        if (value = needle)
            return index
    return 0
}

; Function to get the monitor index where the given window is located
GetMonitorIndexFromWindow(winID) {
    monitorCount := MonitorGetCount()

    if (monitorCount = 1) {
        return 1  ; If only one monitor, return the first monitor
    }

    ; Get monitor handle based on the window ID
    monitorHandle := DllCall("User32.dll\MonitorFromWindow", "Ptr", winID, "UInt", 2, "Ptr")
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

    return false  ; Return false if no matching monitor is found
}

; Function to get the monitor index based on the current mouse position
GetMonitorIndexFromMouse() {
    monitorCount := MonitorGetCount()

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

F1:: {
    activeNextWindow()
}

activeNextWindow(initialState := 2) {
    activeMonitor := GetMonitorIndexFromMouse()
    state := initialState

    while (true) {

        if (activeMonitor = 1) {

            if (monitor1WindowList.Length = 0) {
                return
            }

            if (monitor1WindowList.Length = 1) {
                state := 1
            }

            if !WinExist(monitor1WindowList[state]) {

                monitor1WindowList.RemoveAt(state)

                state++
                if (state > monitor1WindowList.Length) {
                    break
                }
                continue
            }
            WinActivate(monitor1WindowList[state])
            break
        }

        if (activeMonitor = 2) {

            if (monitor2WindowList.Length = 0) {
                return
            }

            if (monitor2WindowList.Length = 1) {
                state := 1
            }

            if !WinExist(monitor2WindowList[state]) {

                monitor2WindowList.RemoveAt(state)

                state++
                if (state > monitor2WindowList.Length) {
                    break
                }
                continue
            }

            WinActivate(monitor2WindowList[state])
            break
        }
    }
}
