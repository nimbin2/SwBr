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
sudo make install     # /usr/bin, examples in /usr/share/swbr
make config           # optional: config.example -> ~/.config/swbr/config
make link             # or: config -> the installed example, kept in sync
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

**vcam** is the virtual webcam that loops your camera through a filter and
overlay chain. swbr asks its socket — `/tmp/vcam.sock`, or `$VCAM_SOCK` —
rather than running `vcam-ctl` on a timer, so whether it is up, what it is
sharing and whether it is recording are facts. The cell is not there at all
while vcam is not running.

```
cell=vcam
vcam.source=vcam
vcam.slim_color=#4ADE80
```

Folded it is lamps: green for running, a second red one while it is
recording. `slim_color2=` changes the red one.

Clicking it opens a menu in the panel under the bar:

| Row | |
|---|---|
| share a region… | pick it with slurp |
| share screen DP-1 | one row per monitor, named from sway |
| stop sharing | only while something is shared |
| show the webcam / webcam off | the webcam overlay on top of the share |
| webcam: top right → bottom right | moves it on, round the six positions |
| record the loopback / stop recording | |

Only the rows that make sense for the state it is in are offered. The menu
stays open while you work through it, because setting a share up is usually
several of these in a row.

The menu runs `vcam-ctl` for the doing — picking a region needs slurp, and
sharing a whole monitor needs geometry and down-scaling it already gets
right. `src_path=` points at it if it is not on `$PATH`.

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
Every folded frame works the open layout out first with nothing drawn, so the
marks are right from the first frame, `--slim` included. `slim_align=0` packs them
against the right edge instead.

`ws_slots=10` (the default) puts the numbers 1–10 in the bar whether or not
they exist. A free number is the same button in the same place, `ws_empty_alpha`
faint, and clicking it opens that workspace. `0` shows only open ones.

Folded and lined up, the workspace marks are the open bar's own buttons — the
same set, the same left edges, the same widths — so you click the same spot in
either mode. Brightness says used from unused. `slim_ws_w` forces a width;
`slim_ws_slots` only applies to the packed strip (`slim_align=0`).

`slim_bar_segs=10` splits a folded gauge into ten blocks, so four lit blocks
reads as forty percent. `slim_bar_gap` is the space between them,
`slim_bar_pad` the space either side of the whole gauge, and `0` segments
gives one solid bar. A cell too narrow to show the dividers halves the count;
give it a `slim_w` instead — on a gauge that wins over the alignment and grows
about the cell's middle, which is what a two-digit battery needs.

`signals=0` leaves a plain strip.

A floating bar (`min_width` > 0) sizes itself to its content. It grows at once,
but ignores getting narrower by less than `shrink_px=24` and waits `shrink_s=30`
before a bigger narrowing — it is centred, so every width change moves
everything on it.

## Redrawing

`redraw_ms=250` holds cell updates and merges whatever lands in the same window
into one frame — every frame is a round trip through the compositor, and ten
cells on their own timers would otherwise wake the bar three times a second.

Anything coming from sway is exempt. A workspace switch is drawn on the next
frame, so switching back and forth stays visible instead of the two changes
merging into one late frame.

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
hover starts rather than on a timer. It is wrapped in `timeout 2`, since it
runs on the frame the pointer arrives and a command that blocks would block
the whole bar. The panel is as tall as the output has
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
battery.alert=30,20,10,5,1
battery.alert_msg=BATTERY %c%%
battery.alert_tone=250
battery.alert_cmd=[ %c -le 1 ] && poweroff
```

Each level fires once on the way down and rearms when the charge comes back
above it, or when the cable goes in — so 19% does not nag every ten seconds.
The message goes through the bar's own message system, as a warning except for
the last level, which is an error.

`alert_cmd` runs at every level and **only** at a level, so a guard like
`[ %c -le 1 ]` needs `1` in the list — otherwise it is evaluated at 5% and
never again. `poweroff` also needs root.

`swbr --alert-test [CELL]` fires an alert now: it prints the levels, plays the
tone through your own player and reports its exit status, and shows what
`alert_cmd` would run at each level without running it. A player that fails
during a real alert now says so on the bar instead of failing silently.

`alert_gain` (35%) is how loud the tone itself is, which costs nothing and
moves no mixer. When that is not enough, `alert_vol_min` raises the mixer for
the tone and puts it back:

```
battery.alert_vol_min=50
battery.alert_vol_get=amixer -M get Master | grep -o '[0-9]*%' | head -1
battery.alert_vol_set=amixer -M -q set Master %v%
```

Any pair of commands works — the first prints a number, the second takes `%v`.
The level is only raised if it is already below the floor, and the restore is
the shell's own EXIT trap, so it happens even if the alert is killed part way
through. ALSA has no per-stream volume, so this is the master control: other
audio is louder for the second or two the tone lasts. A muted output stays
muted; append `unmute` to the set command if you would rather it spoke anyway.

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
without measuring anything itself. The last thirty-two windows to be focused
go to `$XDG_RUNTIME_DIR/swbr-focus` in the same spirit: swov opens and closes
in a moment and can never watch focus itself, so its `tab` key reads the order
from here.

## Other monitors

Workspaces are ordered by number, not in the order sway lists them — that is
grouped by output, so with a second monitor the numbers come out interleaved
and which way round depends on which cable went in first. `ws_sort=0` keeps
sway's order.

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
| `ws_names`, `ws_inset`, `ws_radius`, `ws_border` | numbers or names, pills or blocks, outlined or not |
| `ws_slots`, `ws_empty_alpha` | show every number, open or not, and how faint |
| `ws_cpu`, `ws_cpu_wash` | how busy each workspace is: dots, and a tint |
| `slim_ws_w`, `slim_bar_segs`, `slim_bar_gap` | folded slot width, gauge blocks |
| `font`, `font_alt`, `ui_scale`, `text_px` | text |
| `markup` | the pango subset: `<span foreground=..>`, `<b>`, `&amp;` |
| `hide_key`, `collapsed_px`, `anim_ms` | folding |
| `signals`, `slim_align`, `slim_ws_slots`, `slim_bar_segs` | what the folded strip shows |
| `status_command` | i3bar-style status, used when no cells are configured |

Colours and fonts for swbr, swov and swas can be set once in
`${XDG_CONFIG_HOME:-~/.config}/sw/config` under role names (`surface`,
`accent`, `hl`, …) that each program maps onto its own keys; `sw_theme.h` has
the table. Keys before any section go to all three, a `[swbr]` section to swbr
only. This config is read afterwards and wins, the command line wins over that.

`make install` also drops the shipped examples in `/usr/share/swbr/`.
`make link` points your config at one of them, so the next install is the
config you are running — handy if you want to follow the examples rather than
keep your own copy. Edits you make there are overwritten on install.

## Notes

- Talks to the sway IPC socket directly: no `swaymsg`, no `jq`. Every reply
  costs the compositor about twelve times its own size and never gives it
  back, so swbr asks as rarely as it can: a workspace switch is applied from
  the event itself rather than by fetching the list again, and only a change
  in the set of workspaces — one created, emptied, renamed — asks for a new
  one. The tree is
  the expensive question, so it is asked for only when sway has said
  something changed, never more often than `tree_min_s` (5), and shared
  between the load sampler and every `source=window` cell. Only the changes that
  can move a window between workspaces count — new, close, move, floating —
  so a shell retitling itself on every prompt does not. An idle session, or a
  busy terminal, fetches it once at startup and then not again — polling it every couple of
  seconds made sway grow by about six times each reply and never give it
  back, which is a compositor bug but not one worth leaning on.
- Cell updates are held for `redraw_ms` (250, or `refresh=` in seconds) and
  merged into one frame. Ten
  cells on their own timers wake the bar three times a second, each with one
  number changed, and every frame is a full round trip through the
  compositor; a clock a quarter of a second late is not a clock anyone
  notices. Anything moving — an animation, a hover, a scrolling cell —
  bypasses it.
- A frame that comes out identical to the one on screen is never sent: the
  new buffer is compared against the old and the commit skipped. Ten cells on
  short timers wake the bar constantly, but the volume is usually still 80%.
- Frames are capped at one per 8 ms per bar, so nothing upstream — an
  animation, a configure, a cell whose width wobbles — can turn into an
  unbounded stream of requests. `SWBR_TRACE=1 swbr` prints, every five
  seconds, how many commits, resizes, buffer pools, regions and configures
  went to the compositor, and on a second line how many IPC queries went to
  sway and how many kilobytes came back. `no_tree=1` stops swbr asking for the
  tree at all, which switches off the load dots and every `source=window`
  cell. `--minimal` goes further: workspaces only, no cells, no tree, no
  keyboard grab, no fifo — a bare layer surface, for finding out which part
  of swbr a compositor is unhappy about.
- The cursor comes from `cursor-shape-v1`, so there is no cursor theme to
  load and no cursor surface to draw. On a compositor without it the pointer
  simply keeps whatever shape it had.
- One bar per output, each with its own surface and buffer.
- Text is rasterised in software into an ARGB32 buffer — no GPU, no SDL.
- `hover_keys=1` grabs the keyboard only while the pointer is over the bar,
  which is what makes `hide_key` work without clicking first.
- A cell with `interval=-1` keeps its command running and takes every line it
  prints, so a script can push updates the moment they happen.
