driver: main.odin
	odin build . -out:$@ -debug -error-pos-style:unix
.PHONY: release 
release: main.odin
	odin build . -out:./driver -o:size
DESTDIR ?= /
.PHONY: install
install: ./driver 
	mkdir -p "$(DESTDIR)usr/bin"
	mkdir -p "${DESTDIR}etc"
	install -Dm755  driver "${DESTDIR}usr/bin/attack-shark-r1-driver"
	install -Dm644 --target-directory="${DESTDIR}etc" attack-shark-r1.ini
.PHONY: uninstall
uninstall:
	rm "${DESTDIR}usr/bin/attack-shark-r1-driver" "${DESTDIR}etc/attack-shark-r1.ini"

.PHONY: clean
clean:
	rm -r driver

