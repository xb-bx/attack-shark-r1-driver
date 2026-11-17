#+feature dynamic-literals
package attackshark
import "core:fmt"
import "core:strings"
import "core:strconv"
import "libusb"

// Button remapping via vendor report 0x08 (59 bytes).
//
// Layout (reverse engineered from the official Attack Shark software):
//   byte 0      : 0x08 (report id)
//   byte 1      : 0x3b (report length)
//   byte 2      : 0x01
//   bytes 3..56 : 18 groups, 3 bytes each: {action, p1, p2}
//                 keyboard actions use {0x11, modifier_mask, hid_keycode}
//   bytes 57..58: checksum, big-endian sum of bytes 3..56
//
// Physical buttons map to groups: left=1 right=2 middle=3 dpi=4 forward=7 backward=8.
// Groups 5,6 are the hardware dpi +/- slots and 9..18 are unused on the R1; they
// are always written with the factory defaults.
REMAP_REPORT_LEN :: 59

Remap_Action :: enum u8 {
    Off                 = 0x01,
    Left                = 0x02,
    Right               = 0x03,
    Middle              = 0x04,
    Backward            = 0x05,
    Forward             = 0x06,
    Double_Click        = 0x07,
    Fire_Button         = 0x08,
    Scroll_Up           = 0x09,
    Scroll_Down         = 0x0a,
    Scroll_Left         = 0x0b,
    Scroll_Right        = 0x0c,
    DPI_Cycle           = 0x0d,
    DPI_Up              = 0x0e,
    DPI_Down            = 0x0f,
    Keyboard_Key        = 0x11,
    Media_Player        = 0x15,
    Previous_Track      = 0x16,
    Next_Track          = 0x17,
    Play_Pause          = 0x18,
    Stop                = 0x19,
    Mute                = 0x1a,
    Volume_Up           = 0x1b,
    Volume_Down         = 0x1c,
    Calculator          = 0x1d,
    Email               = 0x1e,
    Browser_Forward     = 0x20,
    Browser_Backward    = 0x21,
    Browser_Stop        = 0x22,
    Browser_My_Computer = 0x23,
    Browser_Refresh     = 0x24,
    Browser_Home        = 0x25,
    Browser_Search      = 0x26,
}

// HID keyboard modifier mask (byte 1 of a keyboard action payload).
Remap_Modifier :: enum u8 {
    Ctrl  = 0x01,
    Shift = 0x02,
    Alt   = 0x04,
    Win   = 0x08,
}

Remap_Button :: enum u8 {
    Left,
    Right,
    Middle,
    Forward,
    Backward,
    DPI,
}

REMAP_BUTTON_COUNT :: 6

remap_button_names := [REMAP_BUTTON_COUNT]string{"left", "right", "middle", "forward", "backward", "dpi"}

Remap_Assignment :: struct {
    action:    Remap_Action,
    modifiers: u8, // HID modifier mask, only for .Keyboard_Key
    keycode:   u8, // HID usage id,      only for .Keyboard_Key
}

// group index (1-based) of every remappable button
remap_button_groups := [REMAP_BUTTON_COUNT]u8{1, 2, 3, 7, 8, 4}

remap_button_group :: proc(b: Remap_Button) -> u8 {
    return remap_button_groups[int(b)]
}

// Factory defaults as written by the official software.
remap_baseline := [REMAP_REPORT_LEN]u8 {
    0x08, 0x3b, 0x01,
    // g1    g2    g3    g4    g5    g6    g7    g8
    0x02, 0x00, 0x00,
    0x03, 0x00, 0x00,
    0x04, 0x00, 0x00,
    0x0d, 0x00, 0x00,
    0x0e, 0x00, 0x00,
    0x0f, 0x00, 0x00,
    0x06, 0x00, 0x00,
    0x05, 0x00, 0x00,
    // g9    g10   g11   g12   g13   g14   g15   g16   g17   g18
    0x3c, 0x00, 0x00,
    0x01, 0x00, 0x00,
    0x01, 0x00, 0x00,
    0x01, 0x00, 0x00,
    0x01, 0x00, 0x00,
    0x01, 0x00, 0x00,
    0x01, 0x00, 0x00,
    0x01, 0x00, 0x00,
    0x0a, 0x00, 0x00,
    0x09, 0x00, 0x00,
    // checksum placeholder
    0x00, 0x94,
}

set_button_remap :: proc(dev_handle: libusb.Device_Handle, remaps: [REMAP_BUTTON_COUNT]Remap_Assignment, remaps_set: [REMAP_BUTTON_COUNT]bool) -> libusb.Error {
    t := i32(0)
    payload := remap_baseline
    for b in 0 ..< REMAP_BUTTON_COUNT {
        if !remaps_set[b] do continue
        group := remap_button_group(Remap_Button(b))
        offset := 3 + int(group - 1) * 3
        payload[offset] = u8(remaps[b].action)
        payload[offset + 1] = remaps[b].modifiers
        payload[offset + 2] = remaps[b].keycode
    }

    checksum := u16(0)
    for b in payload[3:57] {
        checksum += u16(b)
    }
    (transmute(^u16be)&payload[57])^ = u16be(checksum)

    for {
        ctrl_transfer(dev_handle, 0x21, 0x9, 0x308, INTERFACE, payload[:]) or_return
        if !wired {
            buf := [5]u8{}
            interrupt_transfer(dev_handle, 0x83, buf[:]) or_return
            if buf[2] == 0x50 do break
        } else do break
    }
    return nil
}

remap_keycodes := map[string]u8 {
    "a" = 0x04,  "b" = 0x05,  "c" = 0x06,  "d" = 0x07,  "e" = 0x08,
    "f" = 0x09,  "g" = 0x0a,  "h" = 0x0b,  "i" = 0x0c,  "j" = 0x0d,
    "k" = 0x0e,  "l" = 0x0f,  "m" = 0x10,  "n" = 0x11,  "o" = 0x12,
    "p" = 0x13,  "q" = 0x14,  "r" = 0x15,  "s" = 0x16,  "t" = 0x17,
    "u" = 0x18,  "v" = 0x19,  "w" = 0x1a,  "x" = 0x1b,  "y" = 0x1c,
    "z" = 0x1d,
    "1" = 0x1e,  "2" = 0x1f,  "3" = 0x20,  "4" = 0x21,  "5" = 0x22,
    "6" = 0x23,  "7" = 0x24,  "8" = 0x25,  "9" = 0x26,  "0" = 0x27,
    "enter" = 0x28, "esc" = 0x29, "backspace" = 0x2a, "tab" = 0x2b,
    "space" = 0x2c, "minus" = 0x2d, "equal" = 0x2e,
    "f1" = 0x3a, "f2" = 0x3b, "f3" = 0x3c, "f4" = 0x3d,
    "f5" = 0x3e, "f6" = 0x3f, "f7" = 0x40, "f8" = 0x41,
    "f9" = 0x42, "f10" = 0x43, "f11" = 0x44, "f12" = 0x45,
    "delete" = 0x4c,
}

remap_modifier_bits :: proc(mod: string) -> (u8, bool) {
    switch mod {
    case "ctrl":  return u8(Remap_Modifier.Ctrl),  true
    case "shift": return u8(Remap_Modifier.Shift), true
    case "alt":   return u8(Remap_Modifier.Alt),   true
    case "win":   return u8(Remap_Modifier.Win),   true
    }
    return 0, false
}

// Parses a remap action name. Simple actions are matched against the wire
// action catalog; "ctrl+c", "alt+tab", "win+shift+s" style values become
// keyboard key actions.
parse_remap_value :: proc(value: string) -> (Remap_Assignment, bool) {
    simple := map[string]Remap_Action {
        "off"                 = .Off,
        "left"                = .Left,
        "right"               = .Right,
        "middle"              = .Middle,
        "backward"            = .Backward,
        "forward"             = .Forward,
        "double_click"        = .Double_Click,
        "fire_button"         = .Fire_Button,
        "scroll_up"           = .Scroll_Up,
        "scroll_down"         = .Scroll_Down,
        "scroll_left"         = .Scroll_Left,
        "scroll_right"        = .Scroll_Right,
        "dpi_cycle"           = .DPI_Cycle,
        "dpi_up"              = .DPI_Up,
        "dpi_down"            = .DPI_Down,
        "media_player"        = .Media_Player,
        "previous_track"      = .Previous_Track,
        "next_track"          = .Next_Track,
        "play_pause"          = .Play_Pause,
        "stop"                = .Stop,
        "mute"                = .Mute,
        "volume_up"           = .Volume_Up,
        "volume_down"         = .Volume_Down,
        "calculator"          = .Calculator,
        "email"               = .Email,
        "browser_forward"     = .Browser_Forward,
        "browser_backward"    = .Browser_Backward,
        "browser_stop"        = .Browser_Stop,
        "browser_my_computer" = .Browser_My_Computer,
        "browser_refresh"     = .Browser_Refresh,
        "browser_home"        = .Browser_Home,
        "browser_search"      = .Browser_Search,
    }

    norm := strings.to_lower(strings.trim(value, " \n\t"))
    norm, _ = strings.replace_all(norm, "-", "_")

    if action, ok := simple[norm]; ok {
        return Remap_Assignment{action = action}, true
    }

    // keyboard combination: mod+mod+key
    modifiers := u8(0)
    keycode := u8(0)
    rest := norm
    parts := strings.split(rest, "+")
    if len(parts) < 2 do return {}, false
    for part in parts[:len(parts) - 1] {
        bit, ok := remap_modifier_bits(strings.trim(part, " "))
        if !ok do return {}, false
        modifiers |= bit
    }
    key := strings.trim(parts[len(parts) - 1], " ")
    code, ok := remap_keycodes[key]
    if !ok do return {}, false
    keycode = code

    return Remap_Assignment{action = .Keyboard_Key, modifiers = modifiers, keycode = keycode}, true
}

parse_remap_button :: proc(name: string) -> (Remap_Button, bool) {
    switch strings.to_lower(strings.trim(name, " \n\t")) {
    case "left":     return .Left,     true
    case "right":    return .Right,    true
    case "middle":   return .Middle,   true
    case "forward":  return .Forward,  true
    case "backward": return .Backward, true
    case "dpi":      return .DPI,      true
    }
    return Remap_Button(0), false
}

remap_assignment_str :: proc(a: Remap_Assignment) -> string {
    if a.action != .Keyboard_Key do return fmt.tprint(a.action)
    mods := ""
    if a.modifiers & u8(Remap_Modifier.Ctrl)  != 0 do mods = strings.concatenate({mods, "ctrl+"})
    if a.modifiers & u8(Remap_Modifier.Shift) != 0 do mods = strings.concatenate({mods, "shift+"})
    if a.modifiers & u8(Remap_Modifier.Alt)   != 0 do mods = strings.concatenate({mods, "alt+"})
    if a.modifiers & u8(Remap_Modifier.Win)   != 0 do mods = strings.concatenate({mods, "win+"})
    return fmt.tprintf("%skey 0x%x", mods, a.keycode)
}
