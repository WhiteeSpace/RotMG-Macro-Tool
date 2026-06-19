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
global ToolToggleHotkey := "F12"
global ToolEnabled := true
global IsEditingHotkeys := false
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
global ActiveKeyCaptureControl := 0
global MenuHotkeyControl
global ToolToggleHotkeyControl
global ToolToggleButton
global NeutralFocusControl
global StatusText
global MacroGui

SetKeyDelay(30, 30)

LoadConfiguration()
BuildGui()
ApplyHotkeys()
OnMessage(0x0100, CaptureKeyboardKey) ; WM_KEYDOWN
OnMessage(0x0104, CaptureKeyboardKey) ; WM_SYSKEYDOWN

A_TrayMenu.Delete()
A_TrayMenu.Add("Open macro settings", (*) => ShowMenu())
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Open macro settings"

LoadConfiguration() {
    global ConfigFile, MacroCount, MacroKeys, MacroTexts
    global MenuHotkey, ToolToggleHotkey

    UpgradeDefaultConfiguration()
    MenuHotkey := IniRead(ConfigFile, "Settings", "MenuHotkey", "F1")
    ToolToggleHotkey := IniRead(
        ConfigFile,
        "Settings",
        "ToolToggleHotkey",
        "Pause"
    )
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
    global MacroKeys, MacroTexts, MenuHotkey, ToolToggleHotkey
    global MenuHotkeyControl, ToolToggleHotkeyControl
    global KeyControls, TextControls, ToolToggleButton
    global NeutralFocusControl, StatusText

    MacroGui := Gui("+AlwaysOnTop", "RotMG Macro Tool")
    MacroGui.SetFont("s10", "Segoe UI")
    MacroGui.MarginX := 18
    MacroGui.MarginY := 16

    ; Create the neutral focus target before every editable control. Windows
    ; will therefore focus it on the very first frame instead of briefly
    ; selecting Open menu hotkey and moving the focus afterward.
    NeutralFocusControl := MacroGui.AddButton(
        "x0 y0 w1 h1",
        ""
    )

    MacroGui.AddText("xm w170 h25 0x200", "Open menu hotkey")
    MenuHotkeyControl := AddKeyCapture(
        MacroGui,
        "x+10 yp w120",
        MenuHotkey
    )

    MacroGui.AddText("xm y+8 w170 h25 0x200", "Enable / disable hotkey")
    ToolToggleHotkeyControl := AddKeyCapture(
        MacroGui,
        "x+10 yp w120",
        ToolToggleHotkey
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
    ToolToggleButton := MacroGui.AddButton(
        "x+10 w140 h32",
        "Disable tool"
    )
    closeButton := MacroGui.AddButton("x+10 w140 h32", "Hide")

    StatusText := MacroGui.AddText(
        "xm y+14 w600 c555555",
        "Auto-emote repeats every 2 seconds. Press its hotkey again to stop it."
    )

    saveButton.OnEvent("Click", SaveConfiguration)
    ToolToggleButton.OnEvent("Click", ToggleTool)
    closeButton.OnEvent("Click", HideMenu)
    MacroGui.OnEvent("Close", HideMenu)
    MacroGui.OnEvent("Escape", HideMenu)
}

AddKeyCapture(guiObject, options, currentKey) {
    global KeyCaptureControls

    control := guiObject.AddEdit(options " ReadOnly Center", currentKey)
    KeyCaptureControls[control.Hwnd] := control
    control.OnEvent("Focus", SetActiveKeyCapture.Bind(control))
    return control
}

SetActiveKeyCapture(control, *) {
    global ActiveKeyCaptureControl
    ActiveKeyCaptureControl := control
}

CaptureKeyboardKey(wParam, lParam, msg, hwnd) {
    global MacroGui, ActiveKeyCaptureControl

    if !DllCall("IsWindowVisible", "Ptr", MacroGui.Hwnd)
        return

    if !IsObject(ActiveKeyCaptureControl)
        return

    keyName := GetKeyName("vk" Format("{:02X}", wParam))

    if (keyName = "Backspace" || keyName = "Delete") {
        ActiveKeyCaptureControl.Value := ""
        return 1
    }

    if (keyName = "Shift" || keyName = "Ctrl"
        || keyName = "Alt" || keyName = "LWin" || keyName = "RWin")
        return 1

    modifiers := ""
    if GetKeyState("Ctrl")
        modifiers .= "^"
    if GetKeyState("Alt")
        modifiers .= "!"
    if GetKeyState("Shift")
        modifiers .= "+"
    if GetKeyState("LWin") || GetKeyState("RWin")
        modifiers .= "#"

    ActiveKeyCaptureControl.Value := modifiers keyName
    return 1
}

CaptureSideButton(buttonName, *) {
    global MacroGui, ActiveKeyCaptureControl

    if !WinActive("ahk_id " MacroGui.Hwnd)
        return

    if !IsObject(ActiveKeyCaptureControl)
        return

    ActiveKeyCaptureControl.Value := buttonName
}

ToggleMenu(*) {
    global MacroGui

    if DllCall("IsWindowVisible", "Ptr", MacroGui.Hwnd)
        HideMenu()
    else
        ShowMenu()
}

ShowMenu(*) {
    global MacroGui, IsEditingHotkeys
    global ActiveKeyCaptureControl, NeutralFocusControl

    ; While editing, no old hotkey can fire or interfere with assigning the
    ; same key again. Unsaved field changes therefore remain purely visual.
    IsEditingHotkeys := true
    DeactivateAllHotkeys()
    Hotkey("XButton1", CaptureSideButton.Bind("XButton1"), "On")
    Hotkey("XButton2", CaptureSideButton.Bind("XButton2"), "On")
    ActiveKeyCaptureControl := 0
    MacroGui.Show("AutoSize Center")
    NeutralFocusControl.Focus()
    ActiveKeyCaptureControl := 0
}

HideMenu(*) {
    global MacroGui, IsEditingHotkeys, ActiveKeyCaptureControl

    try Hotkey("XButton1", "Off")
    try Hotkey("XButton2", "Off")
    MacroGui.Hide()
    IsEditingHotkeys := false
    ActiveKeyCaptureControl := 0
    ApplyHotkeys()
}

ToggleTool(*) {
    global ToolEnabled, ToolToggleButton, IsEditingHotkeys
    global AutoEmoteEnabled, EmergencyHealingQueuedPresses

    ToolEnabled := !ToolEnabled

    if ToolEnabled {
        ToolToggleButton.Text := "Disable tool"
        ShowStatus("Tool enabled. All configured hotkeys are active.")
    } else {
        ToolToggleButton.Text := "Enable tool"
        AutoEmoteEnabled := false
        EmergencyHealingQueuedPresses := 0
        SetTimer(SendAutomaticEmote, 0)
        ShowStatus("Tool disabled. Only the menu hotkey will remain active.")
    }

    ; Immediately rebuild the active hotkeys when toggled outside the
    ; settings window. While editing, HideMenu will apply the correct state.
    if !IsEditingHotkeys
        ApplyHotkeys()
}

SaveConfiguration(*) {
    global ConfigFile, MacroCount, MacroKeys, MacroTexts
    global MenuHotkey, ToolToggleHotkey
    global EmergencyHealingMacroIndex
    global MenuHotkeyControl, ToolToggleHotkeyControl
    global KeyControls, TextControls

    newKeys := []
    newTexts := []
    usedKeys := Map()
    usedKeys.CaseSense := false
    newMenuHotkey := Trim(MenuHotkeyControl.Value)
    newToolToggleHotkey := Trim(ToolToggleHotkeyControl.Value)

    if (newMenuHotkey = "") {
        ShowStatus("The menu does not have a hotkey.", true)
        return
    }

    if (newToolToggleHotkey = "") {
        ShowStatus("Enable / disable does not have a hotkey.", true)
        return
    }

    usedKeys[newMenuHotkey] := true

    if usedKeys.Has(newToolToggleHotkey) {
        ShowStatus(
            "The menu and enable / disable hotkeys must be different.",
            true
        )
        return
    }
    usedKeys[newToolToggleHotkey] := true

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
    oldToolToggleHotkey := ToolToggleHotkey
    MacroKeys := newKeys
    MacroTexts := newTexts
    MenuHotkey := newMenuHotkey
    ToolToggleHotkey := newToolToggleHotkey

    try {
        ApplyHotkeys()

        IniWrite(MenuHotkey, ConfigFile, "Settings", "MenuHotkey")
        IniWrite(
            ToolToggleHotkey,
            ConfigFile,
            "Settings",
            "ToolToggleHotkey"
        )
        Loop MacroCount {
            IniWrite(MacroKeys[A_Index], ConfigFile, "Macro" A_Index, "Key")
            IniWrite(MacroTexts[A_Index], ConfigFile, "Macro" A_Index, "Text")
        }

        ShowStatus("Settings saved.", false)
    } catch Error as err {
        MacroKeys := oldKeys
        MacroTexts := oldTexts
        MenuHotkey := oldMenuHotkey
        ToolToggleHotkey := oldToolToggleHotkey
        ApplyHotkeys()
        ShowStatus("Could not enable a hotkey: " err.Message, true)
    }
}

ApplyHotkeys() {
    global MacroCount, MacroKeys, MenuHotkey, ToolToggleHotkey
    global ActiveHotkeys
    global EmergencyHealingMacroIndex
    global ToolEnabled, IsEditingHotkeys

    DeactivateAllHotkeys()

    if IsEditingHotkeys
        return

    ; The menu hotkey remains available even while the tool is disabled.
    menuCallback := ToggleMenu
    Hotkey(MenuHotkey, menuCallback, "On")
    ActiveHotkeys[MenuHotkey] := menuCallback

    toggleCallback := ToggleTool
    Hotkey(ToolToggleHotkey, toggleCallback, "On")
    ActiveHotkeys[ToolToggleHotkey] := toggleCallback

    if !ToolEnabled
        return

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

DeactivateAllHotkeys() {
    global ActiveHotkeys

    for keyName, callback in ActiveHotkeys {
        try Hotkey(keyName, callback, "Off")
    }
    ActiveHotkeys.Clear()
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
