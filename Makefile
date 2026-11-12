PREFIX  ?= /usr
BINDIR  ?= $(PREFIX)/bin
DATADIR ?= $(PREFIX)/share/swbr
CONFDIR ?= $(HOME)/.config/swbr

CC      ?= cc
CFLAGS  ?= -std=c11 -O2 -Wall -Wextra
LDLIBS   = -lwayland-client -lm

# short md5 of the sources, compiled in: `swbr --version` then tells you
# exactly which build is running. The headers count too, so a fix in one of
# them is a different build even when swbr.c has not moved.
BUILD   := $(shell cat swbr.c sw_theme.h 2>/dev/null | md5sum | cut -c1-8)

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
	install -Dm755 swbr $(DESTDIR)$(BINDIR)/swbr
	install -Dm644 config.example $(DESTDIR)$(DATADIR)/config.example
	install -Dm644 config.advanced.example $(DESTDIR)$(DATADIR)/config.advanced.example
	@echo "installed $(DESTDIR)$(BINDIR)/swbr"
	@echo "examples  $(DESTDIR)$(DATADIR)/"

# Your own copy: edit it freely, an install never touches it.
config:
	install -d $(CONFDIR)
	[ -f $(CONFDIR)/config ] || install -m644 config.example $(CONFDIR)/config

# The shipped example, live: every install updates what you are running.
# Link the advanced one with  make link EXAMPLE=config.advanced.example
EXAMPLE ?= config.example
link:
	install -d $(CONFDIR)
	ln -sfn $(DATADIR)/$(EXAMPLE) $(CONFDIR)/config
	@echo "$(CONFDIR)/config -> $(DATADIR)/$(EXAMPLE)"

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/swbr
	rm -f $(DESTDIR)$(DATADIR)/config.example
	rm -f $(DESTDIR)$(DATADIR)/config.advanced.example
	-rmdir $(DESTDIR)$(DATADIR) 2>/dev/null || true

clean:
	rm -f swbr swbr-debug

.PHONY: all debug install config link uninstall clean
