# swbr

A floating bar for [Sway](https://swaywm.org), on the layer shell. It sits on
top of the tiled windows at the screen edge instead of taking space from them.
Hover it and press space and it folds into a thin strip that still tells you
what is going on.

![swbr](screenshot.png)

100% vibecode, but tested.

## Build

```sh
sudo apt install build-essential libwayland-dev
make
make install          # ~/.local/bin, or PREFIX=/usr/local
make config           # optional: swbr_config.example -> ~/.config/swbr/config
```

`libwayland-client` is the only library it links. The wlr-layer-shell protocol
glue is vendored, so there is no `wayland-scanner` step. Fonts come from
`stb_truetype.h`, also vendored.

Needs a running sway session (`$SWAYSOCK`) and any TTF font. `fc-match` is used
to pick one if it is there.

## Use

```
exec_always swbr --replace
```

`--replace` terminates a bar that is already running and waits for it to go,
which is what you want on a sway reload. Do not use `pkill swbr` on a separate
line for this: sway forks each `exec_always` without waiting for it, so the
kill and the new bar race each other and the kill usually wins — which looks
exactly like the bar refusing to start.

| | |
| --- | --- |
| left click a workspace | switch to it |
| hover the bar, press `space` | fold it into the signal strip, and back |
| click a cell | run its `button1=` command |
| `pkill -USR1 swbr` | fold or unfold every bar |

The right hand side is made of **cells**: one command each, run on an interval
or kept running and read line by line.

```
cell=clock
clock.cmd=date '+%H:%M'
clock.interval=20

cell=vol
vol.cmd=pactl get-sink-volume @DEFAULT_SINK@ | grep -o '[0-9]*%' | head -1
vol.interval=2
vol.button1=pavucontrol

bar={workspaces||vol,clock}
```

`bar=` is one line that places everything: `||` splits left / center / right,
`,` separates cells, `(a,b)` glues two together. Keep it last in the config.

## Folded

`space` over the bar folds it to a few pixels. The strip keeps saying
something.

![swbr, folded](screenshot-slim.png)

| `NAME.slim=` | on the strip |
| --- | --- |
| `tick` | a block, on while the cell has output |
| `bar` | a gauge, `slim_min`–`slim_max` |
| `clock` | twelve bars, lit up to the hour — two at 02:00, still two at 02:55, softer before noon |
| `presence` | a block in the `running` colour, there only while the program is |
| `media` | two full-height bars while playing, the same two short and dim when paused, nothing when stopped |
| `auto` | pick from what the cell prints |
| `off` | nothing |

A cell keeps its own colour when folded, markup included, so a green "playing"
glyph stays green down there. `slim_color` overrides it, `slim_color2` is the
second one a clock uses for its minutes. `slim_on=` says which output counts as
playing for `slim=media` — it has to match what your command prints. Without
it swbr guesses from the usual glyphs and the words "playing" and "paused",
which only helps if your player happens to print one of them.

For cmus there is no guessing:

```
cell=music
music.source=cmus
```

Two cells, if you want the icon separate from the title:

```
cell=cmusui
cmusui.source=cmus
cmusui.cmus_fmt=%i          # just ▶ or ⏸

cell=cmus
cmus.source=cmus
cmus.cmus_fmt=%n            # just Artist — Title
cmus.slim=off
```

`cmus_fmt` understands `%i` (the icon, which follows the real state), `%n`
(artist — title, or just the title), `%a`, `%t` and `%s` (the word playing or
paused). The default is `%i %n`.

That is the whole config, and `source=cmus` sets the command itself — a
`music.cmd=` from an older config would leave swbr parsing a script's output
instead of cmus's own, so setting one switches the cell back to a plain
command. swbr runs `cmus-remote -Q` and reads the `status` line, so playing and paused are facts, not a guess at what a script
printed. The bar shows `▶ Artist — Title` or `⏸ Artist — Title`, the icon
following the actual state, and the cell disappears when cmus is stopped or
not running. Left click toggles pause, middle skips forward, right goes back;
`music.cmd=`, `music.interval=` and the binds override any of it.

`swbr --probe` prints what it decided for every cell, and the text it decided
it from:

```
cell music      iv=2  min_w=0  sep=1  '♪ Boards of Canada — Roygbiv'
            slim=media  playing=yes  slim_on unset, guessing from the text
```

`signals=0` turns the whole thing off and leaves a plain strip.

## Battery

```
cell=battery
battery.source=battery
```

Reads capacity and status out of `/sys/class/power_supply` itself: `83+` while
it is filling, `83-` while it is draining, and no sign at all when it is full,
since nothing is happening. The sign
carries the direction, so there is no percent sign spending width. `slim=bar`
and the 0–100 range are set for you.

Not every machine calls it `BAT0`, so it takes the first thing with a
`capacity` file, preferring one named `BAT*`. Point it elsewhere with
`battery.bat_path=/sys/class/power_supply/BAT1` — which is also how you pick
one of two — and lay it out with `battery.src_fmt=`: `%c` capacity, `%i` the
sign, `%w` what it is drawing right now in watts, `%h` how long that leaves,
`%s` the word. `battery.src_fmt=%c%i %w %h` gives `83- 21.5W 1.7h`.

The watts and the hours come from `energy_now`/`power_now` where the kernel
reports those, and from `charge_now`/`current_now`/`voltage_now` where it does
not; whichever pair exists gives both numbers, and they are simply left empty
when neither does.

None of this takes anything away. Setting `battery.cmd=` switches the cell
back to your own script, as with any other cell; `source=` and `cmd=` are the
two ways of filling a cell, and whichever comes last in the config wins.

## Other monitors

`ws_other=1` adds the workspaces from your other screens to the bar, drawn as
short pills sitting on the bar's bottom edge at a little over half height, in
type a fifth smaller and a little see-through. It is on in the shipped config.

Folded, they take a slot like any other workspace but never this screen's
emphasis — focused on the other monitor is not focused here, so the brightest
they ever get is a soft accent. They stay
readable and clickable, and nothing about them looks like it belongs to this
screen.

## Load per workspace

A column of dots up the right edge of each workspace button says how much
processor time the windows on that workspace are using: one lit when it is
idling, all of them when something is working. Dots rather than a solid fill,
so the button's own colour still reads through the gaps — six of them on a
30 px bar, three in the folded strip, where the same dots run up the workspace
slot.

They keep one colour — `accent`, held back towards `dim` — and only tip
towards `urgent` when a workspace is really pinned, so it is the count and not
the hue that carries the load. `hl` is what paints the focused workspace, so
nothing here goes near it.

swbr asks sway which window belongs to which workspace, reads `/proc`, and
credits every process to the nearest ancestor that owns a window — so a build
running in a terminal counts towards the workspace that terminal is on. Each
process is measured by its own cpu time *plus* the time of the children it has
already reaped, which is what makes a build show up at all: every compiler
process lives for a moment and is gone long before the next sample, and its
time only survives in its parent's totals.
Anything with no window above it, a daemon or the session itself, belongs to
no workspace and is left out. The colour runs from `running` through
`slim_warm` into `urgent`.

```
ws_cpu=1  ws_cpu_interval=3  ws_cpu_min=4  ws_cpu_full=60
```

The numbers are written to `$XDG_RUNTIME_DIR/swbr-cpu` so swov can show the
same thing on its tiles without measuring anything itself — a rate needs two
samples seconds apart, and swov is only on screen for a moment. `swbr --probe`
prints what it last measured, and how many windows it found in sway's tree to
attribute work to — if that count is zero, nothing can ever show.

## Messages

Other programs can shout at the bar, which shows the text in place of a cell:

```sh
swbr --msg 'warn: battery at 9%'
swbr --msg clear
echo 'info: build done' > $XDG_RUNTIME_DIR/swbr.fifo
```

`msg_target=` says which cell is taken over, `msg_timeout=` for how long.

## Config

`${XDG_CONFIG_HOME:-~/.config}/swbr/config`, `key=value`, `#` comments. Every
key is also a command line option:

```sh
swbr position=bottom height=32
swbr --dump-config > ~/.config/swbr/config
swbr --probe        # outputs, sizes, font metrics and what each cell prints
```

`swbr_config.example` lists everything with defaults. The ones worth knowing:

| key | |
| --- | --- |
| `position`, `layer`, `height` | where the bar sits and how tall it is |
| `exclusive` | `1` = reserve the space, `0` = float above the windows |
| `min_width`, `align_x`, `side_margin` | a floating bar sizes itself to its content |
| `radius` | corner radius; the corners at the screen edge stay square |
| `outputs` | which monitors get a bar |
| `ws_names`, `ws_inset`, `ws_radius` | workspace buttons: numbers or names, pills or blocks |
| `font`, `font_alt`, `ui_scale`, `text_px` | text |
| `markup` | the pango subset: `<span foreground=..>`, `<b>`, `&amp;` |
| `hide_key`, `collapsed_px`, `anim_ms` | folding |
| `signals`, `slim_ws_slots`, `slim_warm` | what the folded strip shows |
| `status_command` | i3bar-style status, used when no cells are configured |

### Shared config

Colours and fonts for swbr, swov and appwheel can be set once in
`${XDG_CONFIG_HOME:-~/.config}/sw/config`, using role names (`surface`,
`accent`, `hl`, ...) that each program maps onto its own keys. `sw_theme.h`
lists them all.

Keys written before any section go to all three programs; a `[swbr]` section
goes to swbr only and takes its own key names as well. The config above is read
afterwards, so it always wins, and the command line wins over that.

## Notes

- Talks to the sway IPC socket directly: no `swaymsg`, no `jq`.
- One bar per output, each with its own surface and buffer.
- Text is rasterised in software into an ARGB32 buffer — no GPU, no SDL.
- `hover_keys=1` grabs the keyboard only while the pointer is over the bar,
  which is what makes `hide_key` work without clicking first.
- A cell with `interval=-1` keeps its command running and takes every line it
  prints, so a script can push updates the moment they happen.
