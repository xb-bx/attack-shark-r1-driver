# Linux driver for Attack Shark R1
Capabilities:
- [X] Get battery charge
- [X] Set current polling rate
- [ ] Remap keys
- [ ] Set DPI
- [X] Set sleep time
- [X] Set Deepsleep time
- [X] Set key response time
- [ ] Ripple control
- [ ] Angle Snap
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
git clone https://github.com/xb-bx/attack-shark-r1-driver
cd attack-shark-r1-driver
makepkg -si
```
## Other
```sh
sudo make install
```

# Configuration

Driver searches for config file by checking following paths:
- $XDG_CONFIG_HOME/attack-shark-r1.ini
- $HOME/.config/attack-shark-r1.ini
- /etc/attack-shark-r1.ini

## Default configuration [attack-shark-r1.ini](https://github.com/xb-bx/attack-shark-r1-driver/blob/master/attack-shark-r1.ini)
