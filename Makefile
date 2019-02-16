TARGET=demo
SRCS=$(wildcard src/*.asm)
OBJS=$(patsubst src/%.asm, build/%.o, $(SRCS))

.SECONDARY: $(OBJS)

all: build/$(TARGET).gbc

build/%.o: src/%.asm
	mkdir -p build/
	rgbasm -i src/ -i data/ -p 0xff -o $@ $<

build/%.gbc: $(OBJS)
	mkdir -p build/
	rgblink -p 0xff -n build/$*.sym -m build/$*.map -o $@ $(OBJS)
	rgbfix -Cjv -i XXXX -k XX -l 0x33 -m 0x1A -r 0x04 -p 0 -r 1 -t $(TARGET) $@

clean:
	rm -r build/
