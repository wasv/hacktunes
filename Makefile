TARGET=demo
SRCS=$(wildcard src/*.asm)
PNGS=$(wildcard data/*.png)
OBJS=$(patsubst src/%.asm, build/%.o, $(SRCS))
GFXS=$(patsubst data/%.png, data/%.bin, $(PNGS))

.SECONDARY: $(OBJS) $(GFXS)
.PHONY: all gfx

all: build/$(TARGET).gbc

data/%.bin: data/%.png
	rgbgfx -o $@ $<


build/%.o: src/%.asm $(GFXS)
	mkdir -p build/
	rgbasm -i src/ -i data/ -p 0xff -o $@ $<

build/%.gbc: $(OBJS)
	mkdir -p build/
	rgblink -p 0xff -n build/$*.sym -m build/$*.map -o $@ $(OBJS)
	rgbfix -Cjv -i XXXX -k XX -l 0x33 -m 0x1A -r 0x04 -p 0 -r 1 -t $(TARGET) $@

clean:
	rm -r build/
