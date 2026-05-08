#Requires AutoHotkey v2.0

; ============================================================================
; Configuration
; ============================================================================

TARGET_APP := "CLIPStudioPaint.exe"
THRESHOLD := 200

#HotIf WinActive(TARGET_APP)

KEY_MAPPINGS := [
    { type: "double-click", source: "a", target_type: "click", target: "^+n" },
    { type: "combine", source: "ax", target_type: "click", target: "{DEL}" }, 
    { type: "long-press", source: "a", target_type: "long-press", target: "d" },
    { type: "click", source: "z", target_type: "click", target: "^z" },
]

IGNORE_KEYS := ["b", "c", "e", "x"]

; ============================================================================
; Global State
; ============================================================================

global trackedKey := ""
global trackedKeyTime := 0
global keyStates := Map()
global mappingCache := Map()
global keys_history := []
global history_hold_state := "init" ; "";"wait-holding"
global history_hold_key := ""

; ============================================================================
; Initialization
; ============================================================================

ValidateMappings()

; ============================================================================
; Functions
; ============================================================================

ValidateMappings() {
    global KEY_MAPPINGS

    for mapping in KEY_MAPPINGS {
        type := mapping.type
        source := mapping.source
        target_type := mapping.target_type

        if (type = "click" or type = "double-click" or type = "long-press") {
            if (StrLen(source) != 1) {
                MsgBox("Error: " type " mapping must have single source key. Found: " source)
                ExitApp()
            }
        } else if (type = "combine") {
            if (StrLen(source) < 2) {
                MsgBox("Error: combine mapping must have multiple source keys. Found: " source)
                ExitApp()
            }
        } else {
            MsgBox("Error: Invalid mapping type: " type)
            ExitApp()
        }

        if (type = "click" or type = "double-click" or type = "combine") {
            if (target_type = "long-press") {
                MsgBox("Error: Cannot map " type " to long-press")
                ExitApp()
            }
        }

        if (target_type = "long-press" and StrLen(mapping.target) != 1) {
            MsgBox("Error: long-press target must be single key. Found: " mapping.target)
            ExitApp()
        }
    }
}

; KEY_MAPPINGS 加个 key 索引，变成 Map<key,item>, 和上面 item 完全一致

IsTargetApp() {
    try {
        return WinActive("ahk_exe " TARGET_APP)
    } catch {
        return false
    }
}

IsIgnoredKey(key) {
    global IGNORE_KEYS
    for ignoredKey in IGNORE_KEYS {
        if (key = ignoredKey) {
            return true
        }
    }
    return false
}

; Check source key, get mapping item. return null if no mapping or not match
GetMapping(source, type) {
    global KEY_MAPPINGS
    for mapping in KEY_MAPPINGS {
        if (mapping.source == source and mapping.type == type) {
            return mapping
        }
    }
    return
}

/**
 * 判断 key 是不是 source 组合键中的前缀
 */
IsPrefix(key) {
    global KEY_MAPPINGS
    for mapping in KEY_MAPPINGS {
        if (mapping.type = "combine" and SubStr(mapping.source, 1, StrLen(key)) = key) {
            return true
        }
    }
    return false
}

IsHistoryEmpty() {
    global keys_history
    return keys_history.Length = 0
}

IsInHistory(key, event) {
    global keys_history
    for item in keys_history {
        if (item.key = key and item.event = event) {
            return true
        }
    }
    return false
}

FindInHistory(key, event) {
    global keys_history
    for item in keys_history {
        if (item.key = key and item.event = event) {
            return item
        }
    }
    return false
}


ResetHistory() {
    global keys_history, history_hold_state, history_hold_key
    
    if (history_hold_state = "wait-holding" && history_hold_key != "") {
        is_up := IsInHistory(history_hold_key, "up")
        item := FindInHistory(history_hold_key, "down")
        ;如果逻辑上 还在按，保持按下状态，等待放开
        if (!is_up && item) {
            ; ToolTip "still holding " history_hold_key
            keys_history := []
            keys_history.Push(item)
            return
        }
    }
    history_hold_state := "init"
    history_hold_key := ""
    keys_history := []
    ; ToolTip ;close ; ToolTip
}

; Core
CheckHistory(now) {
    global keys_history, THRESHOLD, history_hold_state, history_hold_key

    try {
        ; 199ms 时的 Holding Check
        if (keys_history.Length = 0) {
            return
        }
        ; ToolTip now " Start " keys_history[-1].key " " keys_history[-1].event "| History Count: " keys_history.Length

        if (now != keys_history[keys_history.Length].time) {
            isHolding := (keys_history.Length == 1 and keys_history[1].event = "down" and now - keys_history[
                keys_history.Length
                ].time >= THRESHOLD)
            if (isHolding) {
                ; ToolTip "Holding " keys_history[-1].key
                ; ToolTip now " Holding " keys_history[-1].key  "| History Count: " keys_history.Length
                ; 检查 mapping target type 是 long-press，是则按 target key down
                cb_mapping := GetMapping(keys_history[keys_history.Length].key, "long-press")
                if (cb_mapping and cb_mapping.target_type = "long-press") {
                    Send("{" cb_mapping.target " down}")
                } else {
                    Send("{" keys_history[keys_history.Length].key " down}")
                }

                history_hold_key := keys_history[1].key
                history_hold_state := "wait-holding"
                return
            }
        }

        ; ToolTip now  " check " keys_history[-1].key " " keys_history[-1].event " | History Count: " keys_history.Length

        switch history_hold_state {
            case "wait-holding":
                ; 检测查 history 有没有对应的 key up，有的话就直接发出 send keyup
                ; ToolTip now  " wait-holding " keys_history[-1].key " " keys_history[-1].event " | History Count: " keys_history.Length
                for item in keys_history {
                    if (item.key = history_hold_key and item.event == "up") {
                        cb_mapping := GetMapping(item.key, "long-press")
                        if (cb_mapping and cb_mapping.target_type = "long-press") {
                            Send("{" cb_mapping.target " up}")
                        } else {
                            Send("{" item.key " up}")
                        }
                        ResetHistory()
                        return
                    } else if (item.key != history_hold_key and item.event == "down") {
                        ; combine 情况，等待另一个键的 down 来触发发送组合键
                        lp_mapping := GetMapping(item.key, "long-press")
                        cb_mapping := GetMapping(history_hold_key . item.key, "combine")
                        if (cb_mapping and cb_mapping.target_type = "click") {
                            ; release long-press first
                            if (lp_mapping and cb_mapping.target_type = "long-press") {
                                Send("{" lp_mapping.target " up}")
                            } else {
                                Send("{" history_hold_key " up}")
                            }
                            ; send combine -> click
                            Send(cb_mapping.target)
                            ResetHistory()
                            return
                        }
                    }
                }
                throw Error("Invalid state: wait-holding but no keyup/combine found for " . history_hold_key)
            default:
                if (keys_history.Length < 2) {
                    return
                }

                ; ToolTip now  " Default " keys_history[-1].key " " keys_history[-1].event " | History Count: " keys_history.Length " now" A_TickCount

                first := keys_history[1]
                second := keys_history[2]
                if (first.key = second.key and first.event = "down" and second.event = "down") {
                    ; double-click
                    ; ToolTip now  " Default-2click " keys_history[-1].key " " keys_history[-1].event " | History Count: " keys_history.Length

                    cb_mapping := GetMapping(first.key, "double-click")
                    if (cb_mapping and cb_mapping.target_type = "click") {
                        Send(cb_mapping.target)
                    } else {
                        Send(first.key . second.key)
                    }

                    ResetHistory()
                    return
                } else if (first.key != second.key and first.event = "down" and second.event = "down") {
                    ; combine
                    ; ToolTip now  " Default-combine " keys_history[-1].key " " keys_history[-1].event " | History Count: " keys_history.Length

                    cb_mapping := GetMapping(first.key . second.key, "combine")
                    if (cb_mapping and cb_mapping.target_type = "click") {
                        Send(cb_mapping.target)
                    } else {
                        Send(first.key . second.key)
                    }

                    ResetHistory()
                    return

                } else if (first.key = second.key and first.event = "down" and second.event = "up") {
                    if (A_TickCount - first.time < THRESHOLD && keys_history.length <= 2 && IsPrefix(first.key)) {
                        ; wait
                        ; ToolTip now  " Default-wait " A_TickCount - first.time "ms" keys_history[-1].key " " keys_history[-1].event " | History Count: " keys_history.Length " now" A_TickCount

                        SetTimer(() => CheckHistory(A_TickCount), -(THRESHOLD - (A_TickCount - first.time)) - 1)

                        return
                    } else {

                        ; 超时或无需等待
                        if (keys_history.Length = 2) {

                            ; 两条为单击，
                            ; ToolTip now  " Default-click " keys_history[-1].key " " keys_history[-1].event " | History Count: " keys_history.Length

                            cb_mapping := GetMapping(first.key, "click")
                            if (cb_mapping and cb_mapping.target_type = "click") {
                                Send(cb_mapping.target)
                            } else {
                                Send(first.key)
                            }

                            ResetHistory()
                            return

                        } else if (keys_history.Length >= 3) {

                            ;如果有第三条，且第三条是 down，则为 double-click
                            ; ToolTip now  " Default-3key " keys_history[-1].key " " keys_history[-1].event " | History Count: " keys_history.Length A_TickCount

                            third := keys_history[3]
                            if (third.key = first.key and third.event = "down" and third.time - second.time < THRESHOLD
                            ) {
                                ; double-click
                                cb_mapping := GetMapping(first.key, "double-click")
                                if (cb_mapping and cb_mapping.target_type = "click") {
                                    Send(cb_mapping.target)
                                } else {
                                    Send(first.key . third.key)
                                }

                                ResetHistory()
                                return

                            } else {
                                ; 超时，如果第三条不是 double-click，则第一条为单击，第三条为新的开始
                                cb_mapping := GetMapping(first.key, "click")
                                if (cb_mapping and cb_mapping.target_type = "click") {
                                    Send(cb_mapping.target)
                                } else {
                                    Send(first.key)
                                }

                                ResetHistory()
                                return

                            }
                        }
                    }
                } else {
                    ; ToolTip now  " Default-Other " keys_history[-1].key " " keys_history[-1].event " | History Count: " keys_history.Length

                    ; 其他情况，直接按顺序发出 down 和 up
                    for i, item in keys_history {
                        if (item.event = "down") {
                            Send("{" item.key " down}")
                        } else {
                            Send("{" item.key " up}")
                        }
                    }
                    ResetHistory()
                    return
                }

        }
    } catch Error as err {
        ; ToolTip("Error: " err.Message " | History Count: " keys_history.Length " History State: " history_hold_state)
        ResetHistory()
    }

}

; ============================================================================
; Hotkeys
; ============================================================================



HandleKey(key) {
    global keys_history

    now := A_TickCount

    ; Always pass through - no remapping
    if (!IsTargetApp() or (IsHistoryEmpty() and IsIgnoredKey(key))) {
        Send("{" key " down}")
        KeyWait(key)
        Send("{" key " up}")
        return
    }
    keys_history.Push({ key: key, event: "down", time: now })
    CheckHistory(now)

    ;长按检测
    SetTimer(() => CheckHistory(A_TickCount), -THRESHOLD + 1)

    KeyWait(key)
    ; keyup 时被打断时清空
    now := A_TickCount
    if (!IsTargetApp()) {
        ResetHistory()
        return
    } else {
        if (IsInHistory(key, "down")) {
            keys_history.Push({ key: key, event: "up", time: now })
        }
    }
    CheckHistory(now)
    return
}

keys := "abcdefghijklmnopqrstuvwxyz0123456789"

for i, char in StrSplit(keys) {
    currentChar := char
    Hotkey("$" currentChar, ((k) => (*) => HandleKey(k))(currentChar))
}

#HotIf