# Button remap protocol (report 0x08)

Reference for the vendor button-remapping report of the Attack Shark R1,
reverse engineered from the official Windows software and verified on real
hardware (wired `1d57:fa61` and 2.4 GHz dongle `1d57:fa60`).

The transport is identical to the other configuration reports: a feature
report sent to interface 2 with

```
bmRequestType = 0x21   (host->device, class, interface)
bRequest      = 0x09   (SET_REPORT)
wValue        = 0x0308 (feature, report ID 0x08)
wIndex        = 2      (configuration interface)
```

The device acknowledges on the interrupt IN endpoint `0x83` with

```
03 10 50 00 08     (status 0x00 = success, report id 0x08)
```

## Report layout (59 bytes)

| Offset | Size | Meaning |
|--------|------|---------|
| 0      | 1    | `0x08` report ID |
| 1      | 1    | `0x3b` report length (59) |
| 2      | 1    | `0x01` |
| 3..56  | 54   | 18 button groups, 3 bytes each: `{action, p1, p2}` |
| 57..58 | 2    | checksum: big-endian 16-bit sum of bytes 3..56 |

## Button groups

Each group controls one physical button. The R1 uses 6 of the 18 groups;
the rest are written with their factory defaults:

| Group | Offset | Physical button (R1) | Factory action |
|-------|--------|----------------------|----------------|
| 1     | 3      | left                 | left click (`0x02`) |
| 2     | 6      | right                | right click (`0x03`) |
| 3     | 9      | middle               | middle click (`0x04`) |
| 4     | 12     | dpi                  | dpi cycle (`0x0d`) |
| 5     | 15     | (hardware dpi up)    | dpi up (`0x0e`) |
| 6     | 18     | (hardware dpi down)  | dpi down (`0x0f`) |
| 7     | 21     | forward              | forward (`0x06`) |
| 8     | 24     | backward             | backward (`0x05`) |
| 9..18 | 27..56 | unused on the R1     | see factory defaults |

Group 5/6 are not exposed by the R1 hardware; groups 9..18 belong to other
models in the same family (the official software supports 18 buttons).

## Action catalog

`{action, p1, p2}` per group. Simple actions ignore `p1`/`p2` (always 0).

| Action | ID | Meaning |
|--------|----|---------|
| Off              | `0x01` | do nothing |
| Left click       | `0x02` | |
| Right click      | `0x03` | |
| Middle click     | `0x04` | |
| Backward         | `0x05` | |
| Forward          | `0x06` | |
| Double click     | `0x07` | |
| Fire button      | `0x08` | rapid repeated left clicks while held |
| Scroll up        | `0x09` | |
| Scroll down      | `0x0a` | |
| Scroll left      | `0x0b` | |
| Scroll right     | `0x0c` | |
| DPI cycle        | `0x0d` | |
| DPI up           | `0x0e` | |
| DPI down         | `0x0f` | |
| Keyboard key     | `0x11` | `{0x11, modifier_mask, hid_keycode}` |
| Media player     | `0x15` | launch media player |
| Previous track   | `0x16` | |
| Next track       | `0x17` | |
| Play / pause     | `0x18` | |
| Stop             | `0x19` | |
| Mute             | `0x1a` | |
| Volume up        | `0x1b` | |
| Volume down      | `0x1c` | |
| Calculator       | `0x1d` | launch calculator |
| Email            | `0x1e` | launch email client |
| Browser forward  | `0x20` | |
| Browser backward | `0x21` | |
| Browser stop     | `0x22` | |
| My computer      | `0x23` | |
| Browser refresh  | `0x24` | |
| Browser home     | `0x25` | |
| Browser search   | `0x26` | |
| (reserved)       | `0x34` `0x35` `0x36` `0x3c` | seen in factory defaults of unused groups |

Actions `0x10`, `0x12`, `0x13`, `0x14`, `0x29`, `0x2b`-`0x2f` also exist in
the official software's catalog (macro shortcuts, tilt-wheel variants and
per-model special functions); they are not used by this driver.

### Keyboard actions

A keyboard action is `{0x11, modifier_mask, hid_keycode}` using the standard
USB HID modifier byte and usage IDs:

- modifiers: `ctrl 0x01`, `shift 0x02`, `alt 0x04`, `win/meta 0x08`
  (combinable, e.g. `ctrl+shift` = `0x03`)
- keycodes are the HID keyboard usage IDs (`a`=0x04 .. `z`=0x1d,
  `1`=0x1e .. `0`=0x27, `f1`=0x3a .. `f12`=0x45, `tab`=0x2b, etc.)

Examples from the official software: `ctrl+c` = `{0x11, 0x01, 0x06}`,
`alt+tab` = `{0x11, 0x04, 0x2b}`, `win+e` = `{0x11, 0x08, 0x08}`,
`alt+f4` = `{0x11, 0x04, 0x3d}`.

## Factory default report

```
08 3b 01
02 00 00  03 00 00  04 00 00  0d 00 00
0e 00 00  0f 00 00  06 00 00  05 00 00
3c 00 00  01 00 00  01 00 00  01 00 00
01 00 00  01 00 00  01 00 00  01 00 00
0a 00 00  09 00 00
00 94                          <- checksum 0x0094
```

## How this was obtained

The report structure was recovered from the official Attack Shark Windows
software (`AttackShark.exe`): the 0x08 report builder writes the header as
one word (`08 3b`), followed by `payload[2] = 1`, then copies 18 groups
× 3 bytes from per-button app state in stride-`0x1020` slots, mapping each
button's selected action through a `.rdata` lookup table (63 entries of
20 bytes: action key at +0, `{action, p1, p2}` at +4/+8/+12). The checksum
is the big-endian 16-bit sum over bytes 3..56, same scheme as the DPI
report. The R1 button→group mapping was confirmed by live testing (the UI
layout order `1,2,3,7,8,4` matches the X11 profile in the same software
family and the capture-validated X6 defaults).

Cross-references:

- `blak0p/attack-shark-linux` (MIT) — `docs/protocol-x6.md` documents the
  same transport and report family for the X6; its `0x08` remap report uses
  the same header/checksum/group encoding
- `iago-fragnan/attack-shark-x11-linux` — `docs/PROTOCOL.md` documents the
  DPI/polling/LED reports and the ACK format shared across the family
