; Clock (NES, NTSC, ASM6)

; --- Constants -----------------------------------------------------------------------------------

; note: segment_buffer = bytes to update to PPU on next VBlank

; RAM
segment_buffer  equ $00    ; segment tile buffer (6 digits * 3 columns * 5 rows = 90 = $5a bytes)
digits          equ $5a    ; digits of time (6 bytes, from tens of hour to ones of second)
frame_counter   equ $60    ; frames left in current second (0-61)
clock_running   equ $61    ; is clock running? (MSB: 0=no, 1=yes)
run_main_loop   equ $62    ; is main loop allowed to run? (MSB: 0=no, 1=yes)
pad_status      equ $63    ; joypad status
prev_pad_status equ $64    ; previous joypad status
cursor_pos      equ $65    ; cursor position (0-5)
scroll_h        equ $66    ; horizontal scroll value
scroll_v        equ $67    ; vertical   scroll value
moving_right    equ $68    ; clock moving right instead of left? (MSB: 0=no, 1=yes)
moving_down     equ $69    ; clock moving down  instead of up?   (MSB: 0=no, 1=yes)
move_counter    equ $6a    ; counts 0-255 repeatedly (used for moving the clock)
digit_tiles     equ $0200  ; tiles of digits (10*16 = $a0 bytes; byte = tile index)
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

; misc
def_scroll_h    equ  3*8+4  ; default (centered) horizontal scroll value
def_scroll_v    equ 12*8+4  ; default (centered) vertical   scroll value
move_spd        equ 5       ; movement speed in run mode (0 = fastest, 8 = slowest)

; colors
color_bg        equ $0f     ; background       (black)
color_dim       equ $18     ; segment - dim    (dark yellow)
color_bright    equ $28     ; segment - bright (yellow)
color_unused    equ $25     ; unused           (pink)

; --- iNES header ---------------------------------------------------------------------------------

                ; see https://wiki.nesdev.org/w/index.php/INES
                ;
                base $0000
                db "NES", $1a            ; file id
                db 1, 1                  ; 16 KiB PRG ROM, 8 KiB CHR ROM
                db %00000001, %00000000  ; NROM mapper, vertical name table mirroring
                pad $0010, $00           ; unused

; --- Initialization ------------------------------------------------------------------------------

                base $c000              ; last 16 KiB of CPU address space

reset           ; initialize the NES; see https://wiki.nesdev.org/w/index.php/Init_code
                ;
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

                ldy #$00                ; fill zero page with $00 and sprite page with $ff
                lda #$ff                ; note: 6502 has no absolute indexed STX/STY
                ldx #0
-               sty $00,x
                sta sprite_data,x
                inx
                bne -

                ldx #(4-1)              ; copy initial sprite data
-               lda init_spr_data,x
                sta sprite_data,x
                dex
                bpl -

                lda #def_scroll_h       ; init nonzero variables
                sta scroll_h
                lda #def_scroll_v
                sta scroll_v

                ldx #0                  ; extract digit_tiles_rom array to RAM
                ldy #0                  ; X/Y = source/target index
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

                jsr wait_vbl_start      ; wait until next VBlank starts

                ldy #$3f                ; set up palette (while still in VBlank)
                jsr set_ppu_addr_pg     ; 0 -> A; Y*$100 + A -> address
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

                ; clear name & attribute table 0 & 1 (both because we scroll the screen)
                ;
                ldy #$20                ; VRAM address $2000
                jsr set_ppu_addr_pg     ; 0 -> A; Y*$100 + A -> address
                ;
                ldy #8                  ; write $800 * $00
                tax
-               sta ppu_data
                inx
                bne -
                dey
                bne -

                ldy #$23                ; print colons between digits
                ldx #(4-1)              ; X = source index, Y = PPU address high
                ;
-               lda colon_addr,x
                jsr set_ppu_addr        ; Y*$100 + A -> address
                lda #$0e
                sta ppu_data
                lda #$0f
                sta ppu_data
                ;
                dex
                bpl -

                jsr wait_vbl_start      ; wait until next VBlank starts
                jsr set_ppu_regs        ; set ppu_scroll/ppu_ctrl/ppu_mask
                jmp main_loop

wait_vbl_start  bit ppu_status          ; wait until next VBlank starts
-               lda ppu_status
                bpl -
                rts

init_spr_data   ; initial sprite data (Y, tile, attributes, X)
                db 18*8+4-1, $10, %00000000, 4*8+4  ; cursor

digit_tiles_rom ; Tiles of digits. Each nybble is a tile index. Each digit is 3*5 tile slots:
                ;     $0 $5 $a
                ;     $1 $6 $b
                ;     $2 $7 $c
                ;     $3 $8 $d
                ;     $4 $9 $e
                ; Tile slots $6, $8                    : always empty
                ; Tile slots $1, $3, $5, $7, $9, $b, $d: middle parts of segments
                ; Tile slots $0, $2, $4, $a, $c, $e    : tips of segments
                ; Tile slot  $f                        : padding (unused)
                ;
                ;   01 23 45 67 89 ab cd ef  <- tile slot (hexadecimal)
                ;   -- -- -- -- -- -- -- --
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

palette         db color_bg, color_dim, color_bright, color_unused  ; copied to all subpalettes

colon_addr      hex 4e 57 8e 97         ; low bytes of PPU addresses of colons

; --- Main loop - common --------------------------------------------------------------------------

main_loop       bit run_main_loop       ; wait until NMI routine has set flag
                bpl main_loop
                ;
                lsr run_main_loop       ; clear flag

                lda pad_status          ; store previous joypad status
                sta prev_pad_status
                ;
                lda #1                  ; read joypad
                sta joypad1             ; (bits: A, B, select, start, up, down, left, right)
                sta pad_status
                lsr a
                sta joypad1
-               lda joypad1
                lsr a
                rol pad_status
                bcc -

                ; set up segment tile buffer
                ;
                ldy #0                  ; source index (digits/digit_tiles)
                ldx #0                  ; target index (segment_buffer)
                ;
--              tya                     ; push digits index
                pha
                lda digits,y            ; digit_tiles index -> Y
                asl a                   ; (6502 has no LDA/STA zp,y so we waste 1 byte)
                asl a
                asl a
                asl a
                tay
                ;
-               lda digit_tiles,y       ; inner loop: copy first 3*5 bytes (tiles) from
                sta segment_buffer,x    ; digit_tiles to segment_buffer
                iny
                inx
                tya
                and #%00001111
                cmp #%00001111
                bne -
                ;
                pla                     ; pull digits index & increment
                tay
                iny
                cpy #6
                bne --

                bit clock_running       ; run mode-specific code
                bpl main_adj_mode
                jmp main_run_mode

; --- Main loop - adjust mode ---------------------------------------------------------------------

main_adj_mode   lda prev_pad_status     ; ignore buttons if something was pressed on last frame
                bne buttons_done

                ldx cursor_pos          ; react to buttons
                lda pad_status
                ;
                lsr a
                bcs cursor_right        ; d-pad right
                lsr a
                bcs cursor_left         ; d-pad left
                lsr a
                bcs dec_digit           ; d-pad down
                lsr a
                bcs inc_digit           ; d-pad up
                lsr a
                bcs start_clock         ; start button
                ;
                bcc buttons_done        ; unconditional

cursor_left     dex                     ; move cursor left
                bpl +
                ldx #(6-1)
                bpl +                   ; unconditional
                ;
cursor_right    inx                     ; move cursor right
                cpx #6
                bne +
                ldx #0
+               stx cursor_pos
                jmp buttons_done

dec_digit       dec digits,x            ; decrement digit at cursor
                bpl buttons_done
                lda max_digits,x
                bpl +                   ; unconditional
                ;
inc_digit       inc digits,x            ; increment digit at cursor
                lda max_digits,x
                cmp digits,x
                bcs buttons_done
                lda #0
+               sta digits,x
                bpl buttons_done        ; unconditional

start_clock     lda digits+0            ; if hour <= 23...
                cmp #2
                bcc +
                lda digits+1
                cmp #4
                bcs buttons_done
                ;
+               lda #$ff                ; hide cursor sprite
                sta sprite_data+0
                lda #60                 ; restart current second
                sta frame_counter
                sec                     ; set flag to switch to run mode
                ror clock_running

buttons_done    ldx cursor_pos          ; update X position of cursor sprite
                lda cursor_x,x
                sta sprite_data+3
                jmp main_loop           ; return to common main loop

cursor_x        db  4*8+4,  8*8+4       ; cursor sprite X positions
                db 13*8+4, 17*8+4
                db 22*8+4, 26*8+4

; --- Main loop - run mode ------------------------------------------------------------------------

main_run_mode   dec frame_counter       ; count down; if zero, a second has elapsed
                bne time_math_done

                lda #60                 ; reinitialize frame counter
                sta frame_counter       ; 60.1 on average (60 + an extra frame every 10 seconds)
                lda digits+5            ; should be 60.0988 according to NESDev wiki
                bne +
                inc frame_counter

+               ldx #(6-1)              ; increment digits (X = which digit)
                ;
-               cpx #1                  ; special logic: reset ones of hour if hour = 23
                bne +
                lda digits+0
                cmp #2
                bne +
                lda digits+1
                cmp #3
                beq ++
                ;
+               inc digits,x            ; the usual logic: increment digit; if too large, zero it
                lda max_digits,x        ; and continue to next digit, otherwise exit
                cmp digits,x
                bcs time_math_done
                ;
++              lda #0
                sta digits,x
                dex
                bpl -

time_math_done  lda prev_pad_status     ; if nothing pressed on previous frame and start pressed
                bne start_chk_done      ; on this frame...
                lda pad_status
                and #%00010000
                beq start_chk_done
                ;
                lda init_spr_data+0     ; show cursor
                sta sprite_data+0
                lda #def_scroll_h       ; restore default scroll values
                sta scroll_h
                lda #def_scroll_v
                sta scroll_v
                lsr clock_running       ; clear flag to switch to adjust mode

start_chk_done  lda move_counter        ; move clock by 1 pixel every 2**move_spd frames
                and #((1<<move_spd)-1)  ; (clock is at bottom right corner of NT0)
                bne vert_move_done

                bit moving_right        ; move clock horizontally
                bmi +
                ;
                inc scroll_h            ; move clock left
                lda scroll_h
                cmp #(7*8)
                bne horiz_move_done
                ror moving_right        ; set flag (carry is always set)
                bne horiz_move_done     ; unconditional
                ;
+               dec scroll_h            ; move clock right
                bne horiz_move_done
                lsr moving_right        ; clear flag

horiz_move_done bit moving_down         ; move clock vertically
                bmi +
                ;
                inc scroll_v            ; move clock up
                lda scroll_v
                cmp #(24*8)
                bne vert_move_done
                ror moving_down         ; set flag (carry is always set)
                bne vert_move_done      ; unconditional
                ;
+               dec scroll_v            ; move clock down
                lda scroll_v
                cmp #(1*8)
                bne vert_move_done
                lsr moving_down         ; clear flag

vert_move_done  inc move_counter        ; increment counter
                jmp main_loop           ; return to common main loop

; --- Interrupt routines --------------------------------------------------------------------------

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

                ; print digit segments from buffer (6*3 vertical slices with 5 tiles each);
                ; instructions executed in the loop: 6*3*20 = 360
                ;
                ldy #(6*3-1)            ; index to seg_upd_addr
                ldx #((6*3-1)*5)        ; index to segment_buffer
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
                sec
                sbc #5
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

seg_upd_addr    ; low bytes of VRAM addresses of first bytes of vertical 5-tile segment slices
                ; (bottom right corner of NT0)
                ;
                db 1*32+ 7, 1*32+ 8, 1*32+ 9  ; tens of hour
                db 1*32+11, 1*32+12, 1*32+13  ; ones of hour
                db 1*32+16, 1*32+17, 1*32+18  ; tens of minute
                db 1*32+20, 1*32+21, 1*32+22  ; ones of minute
                db 1*32+25, 1*32+26, 1*32+27  ; tens of second
                db 1*32+29, 1*32+30, 1*32+31  ; ones of second

; --- Subs & arrays used in many places -----------------------------------------------------------

set_ppu_addr_pg lda #$00                ; clear A and set PPU address page from Y
set_ppu_addr    sty ppu_addr            ; set PPU address from Y and A
                sta ppu_addr
                rts

set_ppu_regs    lda scroll_h            ; set scroll value
                sta ppu_scroll
                lda scroll_v
                sta ppu_scroll
                lda #%10000100          ; enable NMI; address autoincrement 32 bytes
                sta ppu_ctrl
                lda #%00011110          ; show background and sprites
                sta ppu_mask
                rts

max_digits      db 2, 9, 5, 9, 5, 9     ; maximum values of individual digits

; --- Interrupt vectors ---------------------------------------------------------------------------

                pad $fffa, $ff
                dw nmi, reset, irq      ; IRQ unused

; --- CHR ROM -------------------------------------------------------------------------------------

                base $0000
                incbin "chr.bin"
                pad $2000, $ff
