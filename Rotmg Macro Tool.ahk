#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreads 50
#MaxThreadsPerHotkey 10

; Configurable macro menu for AutoHotkey v2.
; F1 opens or hides the menu by default; the hotkey is configurable.
; Text macros send: Enter, the configured text, then Enter.

global ConfigFile := A_ScriptDir "\MacroMenu.ini"
global MacroCount := 11
global ScreenshotMacroIndex := 8
global AutoEmoteMacroIndex := 9
global QuickEmoteMacroIndex := 10
global EmergencyHealingMacroIndex := 11
global MenuHotkey := "F1"
global AutoEmoteEnabled := false
global AutoEmoteInterval := 2000
global EmergencyHealingQueuedPresses := 0
global EmergencyHealingBusy := false
global MacroKeys := []
global MacroTexts := []
global ActiveHotkeys := Map()
global KeyControls := []
global TextControls := []
global KeyCaptureControls := Map()
global MenuHotkeyControl
global StatusText
global MacroGui

SetKeyDelay(30, 30)

LoadConfiguration()
BuildGui()
ApplyHotkeys()
OnMessage(0x020B, CaptureMouseButton) ; WM_XBUTTONDOWN

A_TrayMenu.Delete()
A_TrayMenu.Add("Open macro settings", (*) => ShowMenu())
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Open macro settings"

LoadConfiguration() {
    global ConfigFile, MacroCount, MacroKeys, MacroTexts, MenuHotkey

    UpgradeDefaultConfiguration()
    MenuHotkey := IniRead(ConfigFile, "Settings", "MenuHotkey", "F1")
    defaultTexts := [
        "taken?",
        "/who",
        "/server",
        "ready",
        "He lives and reigns and conquers the world",
        "hp",
        "/teleport <username>",
        "Screenshot RotMG Exalt window",
        "t&",
        "t&",
        "f"
    ]

    Loop MacroCount {
        defaultKey := "F" (A_Index + 1)
        MacroKeys.Push(IniRead(
            ConfigFile,
            "Macro" A_Index,
            "Key",
            defaultKey
        ))
        MacroTexts.Push(IniRead(
            ConfigFile,
            "Macro" A_Index,
            "Text",
            defaultTexts[A_Index]
        ))
    }
}

UpgradeDefaultConfiguration() {
    global ConfigFile

    configVersion := Integer(
        IniRead(ConfigFile, "Settings", "ConfigVersion", "0")
    )

    if (configVersion >= 3)
        return

    ; Apply the new requested message order once while preserving all
    ; configured hotkeys, including the menu and screenshot hotkeys.
    newMessages := [
        "taken?",
        "/who",
        "/server",
        "ready",
        "He lives and reigns and conquers the world",
        "hp",
        "/teleport <username>"
    ]

    Loop newMessages.Length
        IniWrite(newMessages[A_Index], ConfigFile, "Macro" A_Index, "Text")

    IniWrite("t&", ConfigFile, "Macro9", "Text")
    IniWrite("t&", ConfigFile, "Macro10", "Text")
    IniWrite("F12", ConfigFile, "Macro11", "Key")
    IniWrite("f", ConfigFile, "Macro11", "Text")
    IniWrite("3", ConfigFile, "Settings", "ConfigVersion")
}

BuildGui() {
    global MacroGui, MacroCount, ScreenshotMacroIndex
    global AutoEmoteMacroIndex, QuickEmoteMacroIndex
    global EmergencyHealingMacroIndex
    global MacroKeys, MacroTexts, MenuHotkey, MenuHotkeyControl
    global KeyControls, TextControls, StatusText

    MacroGui := Gui("+AlwaysOnTop", "RotMG Macro Tool")
    MacroGui.SetFont("s10", "Segoe UI")
    MacroGui.MarginX := 18
    MacroGui.MarginY := 16

    MacroGui.AddText("xm w170 h25 0x200", "Open menu hotkey")
    MenuHotkeyControl := AddKeyCapture(
        MacroGui,
        "x+10 yp w120",
        MenuHotkey
    )

    MacroGui.AddText("xm w140 Center", "Macro")
    MacroGui.AddText("x+10 w120 Center", "Hotkey")
    MacroGui.AddText("x+10 w320 Center", "Message / action key")

    Loop MacroCount {
        row := A_Index
        rowLabel := row
        if (row = ScreenshotMacroIndex)
            rowLabel := "Screenshot"
        else if (row = AutoEmoteMacroIndex)
            rowLabel := "Auto Emote"
        else if (row = QuickEmoteMacroIndex)
            rowLabel := "Quick Emote"
        else if (row = EmergencyHealingMacroIndex)
            rowLabel := "Emergency Healing"

        MacroGui.AddText("xm y+10 w140 h25 Center 0x200", rowLabel)

        keyControl := AddKeyCapture(
            MacroGui,
            "x+10 yp w120",
            MacroKeys[row]
        )
        KeyControls.Push(keyControl)

        options := "x+10 yp w320"
        if (row = ScreenshotMacroIndex)
            options .= " ReadOnly"

        if (row = EmergencyHealingMacroIndex)
            textControl := AddKeyCapture(MacroGui, options, MacroTexts[row])
        else
            textControl := MacroGui.AddEdit(options, MacroTexts[row])

        TextControls.Push(textControl)
    }

    saveButton := MacroGui.AddButton(
        "xm y+18 w140 h32 Default",
        "Save settings"
    )
    closeButton := MacroGui.AddButton("x+10 w140 h32", "Hide")

    StatusText := MacroGui.AddText(
        "xm y+14 w600 c555555",
        "Auto-emote repeats every 2 seconds. Press its hotkey again to stop it."
    )

    saveButton.OnEvent("Click", SaveConfiguration)
    closeButton.OnEvent("Click", (*) => MacroGui.Hide())
    MacroGui.OnEvent("Close", (*) => MacroGui.Hide())
    MacroGui.OnEvent("Escape", (*) => MacroGui.Hide())
}

AddKeyCapture(guiObject, options, currentKey) {
    global KeyCaptureControls

    control := guiObject.AddHotkey(options, currentKey)
    KeyCaptureControls[control.Hwnd] := control
    return control
}

CaptureMouseButton(wParam, lParam, msg, hwnd) {
    global MacroGui, KeyCaptureControls

    if !WinActive("ahk_id " MacroGui.Hwnd)
        return

    ; Assign the side mouse button to the field physically under the cursor,
    ; never to a previously focused field such as Open menu hotkey.
    MouseGetPos(, , , &controlHwnd, 2)
    if !KeyCaptureControls.Has(controlHwnd)
        return

    buttonNumber := (wParam >> 16) & 0xFFFF
    if (buttonNumber = 1)
        KeyCaptureControls[controlHwnd].Value := "XButton1"
    else if (buttonNumber = 2)
        KeyCaptureControls[controlHwnd].Value := "XButton2"

    return 1
}

ToggleMenu(*) {
    global MacroGui

    if WinExist("ahk_id " MacroGui.Hwnd)
        MacroGui.Hide()
    else
        ShowMenu()
}

ShowMenu(*) {
    global MacroGui
    MacroGui.Show("AutoSize Center")
}

SaveConfiguration(*) {
    global ConfigFile, MacroCount, MacroKeys, MacroTexts, MenuHotkey
    global EmergencyHealingMacroIndex
    global MenuHotkeyControl, KeyControls, TextControls

    newKeys := []
    newTexts := []
    usedKeys := Map()
    usedKeys.CaseSense := false
    newMenuHotkey := Trim(MenuHotkeyControl.Value)

    if (newMenuHotkey = "") {
        ShowStatus("The menu does not have a hotkey.", true)
        return
    }

    usedKeys[newMenuHotkey] := true

    Loop MacroCount {
        keyName := Trim(KeyControls[A_Index].Value)
        textValue := TextControls[A_Index].Value

        if (keyName = "") {
            ShowStatus("Macro " A_Index " does not have a hotkey.", true)
            return
        }

        if usedKeys.Has(keyName) {
            ShowStatus(
                "Hotkey " keyName " is assigned more than once.",
                true
            )
            return
        }

        usedKeys[keyName] := true
        newKeys.Push(keyName)
        newTexts.Push(textValue)
    }

    oldKeys := MacroKeys.Clone()
    oldTexts := MacroTexts.Clone()
    oldMenuHotkey := MenuHotkey
    MacroKeys := newKeys
    MacroTexts := newTexts
    MenuHotkey := newMenuHotkey

    try {
        ApplyHotkeys()

        IniWrite(MenuHotkey, ConfigFile, "Settings", "MenuHotkey")
        Loop MacroCount {
            IniWrite(MacroKeys[A_Index], ConfigFile, "Macro" A_Index, "Key")
            IniWrite(MacroTexts[A_Index], ConfigFile, "Macro" A_Index, "Text")
        }

        ShowStatus("Settings saved.", false)
    } catch Error as err {
        MacroKeys := oldKeys
        MacroTexts := oldTexts
        MenuHotkey := oldMenuHotkey
        ApplyHotkeys()
        ShowStatus("Could not enable a hotkey: " err.Message, true)
    }
}

ApplyHotkeys() {
    global MacroCount, MacroKeys, MenuHotkey, ActiveHotkeys
    global EmergencyHealingMacroIndex

    for keyName, callback in ActiveHotkeys {
        try Hotkey(keyName, callback, "Off")
    }
    ActiveHotkeys.Clear()

    menuCallback := ToggleMenu
    Hotkey(MenuHotkey, menuCallback, "On")
    ActiveHotkeys[MenuHotkey] := menuCallback

    Loop MacroCount {
        index := A_Index
        keyName := MacroKeys[index]
        callback := RunMacro.Bind(index)

        if (index = EmergencyHealingMacroIndex)
            Hotkey(keyName, callback, "On B0 T10")
        else
            Hotkey(keyName, callback, "On")

        ActiveHotkeys[keyName] := callback
    }
}

RunMacro(index, *) {
    global ScreenshotMacroIndex, AutoEmoteMacroIndex, QuickEmoteMacroIndex
    global EmergencyHealingMacroIndex
    global MacroTexts

    if (index = ScreenshotMacroIndex) {
        CaptureRotMGScreenshot()
        return
    }

    if (index = AutoEmoteMacroIndex) {
        ToggleAutoEmote()
        return
    }

    if (index = QuickEmoteMacroIndex) {
        SendEmote(MacroTexts[index], true, false)
        return
    }

    if (index = EmergencyHealingMacroIndex) {
        SendEmergencyHealing(MacroTexts[index])
        return
    }

    SendEvent("{Enter}")
    Sleep(80)
    SendText(MacroTexts[index])
    Sleep(50)
    SendEvent("{Enter}")
}

SendEmergencyHealing(healKey) {
    global EmergencyHealingQueuedPresses, EmergencyHealingBusy

    healKey := Trim(healKey)

    if !WinActive("ahk_exe RotMG Exalt.exe") {
        TrayTip(
            "Open or select the RotMG Exalt window first.",
            "Emergency Healing not sent",
            "Iconx"
        )
        return
    }

    if (healKey = "") {
        TrayTip(
            "Configure a healing key in the menu.",
            "Emergency Healing not sent",
            "Iconx"
        )
        return
    }

    if (healKey = "&" || healKey = "1")
        healKey := "sc002"

    ; Every activation queues another full burst, including activations made
    ; while a previous burst is still being sent.
    EmergencyHealingQueuedPresses += 10

    if EmergencyHealingBusy
        return

    EmergencyHealingBusy := true

    try {
        while (EmergencyHealingQueuedPresses > 0) {
            SendInput("{" healKey " down}")
            Sleep(3)
            SendInput("{" healKey " up}")
            Sleep(3)
            EmergencyHealingQueuedPresses -= 1
        }
    } finally {
        EmergencyHealingBusy := false
    }
}

ToggleAutoEmote() {
    global AutoEmoteEnabled, AutoEmoteInterval

    AutoEmoteEnabled := !AutoEmoteEnabled

    if AutoEmoteEnabled {
        SendAutomaticEmote()
        SetTimer(SendAutomaticEmote, AutoEmoteInterval)
        TrayTip(
            "Press the same hotkey again to stop it.",
            "Auto-emote enabled",
            "Iconi"
        )
    } else {
        SetTimer(SendAutomaticEmote, 0)
        TrayTip("The repeating emote has stopped.", "Auto-emote disabled", "Iconi")
    }
}

SendAutomaticEmote() {
    global AutoEmoteEnabled, AutoEmoteMacroIndex, MacroTexts

    if AutoEmoteEnabled
        SendEmote(MacroTexts[AutoEmoteMacroIndex], false, true)
}

SendEmote(sequence, warnIfInactive := false, reliableTiming := false) {
    if !WinActive("ahk_exe RotMG Exalt.exe") {
        if warnIfInactive {
            TrayTip(
                "Open or select the RotMG Exalt window first.",
                "Quick-emote not sent",
                "Iconx"
            )
        }
        return
    }

    keys := []

    Loop Parse sequence {
        key := A_LoopField

        if (key = " " || key = "+" || key = "-")
            continue

        ; SC002 is the physical AZERTY "&/1" key.
        if (key = "&" || key = "1")
            key := "sc002"

        keys.Push(key)
    }

    if (keys.Length = 0)
        return

    if reliableTiming {
        ; Auto-emote uses a short but detectable held-key combination.
        ; T stays down during the complete AZERTY &/1 press.
        SendInput("{" keys[1] " down}")
        Sleep(20)

        Loop keys.Length - 1 {
            key := keys[A_Index + 1]
            SendInput("{" key " down}")
            Sleep(25)
            SendInput("{" key " up}")
            Sleep(15)
        }

        SendInput("{" keys[1] " up}")
        return
    }

    ; Send the complete held-key combination as one near-instantaneous input.
    ; T remains logically held while the AZERTY &/1 key is pressed and
    ; released, then T is released last.
    inputSequence := "{" keys[1] " down}"

    Loop keys.Length - 1 {
        key := keys[A_Index + 1]
        inputSequence .= "{" key " down}{" key " up}"
    }

    inputSequence .= "{" keys[1] " up}"
    SendInput(inputSequence)
}

CaptureRotMGScreenshot() {
    scriptPath := A_ScriptDir "\CaptureRotMG.ps1"
    outputDirectory := A_ScriptDir "\Screenshots"
    quote := Chr(34)

    if !FileExist(scriptPath) {
        TrayTip(
            "CaptureRotMG.ps1 could not be found.",
            "Screenshot failed",
            "Iconx"
        )
        return
    }

    command := "powershell.exe -NoProfile -ExecutionPolicy Bypass -File "
        . quote scriptPath quote
        . " -OutputDirectory "
        . quote outputDirectory quote

    exitCode := RunWait(command, A_ScriptDir, "Hide")

    if (exitCode = 0) {
        TrayTip(
            "Screenshot saved in the Screenshots folder.",
            "Screenshot captured",
            "Iconi"
        )
    } else {
        TrayTip(
            "RotMG Exalt.exe was not found or could not be captured.",
            "Screenshot failed",
            "Iconx"
        )
    }
}

ShowStatus(message, isError := false) {
    global StatusText
    StatusText.SetFont("c" (isError ? "B00020" : "177245"))
    StatusText.Text := message
}
