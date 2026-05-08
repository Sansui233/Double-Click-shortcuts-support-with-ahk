#Requires AutoHotkey v2.0

; ============================================================================
; Configuration
; ============================================================================

TARGET_APP := "CLIPStudioPaint.exe"

; ============================================================================
; Hotkeys - Complete passthrough, no remapping
; ============================================================================

#HotIf WinActive("ahk_exe " TARGET_APP)

keys := "abcdefghijklmnopqrstuvwxyz0123456789"

HandleKey(key) {
    ; Always pass through - no remapping
    Send("{" . key . " down}")
    KeyWait(key)
    Send("{" . key . " up}")
    return
}

for i, char in StrSplit(keys) {
    currentChar := char
    Hotkey("$" currentChar, ((k) => (*) => HandleKey(k))(currentChar))
}

#HotIf
