;; -*- mode: rgbds; -*-
INCLUDE "hardware.inc"
INCLUDE "engine.inc"

; rst vectors are currently unused
SECTION "rst00",ROM0[0]
    ret

SECTION "rst08",ROM0[8]
    ret

SECTION "rst10",ROM0[$10]
    ret

SECTION "rst18",ROM0[$18]
    ret

SECTION "rst20",ROM0[$20]
    ret

SECTION "rst30",ROM0[$30]
    ret

SECTION "rst38",ROM0[$38]
    ret

SECTION "vblank",ROM0[$40]
    reti
SECTION "lcdc",ROM0[$48]
    reti
SECTION "timer",ROM0[$50]
    reti
SECTION "serial",ROM0[$58]
    reti
SECTION "joypad",ROM0[$60]
    reti

SECTION "romheader",ROM0[$100]
    nop
    jp _start

SECTION "start",ROM0[$150]

_start:
    nop
    di
    ld sp, $fffe

; Starts on Bank 1 for tiles and pallettes.

; Disable LCD during initial VRAM writes.
    ld a, [rLCDC]
    res 7, a
    ld [rLCDC], a

; Reset pallete
    ld a, %11100100
    ld [rBGP], a
    ld [rOBP0], a

; Setup Pallette
    ld hl, BGPal
    ld a, $00
    call loadBGPal

;    ld hl, BGPalAlt
;    ld a, $01
;    call loadBGPal

; Reset scrolling
    ld a, 0
    ld [rSCX], a
    ld [rSCY], a

; Turn off sound
    ld [rNR52], a

    ld hl, TileStart
    ld de, _VRAM+$200  ; Font starts at $8200
    ld bc, TileEnd - TileStart
    call memcpy

; Reenable LCD after VRAM writes.
    ld a, [rLCDC]
    set 7, a
    ld [rLCDC], a

; Switch to Bank 2 for sound fns.
    ld a,$02
    ld [rROMB0],a
    call main
    halt

SECTION "main", ROMX,BANK[2]
main:
;; Setup sound system
    ld a,  %10000000 ; Set bit 7 to enable sound.
    ld [rNR52], a
    ld a,  %01110111 ; Set left/right volume to 7
    ld [rNR50], a
    ld a,  %00010001 ; Set Sound 1 on left and right.
    ld [rNR51], a

;; Setup channel 1
    ld a,  %01000000 ; Set 50% Duty cycle and sound length 0.
    ld [rNR11], a
    ld a,  %11110000 ; Max envelope
    ld [rNR12], a

;; Copy song into RAM
    ld hl, DefaultSong
    ld de, WorkingSong
    ld bc, DefaultSongEnd - DefaultSong
    call memcpy

    ld hl, DefaultBeat
    ld de, WorkingBeat
    ld bc, DefaultBeatEnd - DefaultBeat
    call memcpy

    ld a, 0
    ld [NoteIndex], a

;;; Start of main loop
;; Display Song
.dispStart
    ld e, 0  ; Start in first column.
    ld hl, WorkingSong
.dispLoop
    ld a,  [hli] ; load Note Code from Song
    cp $ff       ; Check for end of sequence.
    jr z, .dispEnd

    ld d, e

    call dispNote


    ld a, e

    push hl

    push bc
    ld h, 0
    ld l, a
    REPT 5
    add hl, hl
    ENDR
    ld bc, _SCRN0
    add hl, bc   ; HL Contains screen offset
    pop bc

    ld a, [NoteIndex] ; Check if current note
    cp e
    jr nz, .notCurrentNote
    ld a, $7F
    jr .printArrow
.notCurrentNote
    ld a, $00
.printArrow      ; A contains signal character

    wait_lcd
    ld [hl], a   ; Put character at screen offset
    pop hl

    inc e
    jr .dispLoop

.dispEnd

.getKey	 ; Stall on Keypress
    get_key get_key_ABKEYS
    jr nz, .keyPressAB
    get_key get_key_DPAD
    jr nz, .keyPressDPAD
    jp .getKey
.keyPressAB

    bit 2, a
    call nz, nextNote

    bit 3, a
    call nz, playSong

    wait_div 20, $fe
    jp .dispStart

.keyPressDPAD
    bit 0, a
    call nz, incOctave

    bit 1, a
    call nz, incNote

    wait_div 20, $fe

    jp .dispStart
    ret


SECTION "sndfns", ROMX,BANK[2]

nextNote:
   push hl
   push hl

   ld a, [NoteIndex]
   inc a
   cp (DefaultSongEnd - DefaultSong) - 1
   jp nz, .noOverFlow

.overFlow
   ld a, 0

.noOverFlow
   ld [NoteIndex], a

   pop hl
   pop af
   ret

incOctave:
   push af
   push bc
   push hl

   ld a, [NoteIndex]
   ld hl, WorkingSong
   ld b, 0
   ld c, a
   add hl, bc ; HL now contains index of current note.
   ld a, [hl]

   add a, $10
   bit 7, a
   jp z, .noOverFlow

.overFlow
   and $0f
   xor $30

.noOverFlow
   ld [hl], a

   pop hl
   pop bc
   pop af
   ret

incNote:
   push af
   push bc
   push hl

   ld a, [NoteIndex]
   ld hl, WorkingSong
   ld b, 0
   ld c, a
   add hl, bc ; HL now contains index of current note.
   ld a, [hl]

   inc a
   bit 3, a
   jp nz, .overFlow
   bit 2, a
   jp z, .noOverflow
   bit 1, a
   jp z, .noOverflow
   bit 0, a
   jp z, .noOverflow

.overFlow
   and $f0

.noOverflow
   ld [hl], a

   pop hl
   pop bc
   pop af
   ret

playSong:

   push af
   push de
   push hl
   ld hl, WorkingSong

   ld e, 0
.playLoop
    ld a,  [hli] ; load Note Code from Song
    cp $ff       ; Check for end of sequence.
    jr z, .playEnd

    call playNote
    inc e

    jr .playLoop
.playEnd

    pop hl
    pop de
    pop af
    ret

dispNote:
;;; Display note at offset E.
    push af
    push bc
    push de
    push hl

;; Display Note on Screen
    ld hl, WorkingSong
    ld b, 0
    ld c, e
    add hl, bc ; HL now contains index of current note.
    ld a, [hl]
    and $07
    ld hl, NoteTbl
    ld b, 0
    ld c, a
    add hl, bc   ; HL Contains note table index
    ld a, [hl]   ; A contains note character

    ld h, 0
    ld l, e
    REPT 5
    add hl, hl
    ENDR
    inc hl
    ld bc, _SCRN0
    add hl, bc   ; HL Contains screen offset
    wait_lcd
    ld [hl], a   ; Put character at screen offset

;; Display Octave on Screen
    ld hl, WorkingSong
    ld b, 0
    ld c, e
    add hl, bc ; HL now contains index of current note.
    ld a, [hl]
    swap a
    and $07
    ld hl, OctvTbl
    ld b, 0
    ld c, a
    add hl, bc   ; HL Contains octave table index
    ld a, [hl]   ; A contains octave character

    ld h, 0
    ld l, e
    REPT 5
    add hl, hl
    ENDR
    inc hl
    inc hl
    ld bc, _SCRN0
    add hl, bc   ; HL Contains screen offset
    wait_lcd
    ld [hl], a   ; Put character at screen offset

    pop hl
    pop de
    pop bc
    pop af
    ret

playNote:
;;; Play note at offset E.

    push af
    push bc
    push de
    push hl

;; Translate note to frequency table index.
    ld hl, WorkingSong
    ld b, 0
    ld c, e
    add hl, bc   ; HL now contains address of current note.
    ld a, [hl]
    and $07      ; Mask note.
    sla a        ; Each element in table is two bytes.
    ld b, a	 ; A contains offset into row of table.

    ld a, [hl]
    and $70      ; Mask octave, use as index of row.
    or b         ; A contains offset into table.

    ld hl, FreqTbl
    ld b, 0
    ld c, a
    add hl, bc   ; HL Contains freqency table index

;; Load frequency data
    ld a,  [hl] ; low-order freq data
    ld [rNR13], a

    inc hl
    ld a,  [hl] ; high-order freq data
    bit 7, a
    jr nz, .dontPlay
    set 7, a
    ld [rNR14], a

.play
    ld a,  %00010001 ; Turn off Sound 1n left and right.
    ld [rNR51], a
    jr .finish


.dontPlay
    ld a,  %00000000 ; Turn off Sound 1n left and right.
    ld [rNR51], a

.finish
    ld hl, WorkingBeat
    ld b, 0
    ld c, e
    add hl, bc   ; HL now contains address of current beat.
    ld a, [hl]

    ld d, a

    swap a
    and $0f
    ld e, a      ; E contains duration

    ld a, d

    and $0f
    ld d, a      ; D contains duty

    ld b, 0      ; B contains tick count

.onTick          ; On while tick < duty
    ld a, b
    cp d
    jp z, .onEnd
    wait_div e, $10
    inc b
    jr .onTick
.onEnd

    ld a,  %00000000 ; Turn off Sound 1n left and right.
    ld [rNR51], a

.offTick          ; Off while tick > duty
    ld a, b
    cp $0f
    jr z, .offEnd
    wait_div e, $10
    inc b
    jr .offTick
.offEnd 
    

    pop hl
    pop de
    pop bc
    pop af
    ret

SECTION "sndtbls", ROMX,BANK[2]
FreqTbl: ; Set bit 7 for invalid note.
;     0     1     2     3     4     5     6     7
;     A     B     C     D     E     F     G     X
dw $8000,$8000,$8000,$8000,$8000,$8000,$8000,$8000 ; 1 (0)
dw $8000,$8000,$8000,$8000,$8000,$8000,$8000,$8000 ; 2 (1)
dw $8000,$8000,$8000,$8000,$8000,$8000,$8000,$8000 ; 3 (2)
dw $8000,$8000,  47,  264,  459,  545,  710, $8000 ; 4 (3)
dw  856,  986, 1045, 1154, 1252, 1296, 1379, $8000 ; 5 (4)
dw 1452, 1517, 1547, 1601, 1650, 1672, 1713, $8000 ; 6 (5)
dw 1750, 1782, 1797, 1824, 1849, 1860, 1880, $8000 ; 7 (6)
dw 1899, 1915, 1923, 1936, 1948, 1954, 1964, $8000 ; 8 (7)

OctvTbl: db "XXX45678"
NoteTbl: db "ABCDEFGX"
HexTbl:  db "0123456789ABCDEF"

; Format: (Octave|Note), ...
DefaultSong: db $50, $51, $52, $53, $52, $51, $51, $50
	     db	$50, $51, $52, $53, $52, $52, $53, $52, $30
	     db $ff
DefaultSongEnd:

DefaultBeat: db $8f, $8f, $8f, $8f, $8f, $8f, $8f, $8f
	     db	$8f, $8f, $8f, $8f, $8f, $8f, $8f, $8f, $8f
	     db $ff
DefaultBeatEnd:


SECTION "song", WRAM0
NoteIndex: ds 1
WorkingSong: ds DefaultSongEnd - DefaultSong
EndOfSong:
WorkingBeat: ds DefaultBeatEnd - DefaultBeat
EndOfBeat:

SECTION "tiles", ROMX,BANK[1]
TileStart:

FontTiles:
INCBIN "font.bin"
FontTilesEnd: ; 0x20-0x7F

TileEnd:

SECTION "palette",ROMX,BANK[1]
BGPal:
    dw %0111111111111111, %0000001111100000, \
       %0000000000011111, %0111110000000000

BGPalAlt:
    dw %0000000000011111, %0000001111100000, \
       %0111111111111111, %0111110000000000

CoinPal:
    dw %0111111111111111, %0001110110101110, \
       %0011010111001111, %0010100011101111
