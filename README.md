# SwBr

**100% Vibecode but tested.**

A floating status bar for Sway. Replaces `swaybar`. Binary: `swbr`.

It sits on the layer shell above the tiled windows, flush with the top edge.
Hover it, press space, and it rolls up into a 5px signal strip.

![SwBr](screenshot.png)

Folded: workspace slots, twelve clock dots, gauges — still readable, still
clickable.

![SwBr folded](screenshot-slim.png)

Version: **0.8.1**

## Why not swaybar

- Floats above the windows instead of taking their space (`exclusive=0`).
- Folds away on a key, without re-tiling anything.
- Bar squared off against the screen edge, rounded on the free side. The
  focused workspace is a full-height block in the appwheel orange.
- Same look and same `key=value` config as `swov` and `appwheel`.

## Build

```sh
make
```

or by hand:

```sh
cc -std=c11 -O2 -Wall -Wextra -o swbr swbr.c -lwayland-client -lm
```

`stb_truetype.h` sits next to the source, same as for `appwheel`.
The layer-shell protocol glue is vendored inside `swbr.c`, so there is no
`wayland-scanner` step.

Needs: `libwayland-client`, a running Sway session (`$SWAYSOCK`).
Optional: `fc-match` to pick up the desktop font.

## Install

```sh
make install          # -> ~/bin/swbr, override with PREFIX= or BINDIR=
make config           # -> ~/.config/swbr/config, never overwrites
```

**Delete the `bar { ... }` block from your sway config.** If you leave it,
swaybar keeps running underneath and you see its text peeking out below SwBr.
Then add:

```
exec_always pkill -x swobar; exec_always ~/bin/swbr
```

Your old `status_command` script keeps working — point the config at it:

```
status_command=~/bin/sway_bar_status.sh
```

## Cells

The right hand side is a row of cells. One command per cell, its own
interval, its own colour. No status script in between.

```
cell=cpu                    # order of the cell= lines = order on the bar
cpu.cmd=cpu_in_percent
cpu.fmt=%s%
cpu.interval=2
cpu.warn=>70:cecb00         # recolour at or above 70
cpu.crit=>80:cc0403
cpu.min_w=52                # never jitter when the number gets shorter
cpu.sep=0                   # no separator: glue the next cell to this one
cpu.button1=foot -e htop    # click it
```

| Field | Does |
| --- | --- |
| `cmd` | shell command, its output is the text |
| `interval` | seconds; `0` = once, `-1` = stream every line |
| `fmt` | `%s` is the output; no printf escaping |
| `color` `bg` | fixed colours |
| `warn` `crit` | `>70:cecb00` / `<12:ff2222` on the first number |
| `min_w` `max_w` `align` | width and placement of the text |
| `sep` | `0` combines this cell with the next |
| `hide_empty` | prints nothing = cell and separator disappear |
| `empty` | text drawn instead of hiding, so the area stays clickable |
| `gap` | space after the cell; `0` glues it to the next one |
| `pad` | padding inside the cell |
| `slim` | folded strip: `auto`, `tick`, `bar`, `clock`, `off` |
| `slim_min` `slim_max` | value range a gauge maps |
| `slim_w` | width in the folded strip |
| `markup` | `<span foreground="#rrggbb">` inside the output |
| `button1..9` | per-cell click commands |
| `pos` | `left`, `center` or `right` group |
| `scroll` | fixed slot, `..` when too long, scrolls on hover |

`swbr_config.example` ships a full set that reproduces a typical swaybar
script: cmus, volume, docker, mpv, clock, cpu, temperature, battery.

With no cells configured, `status_command` still works the old way.

## Messages

Anything on the system can shout at the bar through a fifo
(`$XDG_RUNTIME_DIR/swbr.fifo`, override with `msg_fifo=`):

```sh
swbr --msg "warn: backup running"
swbr --msg "error: disk full"
swbr --msg clear
echo "info: done" > $XDG_RUNTIME_DIR/swbr.fifo
```

`info:` / `warn:` / `error:` pick the colour. `msg_timeout=8` seconds, `0`
keeps it until cleared, and clicking it dismisses it.

`msg_target=cmus` hands a cell over to the message while one is up — the
music title becomes the warning, then goes back to being the title. With no
target the message is drawn centred on its own. Folded, `msg_flash=1` paints
the whole strip in the message colour, so an error is visible at 4px.

## Layout

One line places everything:

```
bar={workspaces,mode||cmus,volume,(docker,mpv),clock,(cpu,temp),(power,battery)}
```

- `||` splits groups — one part is left, two are left and right, three are
  left, centre and right.
- `,` separates items, `(a,b)` glues them with no separator between.
- Names are your cell names plus the built-ins `workspaces` and `mode`.

It assigns group, order and separators, so keep it last in the config. The
left group reserves its width first, then the right one is placed against it,
so nothing ever overlaps.

`min_width=800` makes the bar a floating pill instead of a full-width strip,
and it **sizes itself to its content**: never narrower than `min_width`,
never wider than the screen. A cell appearing — charging, a docker list, a
longer clock — grows the bar instead of being cut off. `min_width=0` goes
back to spanning the whole output. `align_x=center|left|right` places it.

## Buttons that stay put

A cell that prints nothing disappears — fine for docker, wrong for a media
control you want to click. Two fields fix it:

- `empty=♪` draws a placeholder instead of hiding, so the area and its click
  bindings survive.
- `gap=0` glues a cell to the next one; with a `bg` on both, they render as
  one continuous box.

The shipped config uses this for cmus: the title is a scrolling text cell,
the transport controls are their own cell right next to it. The controls can
never be truncated away by a long title, and when cmus is not running the
title vanishes while the button stays and starts it.

## Text cells

`NAME.scroll=1` with a `min_w` gives a cell a fixed slot. Longer text is cut
with `..`, and scrolls through while the pointer sits on it. When the bar
runs out of room, these are the cells that give up width — nothing else
moves.

## Use

| Action | Result |
| --- | --- |
| Left click a workspace | switch to it |
| Hover + `space` | fold / unfold the bar |
| `pkill -USR1 swbr` | fold / unfold without the mouse |
| Click a message | dismiss it |
| Mouse buttons | run `button1`..`button9` commands |

## The folded strip

Four pixels tall and still readable:

- **Workspaces** keep a fixed slot each, so slot 3 is always workspace 3 —
  missing ones stay as faint placeholders and nothing shifts around.
- **A clock cell** (`slim=clock`) becomes twelve dots: hours up to now are
  lit, the current hour grows with the minutes.
- **Anything with a percentage, or with warn/crit thresholds**, becomes a
  gauge: a visible track filled to its value, in that cell's current colour.
  Battery red still reads as red. `slim_min`/`slim_max` map any range, so a
  temperature cell can be a gauge over 40..100 C.
- **A message** takes the whole strip in its colour.

Per cell: `slim=auto|tick|bar|clock|off`, plus `slim_min`/`slim_max`.
Height is `collapsed_px` (5 by default).

The strip stays **clickable**: workspace slots still switch workspaces, and a
cell's button bindings still fire. Give a media cell `slim=tick` (not `off`)
and `slim_w=26`, and it stays on the strip as a play/pause button you can
find and hit — the screen edge makes a 5px target easy.

For something you must be able to reach without aiming, use the bar-wide
`button2=` / `button6=` / `button7=` bindings: they fire anywhere no cell
sits, folded or not. Start folded with `swbr --slim`.

Elements sit in the same order as the expanded bar, and cells glued in the
layout stay glued here too. `swbr --probe` prints the whole strip left to
right with each element's mode, colour and fill, which is the fastest way to
work out which bar is which.

## Screen modes

Sizes are logical pixels, multiplied by the output scale — the bar looks the
same on a HiDPI screen. `height=0` derives the height from the font, and
`ui_scale` scales all text at once. One bar per output, each with its own
workspaces.

## Config

`~/.config/swbr/config`, `key=value`, one per line.
Every key also works on the command line: `swbr ui_scale=1.2 exclusive=1`.

```sh
swbr --help          # all keys
swbr --dump-config   # a config file with every default
swbr --probe         # outputs, sizes, font metrics, live cell values
swbr --msg TEXT      # send a message to the running bar
swbr --slim          # start folded
swbr --version       # SwBr 0.8.1 (build eaebdc09)  <- md5 of swbr.c
```

See `swbr_config.example` for the commented version.

## Notes

- `hover_keys=1` grabs the keyboard while the pointer is over the bar. That is
  what lets `space` work without a click first. Keystrokes typed while the
  pointer rests on the bar go to the bar, not to your window. Set
  `hover_keys=0` and use `SIGUSR1` if that bothers you.
- `hide_key` matches the physical key, not the layout.
- Status markup: `<span foreground=..>`, `<span background=..>`, `<b>`, `<i>`
  and the XML entities. The i3bar JSON protocol is not supported.
- No system tray.

## Tested

- Builds clean with `-Wall -Wextra`. `--version` carries the md5 of the
  source, so you always know which build is running.
- Config parser: inline comments stripped, `#` inside quoted command text
  kept, verified against the shipped example.
- Vertical centering checked at scale 1 and 2: digits sit equally far from
  both edges.
- Merged backgrounds verified pixel by pixel: no bare bar shows between two
  glued cells, so the pair reads as one panel.
- Media glyphs checked against the font before shipping them: `U+23F8` and
  the rest of that block are missing from DejaVu, so the config uses glyphs
  that exist.
- The folded paint path is now the same code the compositor gets, run
  headless in tests: the music button lands at 582..608 in its own colour
  with its binding attached, and a middle click anywhere else falls through
  to the bar-wide binding.
- Self-sizing checked across states: 800px idle, 1217px with charging, temp
  and a docker list, and capped at the 1920px screen when content overflows.
- Folded strip rendered and sampled pixel by pixel: workspace slots, clock
  dots, and gauge fills matching their values (47%, 63%, 60%, 88%) against a
  track that is actually visible.
- cmus split checked both ways: idle leaves only the button and its click
  binding, playing keeps the controls at full width beside a truncated title.
- Focused workspace checked pixel by pixel: solid `cb9b00` from the top row
  to the bottom row, square corners, and the baseline lift is exactly 2px.
- Layout DSL parsed and rendered: groups, glued items, hit boxes measured on
  an 800px bar — workspaces and cells no longer overlap, the last cell lands
  exactly on the right padding, and a hovered text cell scrolls.
- Messages tested end to end: fifo round trip, level parsing, cell takeover
  and hand-back, and the centred-group layout landing on the bar's midpoint.
- Markup parser, glyph cache, text metrics and the rounded-rect rasterizer
  run under ASan/UBSan against a real status line: no leaks, no overruns,
  correct premultiplied output, square top edge, rounded bottom corners.
- `--dump-config` output re-parses without warnings.
- Cells tested end to end: config parse, process spawn and reap, thresholds,
  hidden cells dropping their separators, `sep=0` grouping, `min_w`, and the
  resulting layout — under ASan/UBSan.
- `make`, `make debug` and `make clean` run clean.
- Not yet run against a live compositor — that part is yours.
