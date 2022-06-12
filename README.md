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
* `chr.bin.gz`: CHR ROM data (gzip compressed)
* `chr.png`: CHR ROM data as an image
* `clock.asm`: source code (assembles with [ASM6](https://www.romhacking.net/utilities/674/))
* `clock.nes.gz`: assembled program (iNES format, gzip compressed)
* `snap.png`: screenshot

## Technical info
* mapper: NROM
* PRG ROM: 16 KiB
* CHR ROM: 8 KiB
* name table mirroring: vertical
* extra RAM: no
* compatibility: NTSC only (runs too slow on PAL)

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
* start: switch to run mode (hour must be 23 or less)

### Run mode
* Time advances by one second every 60.1 frames.
* The clock moves around the screen to prevent burn-in.
* The cursor is hidden.

Buttons:
* start: switch to adjust mode
