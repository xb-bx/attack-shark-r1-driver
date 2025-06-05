pkgname="attack-shark-r1-driver"
pkgver="1.0.0"
pkgrel="1"
pkgdesc="Userspace driver for Attack Shark R1 mouse"
arch=("x86_64")
depends=("libusb")
makedepends=("odin" "git")
url="https://github.com/xb-bx/attack-shark-r1-driver"
source=("git+$url")
md5sums=("SKIP")

build() {
    cd $pkgname
    git submodule update --force --init --recursive
    make release
}
package() {
    cd $pkgname
    DESTDIR="${pkgdir}/" make install
    #mkdir -p "${pkgdir}/usr/bin"
    #mkdir -p "${pkgdir}/etc"
    #install -Dm755  driver "$pkgdir/usr/bin/attack-shark-r1-driver"
    #install -Dm644 --target-directory="$pkgdir/etc" attack-shark-r1.ini
}

