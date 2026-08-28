PREFIX  ?= $(HOME)
BINDIR  ?= $(PREFIX)/bin
CONFDIR ?= $(HOME)/.config/swbr

CC      ?= cc
CFLAGS  ?= -std=c11 -O2 -Wall -Wextra
LDLIBS   = -lwayland-client -lm

# short md5 of the source, compiled in: `swbr --version` then tells you
# exactly which build is running
BUILD   := $(shell md5sum swbr.c 2>/dev/null | cut -c1-8)

all: swbr

swbr: swbr.c stb_truetype.h
	$(CC) $(CFLAGS) -DSWBR_BUILD='"$(BUILD)"' -o $@ swbr.c $(LDFLAGS) $(LDLIBS)
	@./$@ --version

stb_truetype.h:
	@echo "missing $@ — drop the vendored header next to the source"
	@echo "(the same one appwheel uses)"
	@false

debug: swbr.c stb_truetype.h
	$(CC) -std=c11 -g -O0 -Wall -Wextra -fsanitize=address,undefined \
		-DSWBR_BUILD='"$(BUILD)-dbg"' -o swbr-debug swbr.c $(LDFLAGS) $(LDLIBS)

install: swbr
	install -d $(BINDIR)
	install -m755 swbr $(BINDIR)/swbr

config:
	install -d $(CONFDIR)
	[ -f $(CONFDIR)/config ] || install -m644 config.example $(CONFDIR)/config

uninstall:
	rm -f $(BINDIR)/swbr

clean:
	rm -f swbr swbr-debug

.PHONY: all debug install config uninstall clean
