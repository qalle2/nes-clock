# nes-clock
A 24-hour 7-segment clock for the [NES](https://en.wikipedia.org/wiki/Nintendo_Entertainment_System). Assembles with [ASM6](https://www.romhacking.net/utilities/674/).

![screenshot](snap.png)

Table of contents:
* [List of files](#list-of-files)
* [Technical info](#technical-info)
* [How to use](#how-to-use)
* [To do](#to-do)

## List of files
* `assemble.sh`: a Linux script that assembles the program (warning: deletes files)
* `clock.asm`: source code (ASM6)
* `clock.nes.gz`: assembled program (iNES format, gzip compressed)
* `snap.png`: screenshot

## Technical info
* mapper: NROM
* PRG ROM: 16 KiB (only 1 KiB is actually used)
* CHR ROM: 0 KiB (uses CHR RAM)
* name table mirroring: does not matter
* extra RAM: no
* compatibility: NTSC only (the clock runs at 60.1 fps)

## How to use
There are two modes:
* adjust mode:
  * program starts in this mode
  * time does not advance
  * cursor (up arrow) is visible
  * press left/right to move cursor
  * press up/down to change digit at cursor
  * press start to switch to run mode (hour must be 23 or less)
* run mode:
  * time advances
  * cursor is hidden
  * press start to switch to adjust mode
