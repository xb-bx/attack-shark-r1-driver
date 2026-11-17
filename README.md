# Linux driver for Attack Shark R1
Capabilities:
- [X] Get battery charge
- [X] Set current polling rate
- [X] Remap keys
- [X] Set DPI
- [X] Set sleep time
- [X] Set Deepsleep time
- [X] Set key response time
- [X] Ripple control
- [X] Angle Snap
- [ ] Macros
# Build requirements
    - odin
    - make
    - libusb
# Build instructions
```sh
make
```

# Installation
## Arch-based distros
```sh
git clone https://github.com/xb-bx/attack-shark-r1-driver --recursive
cd attack-shark-r1-driver
makepkg -si
```
## Other
```sh
git clone https://github.com/xb-bx/attack-shark-r1-driver --recursive
sudo make install
```

# Configuration

Driver searches for config file by checking following paths:
- $XDG_CONFIG_HOME/attack-shark-r1.ini
- $HOME/.config/attack-shark-r1.ini
- /etc/attack-shark-r1.ini

## Default configuration [attack-shark-r1.ini](https://github.com/xb-bx/attack-shark-r1-driver/blob/master/attack-shark-r1.ini)

## Button remapping

Remappable buttons: `left`, `right`, `middle`, `forward`, `backward`, `dpi`.

Actions:
- Mouse: `left`, `right`, `middle`, `backward`, `forward`, `double_click`,
  `fire_button`, `scroll_up`, `scroll_down`, `scroll_left`, `scroll_right`,
  `dpi_cycle`, `dpi_up`, `dpi_down`, `off`
- Multimedia: `media_player`, `play_pause`, `stop`, `previous_track`,
  `next_track`, `volume_up`, `volume_down`, `mute`
- Browser/application: `calculator`, `email`, `browser_forward`,
  `browser_backward`, `browser_stop`, `browser_my_computer`, `browser_refresh`,
  `browser_home`, `browser_search`
- Keyboard combinations: `ctrl+c`, `ctrl+v`, `ctrl+shift+s`, `alt+tab`,
  `alt+f4`, `win+e`, `win+l`, etc. (modifiers: `ctrl`, `shift`, `alt`, `win`;
  keys: `a`-`z`, `0`-`9`, `f1`-`f12`, `tab`, `esc`, `enter`, `space`,
  `backspace`, `delete`, `minus`, `equal`)

In the config file (optional):

```ini
remap_forward  = browser_forward
remap_backward = ctrl+c
remap_dpi      = dpi_cycle
```

Or from the command line:

```sh
sudo attack-shark-r1-driver -remap:forward=ctrl+c -remap:backward=browser_backward
```
