;; -*- mode: rgbds; -*-

; Wait till the LCD is past VBlank
wait_vblank : MACRO
    push af
.waitVBlank\@
    ld a, [rLY]
    cp SCRN_Y
    jr c, .waitVBlank\@
    pop af
ENDM

; Usage: stall_cyc n
; Stall for n cycles.
wait_cyc : MACRO
    push af
    ld a, \1
.stall\@
    dec a
    jr nz, .stall\@
    pop af
ENDM

; Waits for a certain time period.
; NOTE: Uses 4096 Hz divider clock.
wait_div: MACRO
    push af
    push bc
    push hl
    ld a, \2
    ld c, \1
    ld hl, rDIV
.loopDiv\@
    ld [rDIV], a
.loopDiv2\@
    cp [hl]
    jr nc, .loopDiv2\@
    dec c
    jr nz, .loopDiv\@
    pop hl
    pop bc
    pop af
ENDM


; Usage: stall_key b
; b is bit number to check
; Wait on key press and release.
; Only uses Start (b=3), Sel, B, A (b=0)
wait_key : MACRO
    ld a, %00010000
    ld [rP1], a
; Stall till A pressed
.aPress
    ld a, [rP1]
    wait_cyc 20
    bit \1, a
    jp z, .aPress

; Stall till A released
.aRelease
    ld a, [rP1]
    wait_cyc 20
    bit \1, a
    jp nz, .aRelease
ENDM
