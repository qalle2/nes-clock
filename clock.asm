; Clock (NES, ASM6)

; --- Constants ---------------------------------------------------------------

; Notes:
; - segment_buffer: segment tile buffer, i.e., bytes to update to PPU on next
;   VBlank; 6 digits * 3 columns * 5 rows = $5a bytes.
; - digits: digits of time, from tens of hours to ones of seconds; 6 bytes.
; - digit_tiles: tile indexes of digits; 10*16 = $a0 bytes.
; - Boolean variables: $00-$7f = false, $80-$ff = true.

; RAM
segment_buffer  equ $00    ; $5a bytes (see above)
digits          equ $5a    ; 6 bytes (see above)
frame_counter   equ $60    ; frames left in current second (0-61)
clock_running   equ $61    ; is clock running? (boolean)
run_main_loop   equ $62    ; is main loop allowed to run? (boolean)
pad_status      equ $63    ; joypad status
prev_pad_status equ $64    ; previous joypad status
cursor_pos      equ $65    ; cursor position (0-5)
scroll_h        equ $66    ; horizontal scroll value
scroll_v        equ $67    ; vertical   scroll value
moving_right    equ $68    ; clock moving right instead of left? (boolean)
moving_down     equ $69    ; clock moving down  instead of up?   (boolean)
timing          equ $6a    ; 0 = NTSC, 1 = PAL
move_counter    equ $6b    ; counts 0-255 repeatedly (for moving the clock)
digit_tiles     equ $0200  ; $a0 bytes (see above)
sprite_data     equ $0300  ; OAM page ($100 bytes)

; memory-mapped registers
ppu_ctrl        equ $2000
ppu_mask        equ $2001
ppu_status      equ $2002
oam_addr        equ $2003
ppu_scroll      equ $2005
ppu_addr        equ $2006
ppu_data        equ $2007
dmc_freq        equ $4010
oam_dma         equ $4014
snd_chn         equ $4015
joypad1         equ $4016
joypad2         equ $4017

; default (centered) horizontal/vertical scroll value
def_scroll_h    equ  3*8+4
def_scroll_v    equ 12*8+4

; --- iNES header -------------------------------------------------------------

                ; see https://wiki.nesdev.org/w/index.php/INES
                base $0000
                db "NES", $1a            ; file id
                db 1, 1                  ; 16 KiB PRG ROM, 8 KiB CHR ROM
                db %00000001, %00000000  ; NROM mapper, vertical NT mirroring
                pad $0010, $00           ; unused

; --- Initialization ----------------------------------------------------------

                base $c000              ; last 16 KiB of CPU address space

reset           ; initialize the NES
                ; see https://wiki.nesdev.org/w/index.php/Init_code
                sei                     ; ignore IRQs
                cld                     ; disable decimal mode
                ldx #%01000000
                stx joypad2             ; disable APU frame IRQ
                ldx #$ff
                txs                     ; initialize stack pointer
                inx
                stx ppu_ctrl            ; disable NMI
                stx ppu_mask            ; disable rendering
                stx dmc_freq            ; disable DMC IRQs
                stx snd_chn             ; disable sound channels

                jsr wait_vbl_start      ; wait until next VBlank starts
                jsr init_ram            ; initialize main RAM

                jsr wait_vbl_start      ; wait until next VBlank starts
                jsr init_ppu_mem        ; initialize PPU memory

                jsr wait_vbl_start      ; wait until next VBlank starts
                jsr set_ppu_regs        ; set ppu_scroll/ppu_ctrl/ppu_mask
                jmp main_loop           ; start main program

wait_vbl_start  bit ppu_status          ; wait until next VBlank starts
-               lda ppu_status
                bpl -
                rts

init_ram        ; initialize main RAM

                ; clear zero page, hide all sprites
                ; (there's no absolute indexed STX/STY)
                ldy #$00
                lda #$ff
                ldx #0
-               sty $00,x
                sta sprite_data,x
                inx
                bne -

                ; copy initial sprite data
                ldx #(3*4-1)
-               lda init_spr_data,x
                sta sprite_data,x
                dex
                bpl -

                ; set nonzero variables
                lda #def_scroll_h
                sta scroll_h
                lda #def_scroll_v
                sta scroll_v

                ; extract tiles of digits from ROM to RAM
                ; Python equivalent:
                ; for i in range(10*8):
                ;     digit_tiles[i*2]   = digit_tiles_rom[i] >> 4
                ;     digit_tiles[i*2+1] = digit_tiles_rom[i] & 0b00001111
                ;
                ldx #0                  ; source index
                ldy #0                  ; target index
                ;
-               lda digit_tiles_rom,x   ; high nybble to byte
                pha
                lsr a
                lsr a
                lsr a
                lsr a
                sta digit_tiles,y
                iny
                ;
                pla                     ; low nybble to byte
                and #%00001111
                sta digit_tiles,y
                iny
                ;
                inx
                cpx #(10*8)
                bne -

                rts

init_spr_data   ; initial sprite data (Y, tile, attributes, X)
                db 18*8+4-1, $10, %00000000, 4*8+4  ; #0: cursor
                db 11*8-1,   $11, %00000000, 15*8   ; #1: "NTSC" - left half
                db 11*8-1,   $12, %00000000, 16*8   ; #2: "NTSC" - right half

digit_tiles_rom ; Tiles of digits. Each nybble is a tile index.
                ; Each digit is 3*5 tile slots:
                ;     $0  $5  $a
                ;     $1  $6  $b
                ;     $2  $7  $c
                ;     $3  $8  $d
                ;     $4  $9  $e
                ; Slots $6, $8                    : always empty
                ; Slots $1, $3, $5, $7, $9, $b, $d: middle parts of segments
                ; Slots $0, $2, $4, $a, $c, $e    : tips of segments
                ; Slot  $f                        : padding (unused)
                ;
                ;   tiles in slots $0-$f
                ;   -----------------------
                hex 5d 3d 6c 00 0c 9d 3d a0  ; "0"
                hex 00 00 00 00 00 1d 3d 20  ; "1"
                hex 40 5d 6c 0c 0c 9d a0 80  ; "2"
                hex 40 40 4c 0c 0c 9d bd a0  ; "3"
                hex 1d 60 00 0c 00 1d bd 20  ; "4"
                hex 5d 60 4c 0c 0c 80 9d a0  ; "5"
                hex 5d 7d 6c 0c 0c 80 9d a0  ; "6"
                hex 40 00 0c 00 00 9d 3d 20  ; "7"
                hex 5d 7d 6c 0c 0c 9d bd a0  ; "8"
                hex 5d 60 4c 0c 0c 9d bd a0  ; "9"

init_ppu_mem    ; initialize PPU memory

                ; set palette (while still in VBlank)
                ;
                ldy #$3f
                lda #$00
                jsr set_ppu_addr        ; Y*$100+A -> address
                ;
                ldy #8                  ; copy same colors to all subpalettes
--              ldx #0
-               lda palette,x
                sta ppu_data
                inx
                cpx #4
                bne -
                dey
                bne --

                ; clear name & attribute table 0 & 1
                ;
                ldy #$20
                lda #$00
                jsr set_ppu_addr        ; Y*$100+A -> address
                ;
                ldy #8                  ; write $800 * $00
                tax
-               sta ppu_data
                inx
                bne -
                dey
                bne -

                ; print colons between digits
                ;
                ldy #$23                ; PPU address high
                ldx #(4-1)              ; source index
                ;
-               lda colon_addr,x
                jsr set_ppu_addr        ; Y*$100+A -> address
                lda #$0e
                sta ppu_data
                lda #$0f
                sta ppu_data
                dex
                bpl -

                rts

set_ppu_addr    sty ppu_addr            ; Y*$100+A -> address
                sta ppu_addr
                rts

palette         ; copied to all subpalettes
                db $0f                  ; background     (black)
                db $18                  ; dim    segment (dark yellow)
                db $28                  ; bright segment (yellow)
                db $25                  ; unused         (pink)

colon_addr      ; low bytes of PPU addresses of colons
                hex 4e 57 8e 97

; --- Main loop - common ------------------------------------------------------

main_loop       bit run_main_loop       ; wait until NMI routine has set flag
                bpl main_loop

                lsr run_main_loop       ; clear flag

                lda pad_status          ; store previous joypad status
                sta prev_pad_status

                jsr read_joypad         ; read joypad
                jsr write_segbuf        ; write segment tile buffer

                bit clock_running       ; run mode-specific sub and restart
                bmi +                   ; main loop
                jsr main_adj_mode
                jmp main_loop
+               jsr main_run_mode
                jmp main_loop

read_joypad     ; read 1st joypad or Famicom expansion port controller
                ; see https://www.nesdev.org/wiki/Controller_reading_code
                ; bits: A, B, select, start, up, down, left, right

                lda #1
                sta joypad1
                sta pad_status
                lsr a
                sta joypad1

-               lda joypad1
                and #%00000011
                cmp #1
                rol pad_status
                bcc -
                rts

write_segbuf    ; write segment tile buffer
                ; Python equivalent (d = digit index, t = tile index):
                ; for d in range(6):
                ;     for t in range(15):
                ;         segment_buffer[d*15+t] = digit_tiles[digits[d]*16+t]

                ldx #0                  ; source index (digits/digit_tiles)
                ldy #0                  ; target index (segment_buffer)

--              txa                     ; push digits index
                pha
                lda digits,x            ; digit_tiles index -> X
                asl a
                asl a
                asl a
                asl a
                tax

                ; inner loop: copy 3*5 bytes (tiles)
-               lda digit_tiles,x
                sta segment_buffer,y    ; 1 byte wasted (6502 has no STA zp,y)
                inx
                iny
                txa
                and #%00001111
                cmp #%00001111
                bne -

                pla                     ; pull digits index & increment
                tax
                inx
                cpx #6
                bne --
                rts

; --- Main loop - adjust mode -------------------------------------------------

main_adj_mode   ; exit if something was pressed on last frame
                lda prev_pad_status
                bne +

                lda pad_status          ; react to buttons
                asl a
                asl a
                bmi toggle_timing       ; select
                asl a
                bmi try_to_start
                asl a
                bmi incr_digit
                asl a
                bmi decr_digit
                asl a
                bmi cursor_left
                bne cursor_right
+               rts

toggle_timing   lda timing              ; toggle between NTSC and PAL timing
                eor #%00000001
                sta timing
                jmp update_sprites

try_to_start    ; start clock if hour <= 23
                lda digits+0
                cmp #2
                bcc start_clock         ; ends with RTS
                lda digits+1
                cmp #4
                bcc start_clock         ; ends with RTS
                rts

decr_digit      ldx cursor_pos          ; decrement digit at cursor
                dec digits,x
                bpl ++
                lda max_digits,x
                bpl +                   ; unconditional
                ;
incr_digit      ldx cursor_pos          ; increment digit at cursor
                inc digits,x
                lda max_digits,x
                cmp digits,x
                bcs ++
                lda #0
+               sta digits,x
++              rts

cursor_left     dec cursor_pos          ; move cursor left
                bpl update_sprites
                ldx #(6-1)
                bpl +                   ; unconditional
                ;
cursor_right    ldx cursor_pos          ; move cursor right
                inx
                cpx #6
                bne +
                ldx #0
+               stx cursor_pos
                jmp update_sprites

update_sprites  ; update sprites and return to main loop
                ldx cursor_pos          ; cursor X position
                lda cursor_x,x
                sta sprite_data+0+3
                lda timing              ; "NTSC/PAL" tiles
                asl a
                adc #$11                ; carry is always clear
                sta sprite_data+1*4+1
                adc #1                  ; carry is always clear
                sta sprite_data+2*4+1
                rts

cursor_x        db  4*8+4,  8*8+4       ; cursor sprite X positions
                db 13*8+4, 17*8+4
                db 22*8+4, 26*8+4

start_clock     ; start clock and return to main loop
                lda #$ff                ; hide sprites (cursor, "NTSC"/"PAL")
                sta sprite_data+0+0
                sta sprite_data+4+0
                sta sprite_data+2*4+0
                ldx timing              ; restart current second
                lda second_lengths,x
                sta frame_counter
                sec                     ; switch to run mode
                ror clock_running
                rts

; --- Main loop - run mode ----------------------------------------------------

main_run_mode   ; count down; if zero, a second has elapsed
                dec frame_counter
                bne +
                jsr init_frame_cntr
                jsr incr_digits

+               ; if nothing pressed on previous frame and start pressed
                ; on this frame, return to adjust mode
                lda prev_pad_status
                bne +
                lda pad_status
                and #%00010000
                bne stop_clock          ; ends with RTS

+               ; move clock every 2**5 frames
                ; (clock is at bottom right corner of NT0)
                lda move_counter
                and #%00011111
                bne +
                jsr move_clock_horz
                jsr move_clock_vert

+               inc move_counter        ; increment counter
                rts                     ; return to main loop

init_frame_cntr ; reinitialize frame counter; NES frame rates:
                ; https://www.nesdev.org/wiki/Cycle_reference_chart

                ldx timing              ; integer frame count
                lda second_lengths,x
                sta frame_counter
                txa
                bne +

                ; NTSC: extra frame every 10 s, or +1/10 fps on average
                lda digits+5
                beq ++
                rts

+               ; PAL: extra frame every 2 min, or +1/120 fps on average
                lda digits+5
                ora digits+4
                bne +++
                lda digits+3
                lsr a
                bcs +++

++              inc frame_counter       ; add extra frame
+++             rts

incr_digits     ; increment digits

                ldx #(6-1)              ; which digit

-               cpx #1                  ; reset ones of hour if hour = 23
                bne +
                lda digits+0
                cmp #2
                bne +
                lda digits+1
                cmp #3
                beq ++
                ;
+               inc digits,x            ; increment digit; exit if not too big
                lda max_digits,x
                cmp digits,x
                bcs +++
                ;
++              lda #0                  ; reset digit and continue to next one
                sta digits,x
                dex
                bpl -

+++             rts

stop_clock      ; return to adjust mode

                ldx #(2*4)              ; show sprites
-               lda init_spr_data+0,x
                sta sprite_data+0,x
                dex
                dex
                dex
                dex
                bpl -

                lda #def_scroll_h       ; restore default scroll values
                sta scroll_h
                lda #def_scroll_v
                sta scroll_v

                lsr clock_running       ; clear flag
                rts

move_clock_horz ; scroll screen horizontally by 1 pixel

                bit moving_right
                bmi ++

                inc scroll_h            ; move left
                lda scroll_h
                cmp #(6*8)
                bne +
                ror moving_right        ; set flag (carry is always set)
+               rts

++              dec scroll_h            ; move right
                lda scroll_h
                cmp #8
                bne +
                lsr moving_right        ; clear flag
+               rts

move_clock_vert ; scroll screen vertically by 1 pixel

                bit moving_down
                bmi ++

                inc scroll_v            ; move up
                lda scroll_v
                cmp #(23*8)
                bne +
                ror moving_down         ; set flag (carry is always set)
+               rts

++              dec scroll_v            ; move down
                lda scroll_v
                cmp #(2*8)
                bne +
                lsr moving_down         ; clear flag
+               rts

; --- Interrupt routines ------------------------------------------------------

                align $100, $ff         ; for speed

nmi             pha                     ; push A, X, Y
                txa
                pha
                tya
                pha

                bit ppu_status          ; reset ppu_scroll/ppu_addr latch

                lda #$00                ; do sprite DMA
                sta oam_addr
                lda #>sprite_data
                sta oam_dma

                ; print digit segments from buffer
                ; (6*3 vertical slices with 5 tiles each);
                ; instructions executed in the loop: 6*3*19 = 342
                ;
                ldy #(6*3-1)            ; index to seg_upd_addr
                ldx #((6*3-1)*5)        ; index to segment_buffer
                sec
                ;
-               lda #$23                ; set VRAM address
                sta ppu_addr
                lda seg_upd_addr,y
                sta ppu_addr
                ;
                lda segment_buffer+0,x
                sta ppu_data
                lda segment_buffer+1,x
                sta ppu_data
                lda segment_buffer+2,x
                sta ppu_data
                lda segment_buffer+3,x
                sta ppu_data
                lda segment_buffer+4,x
                sta ppu_data
                ;
                txa
                sbc #5                  ; carry is always set
                tax
                ;
                dey
                bpl -

                sec                     ; set flag to let main loop run once
                ror run_main_loop

                jsr set_ppu_regs        ; set ppu_scroll/ppu_ctrl/ppu_mask

                pla                     ; pull Y, X, A
                tay
                pla
                tax
                pla

irq             rti                     ; IRQ unused

seg_upd_addr    ; low bytes of VRAM addresses of first bytes of vertical 5-tile
                ; segment slices (bottom right corner of NT0)
                db 1*32+ 7, 1*32+ 8, 1*32+ 9  ; tens of hour
                db 1*32+11, 1*32+12, 1*32+13  ; ones of hour
                db 1*32+16, 1*32+17, 1*32+18  ; tens of minute
                db 1*32+20, 1*32+21, 1*32+22  ; ones of minute
                db 1*32+25, 1*32+26, 1*32+27  ; tens of second
                db 1*32+29, 1*32+30, 1*32+31  ; ones of second

; --- Subs & arrays used in many places ---------------------------------------

set_ppu_regs    lda scroll_h            ; set scroll value
                sta ppu_scroll
                lda scroll_v
                sta ppu_scroll
                lda #%10000100          ; enable NMI; address autoincrement
                sta ppu_ctrl            ; 32 bytes
                lda #%00011110          ; show background and sprites
                sta ppu_mask
                rts

max_digits      db 2, 9, 5, 9, 5, 9     ; maximum values of individual digits

second_lengths  db 60, 50               ; whole frames/second in NTSC/PAL mode

; --- Interrupt vectors -------------------------------------------------------

                pad $fffa, $ff
                dw nmi, reset, irq      ; IRQ unused

; --- CHR ROM -----------------------------------------------------------------

                base $0000
                incbin "chr.bin"
                pad $2000, $ff
