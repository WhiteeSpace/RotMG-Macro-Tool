**ROTMG MACRO TOOL - AUTOHOTKEY v2**
================================

```1. Install AutoHotkey v2 from https://www.autohotkey.com/
2. Run MacroMenu.ahk.
3. Press F1 to open or hide the settings menu.
4. Click a Hotkey field and press the key you want to assign.
5. Edit the associated message.
6. Click "Save settings".```

Text macros automatically send:

    Enter -> configured message -> Enter

The default hotkeys are F2 through F12.
The menu hotkey defaults to F1 and can also be changed in the menu.

Default actions:

    F2  taken?
    F3  /who
    F4  /server
    F5  ready
    F6  He lives and reigns and conquers the world
    F7  hp
    F8  /teleport <username>
    F9  Screenshot the RotMG Exalt.exe window (hotkey can be changed)
    F10 Auto-emote: send "t&" every 2 seconds
    F11 Quick-emote: send "t&" once
    F12 Emergency Healing: press the configured healing key 10 times

Replace <username> with the name of the player you want to teleport to.

Screenshots are saved as PNG files in the "Screenshots" folder next to the
script. The folder is created automatically.

AUTO-EMOTE
----------

Press its configured hotkey once to enable it. It sends the configured key
sequence every 2 seconds while RotMG Exalt is the active window. Press the
same hotkey again to disable it. Its held-key combination lasts approximately
60 milliseconds so the game can reliably detect it.

QUICK-EMOTE
-----------

Press its configured hotkey to send the configured key sequence once.
Quick-emote remains near-instantaneous.

The default emote combination is "t&" and can be edited independently for
both emote modes. The first key is held down while the following key is
pressed, then the first key is released last. The "&" or "1" character uses
the physical &/1 key (scan code SC002). The complete combination is
sent as one near-instantaneous input without an added delay.

EMERGENCY HEALING
-----------------

Press its configured hotkey to press the healing key 10 times in a
very fast burst. Each press is separated by only a few milliseconds so the
game can detect all 10 inputs. The action can be spammed: every activation
queues another complete 10-press burst, even while a previous burst is
running. The activation hotkey and healing key are both editable. The
default activation hotkey is F12 and the default healing key is F. The
healing key uses the same direct key-capture field as the other hotkeys.
It can also use XButton1, XButton2, or Space.

Settings are saved in MacroMenu.ini next to the script.
