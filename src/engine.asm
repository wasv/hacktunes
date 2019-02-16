;; -*- mode: rgbds; -*-
INCLUDE "hardware.inc"
INCLUDE "engine.inc"

SECTION "engine",ROM0
loadBGPal::
;; Input: HL - Source Address of palette colors
;;        A  - Destination palette index
    push af
    push bc
    push hl
    set 7, a
    ld [rBCPS], a

    ld b, 8
.palLoop
    ld a, [hli]
    ld [rBCPD], a
    dec b
    jr nz, .palLoop

    pop hl
    pop bc
    pop af
    ret

loadOBJPal::
;; Input: HL - Source Address of palette colors
;;        A  - Destination palette index
    push af
    push bc
    push hl
    set 7, a
    ld [rOCPS], a

    ld b, 8
.palLoop
    ld a, [hli]
    ld [rOCPD], a
    dec b
    jr nz, .palLoop

    pop hl
    pop bc
    pop af
    ret

memcpy::
;; Input: HL - Source address
;;        DE - Destination address
;;        BC - Length
    push af
    push bc
    push de
    push hl

.memcpyLoop
    ld a, [hli]   ; Grab 1 byte from the source
    ld [de], a    ; Place it at the destination, incrementing hl
    inc de        ; Move to next byte
    dec bc        ; Decrement count
    ld a, b       ; Check if count is 0, since `dec bc` doesn't update flags
    or c
    jr nz, .memcpyLoop

    pop hl
    pop de
    pop bc
    pop af
    ret
