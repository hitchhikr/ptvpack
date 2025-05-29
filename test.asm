; --------------------------------------------
; ptvpack v1.3c - Replay routine tester
; Written by hitchhikr / Neural

; --------------------------------------------
; Constants
AttnFlags                   equ     296
_LVOSupervisor              equ     -30

                            mc68020
                            opt      o+
                            opt      all+

                            section pta_test,code

; --------------------------------------------
; Entry point
start:                      move.w  $dff01c,-(a7)

                            move.l  4.w,a6
                            lea     get_vbr(pc),a5
                            jsr     _LVOSupervisor(a6)
                            move.w  #$0020,$dff09a
                            ; d0 = vbr
                            lea     ptv_data,a0
                            sub.l   a1,a1               ; possible separate .smp file
                            bsr     ptv_init
ptv_loop:
                            lea     ptv_Enable(pc),a0
                            tst.b   (a0)
                            beq     ptv_fx_f00
                            btst.b  #6,$bfe001
                            bne     ptv_loop
ptv_fx_f00:                 
                            bsr     ptv_end
                            move.w  (a7)+,d0
                            or.w    #$c000,d0
                            move.w  d0,$dff09a
                            moveq   #0,d0
                            rts
get_vbr:                    
                            ; turn vampire extras on
                            move    sr,d1
                            or.w    #$800,d1
                            move    d1,sr
                            move.w  #%10000,$dff1fc
                            movec   vbr,d0
                            rte

; --------------------------------------------
; Replay routine
                            include "constants.inc"
ptv_replay:                 include "replay/replay.asm"

; --------------------------------------------
; Module
; (only the samples need to be located in chipram if splitted from patterns)
                            section ptv_test,data_c

ptv_data:                   incbin  "cattle banger.ptv"

                            end
