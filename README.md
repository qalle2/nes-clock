# nes-clock
A 24-hour 7-segment clock for the [NES](https://en.wikipedia.org/wiki/Nintendo_Entertainment_System). Assembles with [ASM6](https://www.romhacking.net/utilities/674/).

![screenshot](snap.png)

Table of contents:
* [List of files](#list-of-files)
* [Technical info](#technical-info)
  * [Adjust mode](#adjust-mode)
  * [Run mode](#run-mode)
* [How to use](#how-to-use)
* [To do](#to-do)

## List of files
* `assemble.sh`: a Linux script that assembles the program (warning: deletes files)
* `clock.asm`: source code (ASM6)
* `clock.nes.gz`: assembled program (iNES format, gzip compressed)
* `hexdump.py`: creates `hexdump.txt`
* `hexdump.txt`: assembled program in hexadecimal
* `snap.png`: screenshot

## Technical info
* mapper: NROM
* PRG ROM: 16 KiB (only 1 KiB is actually used)
* CHR ROM: 0 KiB (uses CHR RAM)
* name table mirroring: vertical
* extra RAM: no
* compatibility: NTSC only (the clock runs at 60.1 fps)

## How to use
There are two modes.

### Adjust mode
* The program starts in this mode.
* Time does not advance.
* Cursor (up arrow) is visible.

Buttons:
* left/right: move cursor
* up/down: change digit at cursor
* start: switch to run mode (hour must be 23 or less)
* select: change palette

### Run mode
* Time advances.
* Cursor is hidden.

Buttons:
* start: switch to adjust mode
* select: change palette
