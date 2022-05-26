; Clock (NES, NTSC, ASM6)

; --- Constants -----------------------------------------------------------------------------------

; note: VRAM buffer = which segments to draw on next VBlank

; RAM
vram_buffer     equ $00    ; VRAM buffer (6 digits * 3 columns * 5 rows = 90 = $5a bytes)
digits          equ $5a    ; digits of time (6 bytes, from tens of hour to ones of minute)
clock_running   equ $60    ; is clock running? (MSB: 0=no, 1=yes)
run_main_loop   equ $61    ; is main loop allowed to run? (MSB: 0=no, 1=yes)
pad_status      equ $62    ; joypad status
prev_pad_status equ $63    ; previous joypad status
cursor_pos      equ $64    ; cursor position (0-5)
frame_counter   equ $65    ; frames left in current second (0-61)
temp            equ $66    ; temporary
sprite_data     equ $0200  ; OAM page ($100 bytes)

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
sound_ctrl      equ $4015
joypad1         equ $4016
joypad2         equ $4017

; colors
color_bg        equ $0f  ; background (black)
color_dim       equ $18  ; dim        (dark yellow)
color_unused    equ $30  ; unused     (white)
color_bright    equ $28  ; bright     (yellow)

tile_dot        equ $01  ; dot (in colons)
tile_cursor     equ $02  ; cursor (up arrow)

; --- iNES header ---------------------------------------------------------------------------------

                ; see https://wiki.nesdev.org/w/index.php/INES
                base $0000
                db "NES", $1a            ; file id
                db 1, 0                  ; 16 KiB PRG ROM, 0 KiB CHR ROM (uses CHR RAM)
                db %00000000, %00000000  ; NROM mapper, horizontal name table mirroring
                pad $0010, $00           ; unused

; --- Initialization ------------------------------------------------------------------------------

                base $c000              ; start of PRG ROM
                pad $fc00, $ff          ; last 1 KiB of CPU address space

reset           ; initialize the NES; see https://wiki.nesdev.org/w/index.php/Init_code
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
                stx sound_ctrl          ; disable sound channels

                jsr wait_vbl_start      ; wait until next VBlank starts

                ldy #$00                ; fill zero page with $00 and sprite page with $ff
                lda #$ff                ; note: 6502 has no absolute indexed STX/STY
                ldx #0
-               sty $00,x
                sta sprite_data,x
                inx
                bne -

                ldx #0                  ; copy initial sprite data
-               lda init_spr_data,x
                sta sprite_data,x
                inx
                cpx #(5*4)
                bne -

                jsr wait_vbl_start      ; wait until next VBlank starts

                ldy #$3f                ; set up palette (while still in VBlank)
                jsr set_ppu_addr_pg     ; 0 -> A; Y*$100 + A -> address
                ;
                ldy #8                  ; copy same 4 colors backwards to all subpalettes
--              ldx #(4-1)
-               lda palette,x
                sta ppu_data
                dex
                bpl -
                dey
                bne --

                ldy #$00                ; copy pattern table data
                jsr set_ppu_addr_pg     ; 0 -> A; Y*$100 + A -> address
                ;
-               lda pt_data,y
                sta ppu_data
                iny
                bne -

                ldy #$20                ; clear name/attribute table 0 (4*256 bytes)
                jsr set_ppu_addr_pg     ; 0 -> A; Y*$100 + A -> address
                ;
                ldy #4
--              tax
-               sta ppu_data
                inx
                bne -
                dey
                bne --

                jsr wait_vbl_start      ; wait until next VBlank starts
                jsr set_ppu_regs        ; set ppu_scroll/ppu_ctrl/ppu_mask
                jmp main_loop

wait_vbl_start  bit ppu_status          ; wait until next VBlank starts
-               lda ppu_status
                bpl -
                rts

init_spr_data   ; initial sprite data (Y, tile, attributes, X)
                db $6a-1, tile_dot,    %00000000, $54  ; #0: top    dot between hour   & minute
                db $76-1, tile_dot,    %00000000, $54  ; #1: bottom dot between hour   & minute
                db $6a-1, tile_dot,    %00000000, $a4  ; #2: top    dot between minute & second
                db $76-1, tile_dot,    %00000000, $a4  ; #3: bottom dot between minute & second
                db $90-1, tile_cursor, %00000000, $18  ; #4: cursor

palette         db color_bright, color_unused, color_dim, color_bg  ; backwards to all subpalettes

pt_data         ; pattern table data
                ; notes:
                ; - we use colors 0/1/3 instead 0/1/2 to achieve better compression
                ; - top tip of segment is at bottom of tile and vice versa;
                ;   same for left/right tip
                ;
                hex 0000000000000000 0000000000000000  ; tile $00: blank
                hex 00003c3c3c3c0000 0000183c3c180000  ; tile $01: dot (used in colons)
                hex 183c7eff18181818 00183c7e18181800  ; tile $02: cursor (up arrow)
                hex 00ffffffffffff00 00ffffffffffff00  ; tile $03: middle of horizontal segment
                hex 7e7e7e7e7e7e7e7e 7e7e7e7e7e7e7e7e  ; tile $04: middle of vertical segment
                hex 0000000000183c7e 000000000000183c  ; tile $05: seg tip - top
                hex 7e3c180000000000 3c18000000000000  ; tile $06: seg tip - bottom
                hex 7e3c180000183c7e 3c1800000000183c  ; tile $07: seg tip - bottom & top
                hex 0001030707030100 0000010303010000  ; tile $08: seg tip - left
                hex 00010307071b3d7e 000001030301183c  ; tile $09: seg tip - left & top
                hex 7e3d1b0707030100 3c18010303010000  ; tile $0a: seg tip - left & bottom
                hex 7e3d1b07071b3d7e 3c1801030301183c  ; tile $0b: seg tip - left & bottom & top
                hex 0080c0e0e0c08000 000080c0c0800000  ; tile $0c: seg tip - right
                hex 0080c0e0e0d8bc7e 000080c0c080183c  ; tile $0d: seg tip - right & top
                hex 7ebcd8e0e0c08000 3c1880c0c0800000  ; tile $0e: seg tip - right & bottom
                hex 7ebcd8e0e0d8bc7e 3c1880c0c080183c  ; tile $0f: seg tip - right & bottom & top

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

                ; set up VRAM buffer
                ;
                lda digits+0            ; tens of hour
                ldx #0*3*5
                jsr digit_to_vrbuf
                ;
                lda digits+1            ; ones of hour
                ldx #1*3*5
                jsr digit_to_vrbuf
                ;
                lda digits+2            ; tens of minute
                ldx #2*3*5
                jsr digit_to_vrbuf
                ;
                lda digits+3            ; ones of minute
                ldx #3*3*5
                jsr digit_to_vrbuf
                ;
                lda digits+4            ; tens of second
                ldx #4*3*5
                jsr digit_to_vrbuf
                ;
                lda digits+5            ; ones of second
                ldx #5*3*5
                jsr digit_to_vrbuf

                bit clock_running       ; run mode-specific code
                bmi +
                jmp main_adj_mode
+               jmp main_run_mode

digit_to_vrbuf  asl a                   ; read 15 (3*5) nybbles from segment_tiles,
                asl a                   ; write 15 tiles to VRAM buffer
                asl a                   ; in: A = value of digit (0-9), X = target index start
                tay
                ;
-               lda segment_tiles,y
                lsr a
                lsr a
                lsr a
                lsr a
                sta vram_buffer,x
                inx
                ;
                tya                     ; exit in the middle of 8th round
                and #%00000111
                cmp #%00000111
                beq +
                ;
                lda segment_tiles,y
                and #%00001111
                sta vram_buffer,x
                inx
                ;
                iny
                bpl -                   ; unconditional
                ;
+               rts

segment_tiles   ; Digits are 3*5 tiles. Tile slots: 0 = top left, 4 = bottom left, etc.
                ; Slots 6 & 8 are always empty; slot 15 is for padding only.
                ; Nybbles = tiles in slots 0-15 for each digit.
                ;
                hex 94 74 a3 00 03 d4 74 e0  ; "0"
                hex 00 00 00 00 00 54 74 60  ; "1"
                hex 80 94 a3 03 03 d4 e0 c0  ; "2"
                hex 80 80 83 03 03 d4 f4 e0  ; "3"
                hex 54 a0 00 03 00 54 f4 60  ; "4"
                hex 94 a0 83 03 03 c0 d4 e0  ; "5"
                hex 94 b4 a3 03 03 c0 d4 e0  ; "6"
                hex 80 00 03 00 00 d4 74 60  ; "7"
                hex 94 b4 a3 03 03 d4 f4 e0  ; "8"
                hex 94 a0 83 03 03 d4 f4 e0  ; "9"

; --- Main loop - adjust mode ---------------------------------------------------------------------

main_adj_mode   lda prev_pad_status     ; ignore buttons if something was pressed on last frame
                bne buttons_done

                ldx cursor_pos          ; react to buttons
                ldy digits,x
                lda pad_status
                lsr a
                bcs cursor_right
                lsr a
                bcs cursor_left
                lsr a
                bcs decrement_digit
                lsr a
                bcs increment_digit
                lsr a
                bcs start_clock
                bcc buttons_done        ; unconditional

cursor_left     dex
                bpl +
                ldx #(6-1)
                bpl +                   ; unconditional
cursor_right    inx
                cpx #6
                bne +
                ldx #0
+               stx cursor_pos
                jmp buttons_done

decrement_digit dey
                bpl ++
                lda max_digits,x
                tay
                bpl ++                  ; unconditional
increment_digit tya
                cmp max_digits,x
                bne +
                ldy #0
                beq ++                  ; unconditional
+               iny
++              sty digits,x
                bpl buttons_done        ; unconditional

start_clock     lda digits+0            ; start clock if hour <= 23
                cmp #2
                bcc +
                lda digits+1
                cmp #4
                bcs buttons_done
+               lda #$ff                ; hide cursor sprite
                sta sprite_data+4*4+0
                lda #60                 ; restart current second
                sta frame_counter
                sec                     ; set flag
                ror clock_running

buttons_done    ldx cursor_pos          ; update cursor sprite X
                lda cursor_x,x
                sta sprite_data+4*4+3
                jmp main_loop           ; return to common main loop

cursor_x        hex 18 40 68 90 b8 e0   ; cursor sprite X positions

; --- Main loop - run mode ------------------------------------------------------------------------

main_run_mode   dec frame_counter       ; count down; if zero, a second has elapsed
                bne digit_incr_done

                lda #60                 ; reinitialize frame counter
                sta frame_counter       ; 60.1 on average (60 + an extra frame every 10 seconds)
                lda digits+5            ; should be 60.0988 according to NESDev wiki
                bne +
                inc frame_counter

+               ldx #5                  ; increment digits (X = which digit)
-               cpx #1                  ; special logic: reset ones of hour if hour = 23
                bne +
                lda digits+0
                cmp #2
                bne +
                lda digits+1
                cmp #3
                beq ++
+               inc digits,x            ; the usual logic: increment digit; if too large, zero it
                lda max_digits,x        ; and continue to next digit, otherwise exit
                cmp digits,x
                bcs digit_incr_done
++              lda #0
                sta digits,x
                dex
                bpl -

digit_incr_done lda prev_pad_status     ; if nothing pressed on previous frame
                bne +
                lda pad_status          ; and start pressed on this frame
                and #%00010000
                beq +
                lda init_spr_data+4*4   ; then show cursor
                sta sprite_data+4*4+0
                lsr clock_running       ; and clear flag

+               jmp main_loop           ; return to common main loop

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

                ; print digit segments from buffer (6*3 vertical slices with 5 tiles each)
                ; TODO: is too slow? assuming 4 cycles/instruction: 6*3*17*4 = ~1,200 cycles
                ;
                ldy #(6*3-1)            ; Y = vram_addr_lo index, X = vram_buffer index
                ;
-               lda #$21                ; set VRAM address
                sta ppu_addr
                lda vram_addr_lo,y
                sta ppu_addr
                ;
                ldx times5,y
                ;
                lda vram_buffer+0,x
                sta ppu_data
                lda vram_buffer+1,x
                sta ppu_data
                lda vram_buffer+2,x
                sta ppu_data
                lda vram_buffer+3,x
                sta ppu_data
                lda vram_buffer+4,x
                sta ppu_data
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

irq             rti                     ; note: IRQ unused

vram_addr_lo    ; low bytes of VRAM addresses of first bytes of vertical 5-tile slices
                db 4*32+ 2, 4*32+ 3, 4*32+ 4  ; tens of hour
                db 4*32+ 7, 4*32+ 8, 4*32+ 9  ; ones of hour
                db 4*32+12, 4*32+13, 4*32+14  ; tens of minute
                db 4*32+17, 4*32+18, 4*32+19  ; ones of minute
                db 4*32+22, 4*32+23, 4*32+24  ; tens of second
                db 4*32+27, 4*32+28, 4*32+29  ; ones of second

times5          db  0,  5, 10, 15, 20, 25  ; multiply 0...17 by 5
                db 30, 35, 40, 45, 50, 55  ; (vram_addr_lo index -> vram_buffer index)
                db 60, 65, 70, 75, 80, 85

; --- Subs & arrays used in many places -----------------------------------------------------------

set_ppu_addr_pg lda #$00                ; clear A and set PPU address page from Y
set_ppu_addr    sty ppu_addr            ; set PPU address from Y and A
                sta ppu_addr
                rts

set_ppu_regs    lda #$00                ; reset PPU scroll
                sta ppu_scroll
                sta ppu_scroll
                lda #%10000100          ; enable NMI; address autoincrement 32 bytes
                sta ppu_ctrl
                lda #%00011110          ; show background and sprites
                sta ppu_mask
                rts

max_digits      db 2, 9, 5, 9, 5, 9     ; maximum values of digits

; --- Interrupt vectors ---------------------------------------------------------------------------

                pad $fffa, $ff
                dw nmi, reset, irq      ; note: IRQ unused
