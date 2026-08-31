# swbr

A floating bar for [Sway](https://swaywm.org), on the layer shell. It sits on
top of the tiled windows at the screen edge instead of taking space from them.
Hover it and press space and it folds into a thin strip that still tells you
what is going on.

![swbr](screenshot.png)

![swbr, folded](screenshot-slim.png)

100% vibecode, but tested.

## Build

```sh
sudo apt install build-essential libwayland-dev
make
make install          # ~/.local/bin, or PREFIX=/usr/local
make config           # optional: config.example -> ~/.config/swbr/config
```

`libwayland-client` is the only library it links. The layer-shell protocol glue
and the font rasteriser are vendored, so there is no `wayland-scanner` step.
Needs a running sway session (`$SWAYSOCK`) and any TTF font.

## Use

```
exec_always swbr --replace
```

`--replace` terminates a bar that is already running and waits for it to go.
Use it instead of a separate `pkill swbr` line: sway forks each `exec_always`
without waiting, so a kill on one line races the bar started on the next and
usually wins.

| | |
| --- | --- |
| left click a workspace | switch to it |
| the pointer | turns into a hand over anything that does something |
| hover the bar, press `space` | fold it into the strip, and back |
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

`bar=` places everything: `||` splits left / center / right, `,` separates
cells, `(a,b)` glues two together. Keep it last in the config.

## Sources

Some cells need no script. `source=` fills them in directly; setting `cmd=` on
the same cell switches it back to your own command.

```
cell=cmus                 cell=battery              cell=mpv
cmus.source=cmus          battery.source=battery    mpv.source=window
                                                    mpv.program=mpv
```

**cmus** runs `cmus-remote -Q` and reads the `status` line, so playing and
paused are facts rather than a guess at what a script printed. Prints
`▶ Artist — Title` or `⏸ …`, nothing when cmus is stopped. Left click toggles
pause, middle skips forward, right goes back. `cmus_fmt`: `%i` icon, `%n`
artist — title, `%a`, `%t`, `%s`; default `%i %n`. Two cells work — one `%i`,
one `%n` — if you want the icon separate from the title.

**battery** reads `/sys/class/power_supply`: `83+` filling, `83-` draining, no
sign when full. `bat_path=` picks one if yours is not `BAT0` or you have two.
`src_fmt`: `%c` capacity, `%i` sign, `%w` watts now, `%h` hours left, `%s` the
word — `%c%i %w %h` gives `83- 21.5W 1.7h`.

**window** asks sway which workspaces have a window of `program=` and prints
`mpv [3|5]`. Matched against the app id, the X11 class, then the title.
`src_fmt`: `%n` the cell's name, `%w` the workspaces, `%c` the count.

## Folded

`space` over the bar folds it to a few pixels.

| `NAME.slim=` | on the strip |
| --- | --- |
| `tick` | a block, on while the cell has output |
| `bar` | a gauge, `slim_min`–`slim_max` |
| `clock` | twelve bars lit up to the hour, softer before noon |
| `presence` | a block, there only while the program is |
| `media` | a full block playing, a short dim one paused, nothing stopped |
| `auto` | pick from what the cell prints |
| `off` | nothing |

A cell keeps its own colour when folded, markup included. `slim_color`
overrides it, `slim_color2` is the clock's minutes. For `slim=media` on a plain
command cell, `slim_on=` says which output counts as playing; a `source=` cell
already knows.

`slim_align=1` (the default) gives each mark its cell's whole place, inset by
the same padding the text had — so folding changes the height of the bar and nothing else.
Starting folded, the open layout is worked out once with nothing drawn, so the
marks are the right size from the first frame. `slim_align=0` packs them
against the right edge instead.

`signals=0` leaves a plain strip.

## Hover

`NAME.hover=` is what a cell shows while the pointer is on it, with the same
placeholders its source understands, or `%s` for a command's output:

```
battery.hover=%w  %h %e        # 21.5W  1.7h left, or 0.3h to full on the cable
battery.hover_click=1          # opens on a click, not on the pointer
battery.hover_slim=0
```

`%e` says which way the clock is running — half an hour means nothing on its
own when it could be to full or to empty. With nothing to report, a full
battery or a kernel that gives no rate, the panel falls back to the status
word rather than showing blanks.

`hover_click=1` — set on the battery and the calendar in the shipped config —
waits for a left click and stays open until that cell is
clicked again, something else is, or the pointer leaves the bar — so you can
read it without holding still. Pointing at such a cell does nothing.

The cell is measured with that text
It slides down out of the bar and fades in over `anim_ms`, centred on the cell
and padded like one: square where the two meet, rounded on the far side. Near
an end of the bar it snaps flush with it and both square that corner, so the
outer edge runs straight from the bar into the panel. The surface grows to make room and
shrinks again when you leave. The padding either side of a cell counts as
part of it, and the panel itself takes the pointer, so resting on it keeps it
open.

`NAME.hover_cal=1` puts this month in the panel, with today in the `hl`
colour. It is built in rather than shelled out to `cal(1)`, so the columns line
up whatever the font and resting on the clock spawns nothing. Weeks start on
Monday, and `‹ ›` at either end of the title row page the month; it opens on
the current one every time.

`NAME.hover_cmd=` is the general form: any command's output, run once when the
hover starts rather than on a timer. The panel is as tall as the output has
lines either way.

```
clock.hover_cal=1
clock.hover_cmd=cal      # the same idea, if you prefer cal's own layout
```

Folded there is no room for a panel, so there is no hover unless
`hover_slim=1`, which opens the bar while you rest on that cell. Off by
default.

## Going flat

```
battery.alert=30,20,10,5
battery.alert_msg=BATTERY %c%%
battery.alert_tone=250
```

Each level fires once on the way down and rearms when the charge comes back
above it, or when the cable goes in — so 19% does not nag every ten seconds.
The message goes through the bar's own message system, as a warning except for
the last level, which is an error.

The tone is a sine with a raised-cosine edge either side, written as raw PCM
straight into `alert_play` (`aplay -q -f cd -` by default, or
`paplay --raw --rate=44100 --format=s16le --channels=2` on pipewire). Soft
edges mean it starts and stops without the click a test tone makes.
`alert_tone=0` for silence, `alert_ms` and `alert_beeps` for length and count.
The last two levels press harder — the one before last gets an extra beep and
a fifth more length, the last three extra beeps and half as long again, so
2.1 s of sound at 30% becomes 8.4 s at 5% and you can tell them apart from the
next room.

`alert_cmd=` runs at every level with `%c` as the percentage, which is where
a last-ditch `[ %c -le 1 ] && systemctl poweroff` goes.

## Load per workspace

A column of dots up the right edge of each workspace button, and up its slot in
the folded strip. The scale is in **cores**: `1.0` is one core kept busy,
`ws_cpu_full=4` fills the column.

```
0.000 cores  ......   a terminal at a prompt
0.02         +.....   cmus playing
0.4          #.....   mpv decoding
1.9          ###...   a browser working
4.0          ######   make -j4
```

Anything alive but below the scale gets one faint dot, so a workspace that is
doing something never looks asleep; `ws_cpu_idle` is where that starts.

swbr asks sway which window belongs to which workspace, reads `/proc`, and
credits each process to the nearest ancestor that owns a window — a build in a
terminal counts towards that terminal's workspace. Each process is measured by
its own cpu time plus the time of the children it has reaped, which is what
makes a build show up at all: every compiler process is gone before the next
sample, and its time only survives in its parent's totals.

```
ws_cpu=1  ws_cpu_interval=3  ws_cpu_idle=0.01  ws_cpu_min=0.25  ws_cpu_full=4
```

The numbers go to `$XDG_RUNTIME_DIR/swbr-cpu` so swov can draw the same thing
without measuring anything itself.

## Other monitors

`ws_other=1` adds the workspaces from your other screens as short pills on the
bar's bottom edge, in smaller, dimmer type. Folded they take a slot like any
other, but never this screen's emphasis.

## Messages

Other programs can shout at the bar, which shows the text in place of a cell,
pulses the folded strip in the message colour, and drops the words into the
panel for `msg_panel` seconds (3 by default) so they can be read when the bar
is folded:

```sh
swbr --msg 'warn: battery at 9%'
swbr --msg clear
echo 'info: build done' > $XDG_RUNTIME_DIR/swbr.fifo
```

`msg_target=` says which cell is taken over, `msg_timeout=` for how long,
`msg_flash=0` stops the pulse and `msg_panel=0` the panel.

## Config

`${XDG_CONFIG_HOME:-~/.config}/swbr/config`, `key=value`, `#` comments. Every
key is also a command line option:

```sh
swbr position=bottom height=32
swbr --dump-config > ~/.config/swbr/config
swbr --probe        # outputs, sizes, font metrics, and what every cell decided
```

Two are shipped: `config.example` is short, one of each thing, and
`config.advanced.example` is the full one — every cell, the alerts, the
panels, and a `poweroff` at one percent. Either goes to
`~/.config/swbr/config`.

`config.advanced.example` lists everything with defaults. The ones worth knowing:

| key | |
| --- | --- |
| `position`, `layer`, `height` | where the bar sits and how tall it is |
| `exclusive` | `1` = reserve the space, `0` = float above the windows |
| `min_width`, `align_x`, `side_margin` | a floating bar sizes itself to its content |
| `radius` | corner radius; the corners at the screen edge stay square |
| `outputs`, `ws_other` | which monitors get a bar, and whose workspaces show |
| `ws_names`, `ws_inset`, `ws_radius` | numbers or names, pills or blocks |
| `font`, `font_alt`, `ui_scale`, `text_px` | text |
| `markup` | the pango subset: `<span foreground=..>`, `<b>`, `&amp;` |
| `hide_key`, `collapsed_px`, `anim_ms` | folding |
| `signals`, `slim_align`, `slim_ws_slots` | what the folded strip shows |
| `status_command` | i3bar-style status, used when no cells are configured |

Colours and fonts for swbr, swov and swas can be set once in
`${XDG_CONFIG_HOME:-~/.config}/sw/config` under role names (`surface`,
`accent`, `hl`, …) that each program maps onto its own keys; `sw_theme.h` has
the table. Keys before any section go to all three, a `[swbr]` section to swbr
only. This config is read afterwards and wins, the command line wins over that.

## Notes

- Talks to the sway IPC socket directly: no `swaymsg`, no `jq`.
- The cursor comes from `cursor-shape-v1`, so there is no cursor theme to
  load and no cursor surface to draw. On a compositor without it the pointer
  simply keeps whatever shape it had.
- One bar per output, each with its own surface and buffer.
- Text is rasterised in software into an ARGB32 buffer — no GPU, no SDL.
- `hover_keys=1` grabs the keyboard only while the pointer is over the bar,
  which is what makes `hide_key` work without clicking first.
- A cell with `interval=-1` keeps its command running and takes every line it
  prints, so a script can push updates the moment they happen.
