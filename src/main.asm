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

; Disable LCD during VRAM  writes.
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

; Switch to Bank 2
    ld a,$02
    ld [rROMB0],a
    jp main


SECTION "main",ROMX,BANK[2]
main:
;; Setup sound system
    ld a,  %10000000 ; Set bit 7 to enable sound.
    ld [rNR52], a
    ld a,  %01110111 ; Set left/right volume to 7
    ld [rNR50], a
    ld a,  %00010001 ; Set Sound 1 on left and right.
    ld [rNR51], a

;; Setup channel 1
    ld a,  %01000000 ; Set 50% Duty cycle and sound length 64.
    ld [rNR11], a
    ld a,  %11110000 ; Max envelope
    ld [rNR12], a

;; Play notes
   ld de, Song
.playLoop
    ld a,  [de]  ; load Note Code from Song
    cp $ff
    jp z, .playEnd
    inc de

    push de      ; Preserve Note Ptr in stack

    ld d, a

    and $07

    ld hl, NoteTbl
    ld b, 0
    ld c, a
    add hl, bc   ; HL Contains note table index
    ld a, [hl]   ; A contains note character
    ld [_SCRN0+$21], a

    ld a, d      ; Revert A from D.

    swap a
    and $07

    ld hl, OctvTbl
    ld b, 0
    ld c, a
    add hl, bc   ; HL Contains octave table index
    ld a, [hl]   ; A contains octave character
    ld [_SCRN0+$22], a

    ld a, d      ; Revert A from D.

    and $07      ; Mask note.
    sla a        ; Each element in table is two bytes.
    ld b, a	 ; A contains offset into row of table.

    ld a, d      ; Revert A from D.

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
    xor $80     ; Set Initialize bit (unset if already set)
    ld [rNR14], a

    wait_div 40, $fe

    pop de       ; Revert Note Ptr from stack

    jr .playLoop

.playEnd
    ld a,  %00000000 ; Reset bit 7 to disable sound.
    ld [rNR52], a

    halt

; Format: (Octave|Note), ...
Song: db $32, $54, $30, $55, $ff

OctvTbl: db "XXX45678"
NoteTbl: db "ABCDEFGX"
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
