attack-shark-r1-drv: main.c
	cc -lusb-1.0 main.c -g -o $@
.PHONY: clean
clean:
	rm -r attack-shark-r1-drv

