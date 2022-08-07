# nes-clock
A 24-hour 7-segment clock for the [NES](https://en.wikipedia.org/wiki/Nintendo_Entertainment_System).

![screenshot](snap.png)

Table of contents:
* [List of files](#list-of-files)
* [Technical info](#technical-info)
* [How to use](#how-to-use)
  * [Adjust mode](#adjust-mode)
  * [Run mode](#run-mode)

## List of files
* `assemble.sh`: a Linux script that assembles the program (warning: deletes files)
* `chr.bin.gz`: CHR data (gzip compressed)
* `chr.png`: CHR data as an image (can be encoded with `nes_chr_encode.py` from [my NES utilities](https://github.com/qalle2/nes-util))
* `clock.asm`: source code (assembles with [ASM6](https://www.romhacking.net/utilities/674/))
* `clock.nes.gz`: assembled program (iNES format, gzip compressed)
* `snap.png`: screenshot

## Technical info
* mapper: NROM
* PRG ROM: 16 KiB
* CHR ROM: 8 KiB
* name table mirroring: vertical
* compatibility: NTSC &amp; PAL

## How to use
There are two modes.

### Adjust mode
* The program starts in this mode.
* Time does not advance.
* The clock is at the center of the screen.
* The cursor (up arrow) is visible.

Buttons:
* left/right: move cursor
* up/down: change digit at cursor
* select: toggle between NTSC and PAL timing
* start: switch to run mode (hour must be 23 or less)

### Run mode
* If using NTSC timing, time advances by one second every 60.1 frames.
* If using PAL timing, time advances by one second every 50.008333&hellip; frames.
* The clock moves around the screen to prevent burn-in.
* The cursor is hidden.

Buttons:
* start: return to adjust mode
