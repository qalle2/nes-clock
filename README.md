# nes-clock
A 24-hour 7-segment clock for the [NES](https://en.wikipedia.org/wiki/Nintendo_Entertainment_System). Runs at 60.1 frames per second. Actual size: PRG ROM 1 KiB, CHR ROM 512 bytes.

![screenshot](clock.png)

Table of contents:
* [List of files](#list-of-files)
* [How to assemble](#how-to-assemble)
* [How to use](#how-to-use)
* [To do](#to-do)

## List of files
* `assemble.sh`: a Linux script that assembles the program (warning: deletes files)
* `chr.bin.gz`: CHR ROM data (gzip compressed)
* `chr-new.png`: a sketch for new CHR data
* `chr.png`: CHR data as an image
* `clock.asm`: source code (ASM6)
* `clock.nes.gz`: assembled program (iNES format, gzip compressed)
* `snap.png`: screenshot

## How to assemble
* get the CHR ROM data:
  * either extract `chr.bin.gz`&hellip;
  * &hellip;or encode it yourself: `python3 nes_chr_encode.py chr.png chr.bin` (you need `nes_chr_encode.py` and its dependencies from my [NES utilities](https://github.com/qalle2/nes-util))
* assemble: `asm6 clock.asm clock.nes`

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

## To do
* make digits 3&times;5 tiles instead of 2&times;4 (use `chr-new.png`)
* use CHR RAM instead of CHR ROM
