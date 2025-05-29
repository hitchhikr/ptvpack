; --------------------------------------------
; ptvpack v1.3b - Replay routine
; Written by hitchhikr / Neural
; Based on the original protracker replay.

; --------------------------------------------
; Constants
; (uncomment all these for a complete replay)
;PTV_EXTEND                  equ     1
;PTV_ARPEGGIO                equ     1
;PTV_PACKED_SMP              equ     1              ; module uses packed samples
;PTV_PORTAMENTOUP            equ     1
;PTV_PORTAMENTODOWN          equ     1
;PTV_TONEPORTAMENTO          equ     1
;PTV_VIBRATO                 equ     1
;PTV_TONEPLUSVOLSLIDE        equ     1
;PTV_VIBRATOPLUSVOLSLIDE     equ     1
;PTV_TREMOLO                 equ     1
;PTV_SAMPLEOFFSET            equ     1
;PTV_VOLUMESLIDE             equ     1
;PTV_POSITIONJUMP            equ     1
;PTV_VOLUMECHANGE            equ     1
;PTV_PATTERNBREAK            equ     1
;PTV_SETSPEED                equ     1
;PTV_SETSYNCHRO              equ     1
;PTV_EFX_FILTERONOFF         equ     1
;PTV_EFX_FINEPORTAUP         equ     1
;PTV_EFX_FINEPORTADOWN       equ     1
;PTV_EFX_SETGLISSCONTROL     equ     1
;PTV_EFX_SETVIBRATOCONTROL   equ     1
;PTV_EFX_SETFINETUNE         equ     1
;PTV_EFX_JUMPLOOP            equ     1
;PTV_EFX_SETTREMOLOCONTROL   equ     1
;PTV_EFX_KARPLUSTRONG        equ     1
;PTV_EFX_RETRIGNOTE          equ     1
;PTV_EFX_VOLUMEFINEUP        equ     1
;PTV_EFX_VOLUMEFINEDOWN      equ     1
;PTV_EFX_NOTECUT             equ     1
;PTV_EFX_NOTEDELAY           equ     1
;PTV_EFX_PATTERNDELAY        equ     1
;PTV_EFX_FUNKIT              equ     1
;PTV_FINETUNE_1              equ     1
;PTV_FINETUNE_2              equ     1
;PTV_FINETUNE_3              equ     1
;PTV_FINETUNE_4              equ     1
;PTV_FINETUNE_5              equ     1
;PTV_FINETUNE_6              equ     1
;PTV_FINETUNE_7              equ     1
;PTV_FINETUNE_M8             equ     1
;PTV_FINETUNE_M7             equ     1
;PTV_FINETUNE_M6             equ     1
;PTV_FINETUNE_M5             equ     1
;PTV_FINETUNE_M4             equ     1
;PTV_FINETUNE_M3             equ     1
;PTV_FINETUNE_M2             equ     1
;PTV_FINETUNE_M1             equ     1

                            rsreset
n_note                      rs.w    1       ; 0
n_cmd                       rs.b    1       ; 2
n_cmdlo                     rs.b    1       ; 3
n_start                     rs.l    1       ; 4
n_length                    rs.l    1       ; 8
n_loopstart                 rs.l    1       ; 12
n_replen                    rs.l    1       ; 16
n_period                    rs.w    1       ; 20
n_finetune                  rs.b    1       ; 22
n_volume                    rs.b    1       ; 23
n_dmabitlo                  rs.w    1       ; 24
n_dmabithi                  rs.w    1       ; 26
n_toneportdirec             rs.b    1       ; 28
n_toneportspeed             rs.b    1       ; 29
n_wantedperiod              rs.w    1       ; 30
n_vibratocmd                rs.b    1       ; 32
n_vibratopos                rs.b    1       ; 33
n_tremolocmd                rs.b    1       ; 34
n_tremolopos                rs.b    1       ; 35
n_wavecontrol               rs.b    1       ; 36
n_glissfunk                 rs.b    1       ; 37
n_sampleoffset              rs.b    1       ; 38
n_pattpos                   rs.b    1       ; 39
n_loopcount                 rs.b    1       ; 40
n_funkoffset                rs.b    1       ; 41
n_wavestart                 rs.l    1       ; 42
n_realvolume                rs.b    1       ; 46
n_gap                       rs.b    1       ; 47
n_noteidx                   rs.w    1       ; 48
n_panningleft               rs.w    1       ; 50
n_panningright              rs.w    1       ; 52
n_sizeof                    rs.b    0       ; 54

ciatalo                     equ     $400
ciatahi                     equ     $500
ciatblo                     equ     $600
ciatbhi                     equ     $700
ciaicr                      equ     $d00
ciacra                      equ     $e00
ciacrb                      equ     $f00

MODE_NEWFILE                equ     1006

_LVOAllocMem                equ     -198
_LVOFreeMem                 equ     -210
_LVOOldOpenLibrary          equ     -408
_LVOCloseLibrary            equ     -414

_LVOOpen                    equ     -30
_LVOClose                   equ     -36
_LVOWrite                   equ     -48
_LVODeleteFile              equ     -72

MPEGA_MAX_CHANNELS          equ     2
MPEGA_PCM_SIZE              equ     (1152*2)

_LVOMPEGA_open              equ     -30
_LVOMPEGA_close             equ     -36
_LVOMPEGA_decode_frame      equ     -42
_LVOMPEGA_seek              equ     -48
_LVOMPEGA_time              equ     -54
_LVOMPEGA_find_sync         equ     -60
_LVOMPEGA_scale             equ     -66

NOTES_AMOUNT                equ     (5*12)
MAX_CHANNELS                equ     16

                            mc68020
                            opt      o+
                            opt      all+

; --------------------------------------------
; Tempo
    ifd PTV_SETSPEED
ptv_set_tempo:
                            move.l  ptv_TimerValue-ptv_var(a2),d2
                            divu    d0,d2
                            lea     $bfd000,a1
                            move.b  d2,ciatalo(a1)
                            lsr.w   #8,d2
                            move.b  d2,ciatahi(a1)
                            move.b  #$83,ciaicr(a1)
                            move.b  #$11,ciacra(a1)
                            rts
    endc

; --------------------------------------------
; Replay routine initialization
; d0: VBR
; a0: .ptv file
; a1: .smp file or 0
ptv_init:
                            movem.l d0-a6,-(a7)
                            lea     ptv_var(pc),a2
    ifd PTV_PACKED_SMP
                            movem.l d0/a0/a1,-(a7)
                            move.l  4.w,a6
                            lea     dosname(pc),a1
                            jsr     _LVOOldOpenLibrary(a6)
                            move.l  d0,dosbase-ptv_var(a2)
                            lea     mpeganame(pc),a1
                            jsr     _LVOOldOpenLibrary(a6)
                            move.l  d0,mpegabase-ptv_var(a2)
                            ; temporary frames buffer
                            move.l  #MPEGA_PCM_SIZE,d0
                            move.l  #$10000,d1
                            jsr     _LVOAllocMem(a6)
                            move.l  d0,pcm_buffers-ptv_var(a2)
                            move.l  #MPEGA_PCM_SIZE,d0
                            move.l  #$10000,d1
                            jsr     _LVOAllocMem(a6)
                            move.l  d0,pcm_buffers+4-ptv_var(a2)
                            movem.l (a7)+,d0/a0/a1
    endc
                            move.w  (a0)+,ptv_channels-ptv_var(a2)
                            move.l  a0,ptv_SongDataPtr-ptv_var(a2)
                            add.l   #$78,d0                     ; vbr + $78
                            move.l  d0,ptv_vbr-ptv_var(a2)
                            move.l  14(a0),ptv_chunksize-ptv_var(a2)
                            move.l  18(a0),ptv_patternssize-ptv_var(a2)
                            ; Depack the samples
                            moveq   #0,d7
                            move.b  12(a0),d7                   ; amount of samples (-1)
                            move.w  d7,ptv_samples-ptv_var(a2)
                            lea     22(a0),a6                   ; samples lengths
                            move.l  a6,ptv_sampleslen-ptv_var(a2)
                            move.l  a1,d0                       ; do we use a separate samples file ?
                            beq     ptv_no_smp_file
                            move.l  d0,a0
                            bra     ptv_process_samples
ptv_no_smp_file:
                            add.l   8(a0),a0                    ; samples pool
ptv_process_samples:
                            lea     ptv_SampleStarts-ptv_var(a2),a4
ptv_depack_samples:

    ifd PTV_PACKED_SMP
                            ; packed length
                            move.l  (a0)+,d0
                            movem.l d0/d1/d7/a0/a1/a2/a3/a4/a5/a6,-(a7)
                            movem.l d0/a0,-(a7)
                            move.l  (a6),d0
                            lsl.l   #4,d0
                            move.l  4.w,a6
                            move.l  #$10002,d1
                            jsr     _LVOAllocMem(a6)
                            move.l  d0,(a4)                     ; store new sample address
                            move.l  d0,a3                       ; a5 = unpacked dest
                            ; save the sample data into RAM:
                            move.l  dosbase(pc),a6
                            lea     smpname(pc),a0
                            move.l  a0,d1
                            move.l  #MODE_NEWFILE,d2
                            jsr     _LVOOpen(a6)
                            move.l  d0,a4
                            ; file handle
                            move.l  d0,d1
                            beq     .no_file
                            movem.l (a7),d0/a0
                            ; a0 = source
                            move.l  a0,d2
                            move.l  d0,d3
                            jsr     _LVOWrite(a6)
                            move.l  a4,d1
                            jsr     _LVOClose(a6)
.no_file:
                            movem.l (a7)+,d0/a0
                            move.l  a3,-(a7)
                            move.l  a3,-(a7)
                            tst.l   mpegabase(pc)
                            beq     .no_mpega
                            lea     smpname(pc),a0
                            lea     mpa_ctrl(pc),a1
                            move.l  mpegabase(pc),a6
                            jsr     _LVOMPEGA_open(a6)
                            ; ; a4 = stream
                            lea     mp3stream(pc),a0
                            move.l  d0,(a0)
                            tst.l   d0
                            beq     .no_stream
                            moveq   #0,d7
.decode_frames:
                            move.l  mp3stream(pc),a0
                            lea     pcm_buffers(pc),a1
                            move.l  mpegabase(pc),a6
                            jsr     _LVOMPEGA_decode_frame(a6)
                            tst.l   d0
                            bmi     .stop_decode
                            beq     .no_frame
                            ; copy into destination buffer
                            ; a3 = sample dest
                            move.l  (a7),a3
                            move.l  pcm_buffers(pc),a1
.copy_frame:
                            move.w  (a1)+,(a3)
                            ; don't record those
                            cmp.l   #1105,d7
                            blt     .no_write
                            addq.l  #2,a3
.no_write:
                            addq.l  #1,d7
                            subq.l  #1,d0
                            bne     .copy_frame
                            move.l  a3,(a7)
.no_frame:
                            bra     .decode_frames
.stop_decode:
                            ; close the stream
                            move.l  mp3stream(pc),a0
                            move.l  mpegabase(pc),a6
                            jsr     _LVOMPEGA_close(a6)
.no_mpega:
                            ; delete the file from the RAM:
                            move.l  dosbase(pc),a6
                            lea     smpname(pc),a0
                            move.l  a0,d1
                            jsr     _LVODeleteFile(a6)
.no_stream:
                            move.l  (a7)+,a3
                            move.l  (a7)+,a3
                            clr.l   (a3)
                            movem.l (a7)+,d0/d1/d7/a0/a1/a2/a3/a4/a5/a6
                            addq.l  #4,a4
                            lea     (a0,d0.l),a0                ; next sample
    else
                            ; dest length / 2
                            move.l  a0,(a4)+                    ; store sample address
                            move.l  (a6),d1
                            add.l   d1,d1                       ; real sample length
                            lea     (a0,d1.l),a0                ; next sample
    endc
                            lea     16(a6),a6
                            dbf     d7,ptv_depack_samples
                            lea     ptv_var(pc),a2
                            lea     ptv_chan1temp-ptv_var(a2),a0
                            lea     $dff40a,a1
                            lea     ptv_PanningTable-ptv_var(a2),a3
                            moveq   #1,d0
                            ; first 4 channels
                            moveq   #4-1,d1
                            moveq   #0,d2
ptv_set_channels_dmabitslo:
                            move.w  d0,n_dmabitlo(a0)
                            moveq   #0,d3
                            move.b  (a3,d2.w),d3
                            move.w  d3,n_panningleft(a0)
                            move.b  1(a3,d2.w),d3
                            move.w  d3,n_panningright(a0)
    ifd PTV_PACKED_SMP
                            ; AUDxCTRL (16 bit sample)
                            move.w  #1,(a1)
    else
                            ; AUDxCTRL
                            clr.w   (a1)
    endc
                            lea     n_sizeof(a0),a0
                            lea     $10(a1),a1
                            add.w   d0,d0
                            addq.w  #2,d2
                            dbf     d1,ptv_set_channels_dmabitslo
                            moveq   #1,d0
                            ; remaining 12 channels
                            moveq   #(MAX_CHANNELS-4)-1,d1
ptv_set_channels_dmabitshi:
                            move.w  d0,n_dmabithi(a0)
                            moveq   #0,d3
                            move.b  (a3,d2.w),d3
                            move.w  d3,n_panningleft(a0)
                            move.b  1(a3,d2.w),d3
                            move.w  d3,n_panningright(a0)
    ifd PTV_PACKED_SMP
                            ; AUDxCTRL (16 bit sample)
                            move.w  #1,(a1)
    else
                            ; AUDxCTRL
                            clr.w   (a1)
    endc
                            lea     n_sizeof(a0),a0
                            lea     $10(a1),a1
                            add.w   d0,d0
                            addq.w  #2,d2
                            dbf     d1,ptv_set_channels_dmabitshi
                            move.b  #6,ptv_speed-ptv_var(a2)
                            st.b    ptv_LowMask-ptv_var(a2)
                            clr.b   ptv_counter-ptv_var(a2)
                            clr.b   ptv_SongPos-ptv_var(a2)
                            clr.w   ptv_PatternPos-ptv_var(a2)
                            move.w  #$4000,$dff09a
                            move.l  ptv_vbr-ptv_var(a2),a0
                            move.l  (a0),ptv_old_irq-ptv_var(a2)
                            lea     $bfd000,a3
                            lea     ptv_oldCiaTimers-ptv_var(a2),a1
                            move.b  #$7f,ciaicr(a3)
                            move.b  ciatalo(a3),(a1)+
                            move.b  ciatahi(a3),(a1)+
                            move.b  ciatblo(a3),(a1)+
                            move.b  ciatbhi(a3),(a1)+
                            bsr     ptv_stop
                            lea     ptv_repeat_interrupt-ptv_var(a2),a0
                            move.l  a0,ptv_repeat_irq-ptv_var(a2)
                            move.l  #1773447,d0                 ; default to normal 50 Hz timer
                            move.l  d0,ptv_TimerValue-ptv_var(a2)
                            divu    #125,d0
                            move.b  d0,ciatalo(a3)
                            lsr.w   #8,d0
                            move.b  d0,ciatahi(a3)
                            lea     ptv_main_interrupt-ptv_var(a2),a0
                            move.l  a0,ptv_main_irq-ptv_var(a2)
                            move.l  ptv_vbr(pc),a1
                            move.l  a0,(a1)
                            move.b  #$83,ciaicr(a3)
                            move.b  #$11,ciacra(a3)
                            move.w  #$e000,$dff09a
                            st.b    ptv_Enable-ptv_var(a2)
                            movem.l (a7)+,d0-a6
                            rts

; --------------------------------------------
; Stop replay
ptv_end:
                            movem.l d0/d1/a0/a1/a2/a3/a6,-(a7)
                            bsr     ptv_stop
    ifd PTV_PACKED_SMP
                            move.l  4.w,a6
                            ; free the samples
                            move.w  ptv_samples(pc),d7
                            lea     ptv_SampleStarts(pc),a2
                            move.l  ptv_sampleslen(pc),a3
.free_samples:
                            move.l  (a2)+,a1
                            move.l  (a3),d0
                            lsl.l   #4,d0
                            jsr     _LVOFreeMem(a6)
                            lea     16(a3),a3
                            dbf     d7,.free_samples
                            move.l  #MPEGA_PCM_SIZE,d0
                            move.l  pcm_buffers+4(pc),a1
                            jsr     _LVOFreeMem(a6)
                            move.l  #MPEGA_PCM_SIZE,d0
                            move.l  pcm_buffers(pc),a1
                            jsr     _LVOFreeMem(a6)
                            tst.l   mpegabase(pc)
                            beq     .no_mpega
                            move.l  mpegabase(pc),a1
                            jsr     _LVOCloseLibrary(a6)
.no_mpega:
                            move.l  dosbase(pc),a1
                            jsr     _LVOCloseLibrary(a6)
    endc
                            movem.l (a7)+,d0/d1/a0/a1/a2/a3/a6
                            rts
ptv_stop:
                            movem.l d0/d1/a0/a1/a6,-(a7)
                            lea     ptv_Enable(pc),a0
                            sf.b    (a0)
                            lea     $dff000,a0
                            move.w  #$4000,$9a(a0)
                            move.l  ptv_vbr(pc),a0
                            move.l  ptv_old_irq(pc),(a0)
                            lea     $bfd000,a0
                            lea     ptv_oldCiaTimers(pc),a1
                            move.b  (a1)+,ciatalo(a0)
                            move.b  (a1)+,ciatahi(a0)
                            move.b  (a1)+,ciatblo(a0)
                            move.b  (a1)+,ciatbhi(a0)
                            move.b  #$10,ciacra(a0)
                            move.b  #$10,ciacrb(a0)
                            lea     $dff000,a0
                            move.w  #$f,$96(a0)
                            move.w  #$fff,$296(a0)
                            moveq   #0,d0
                            moveq   #0,d1
.ptv_switch_em_off:
                            move.w  d0,$408(a0)
                            lea     $10(a0),a0
                            addq.w  #1,d1
                            cmp.w   ptv_channels(pc),d1
                            bne     .ptv_switch_em_off
                            movem.l (a7)+,d0/d1/a0/a1/a6
                            rts

; --------------------------------------------
; Interrupts
ptv_repeat_interrupt:
                            tst.b   $bfdd00
                            movem.l d0/a0/a1,-(a7)
                            lea     $dff09c,a0
                            move.w  #$2000,(a0)
                            move.w  #$2000,(a0)
                            lea     $400-$9c(a0),a0
                            lea     ptv_chan1temp(pc),a1
                            moveq   #0,d0
ptv_set_loop:
                            move.l  n_loopstart(a1),(a0)+
                            move.l  n_replen(a1),(a0)
                            lea     $10-4(a0),a0
                            lea     n_sizeof(a1),a1
                            addq.w  #1,d0
                            cmp.w   ptv_channels(pc),d0
                            bne     ptv_set_loop
                            move.l  ptv_vbr(pc),a0
                            move.l  ptv_main_irq(pc),(a0)
                            movem.l (a7)+,d0/a0/a1
                            rte
ptv_dma_interrupt:
                            tst.b   $bfdd00
                            pea     (a0)
                            lea     $dff09c,a0
                            move.w  #$2000,(a0)
                            move.w  #$2000,(a0)
                            move.b  #$19,$bfdf00
                            move.w  ptv_DMACONHi(pc),$296-$9c(a0)
                            move.w  ptv_DMACONLo(pc),$96-$9c(a0)
                            move.l  ptv_vbr(pc),a0
                            move.l  ptv_repeat_irq(pc),(a0)
                            move.l  (a7)+,a0
                            rte

; --------------------------------------------
; Replay the module
ptv_main_interrupt:
                            tst.b   $bfdd00
                            movem.l d0-d6/a0-a6,-(a7)
                            lea     $dff09c,a0
                            move.w  #$2000,(a0)
                            move.w  #$2000,(a0)
                            lea     ptv_var(pc),a2
                            sf.b    ptv_synchro-ptv_var(a2)
                            tst.b   ptv_Enable-ptv_var(a2)
                            beq     ptv_exit
                            addq.b  #1,ptv_counter-ptv_var(a2)
                            move.b  ptv_counter-ptv_var(a2),d0
                            cmp.b   ptv_speed-ptv_var(a2),d0
                            blo     ptv_NoNewNote
                            clr.b   ptv_counter-ptv_var(a2)
                            tst.b   ptv_PattDelTime2-ptv_var(a2)
                            beq     ptv_GetNewNote
                            bsr     ptv_NoNewAllChannels
                            bra     ptv_dskip
ptv_NoNewNote:
                            bsr     ptv_NoNewAllChannels
                            bra     ptv_NoNewPosYet
ptv_NoNewAllChannels:
                            lea     $dff400,a5
                            lea     ptv_chan1temp-ptv_var(a2),a6
                            moveq   #0,d6
ptv_CheckEfx_channels:
                            bsr     ptv_CheckEfx
                            moveq   #0,d0
                            move.b  n_realvolume(a6),d0
                            mulu    n_panningleft(a6),d0
                            lsr.w   #7,d0
                            lsl.w   #8,d0
                            moveq   #0,d1
                            move.b  n_realvolume(a6),d1
                            mulu    n_panningright(a6),d1
                            lsr.w   #7,d1
                            or.w    d1,d0
                            move.w  d0,8(a5)
                            lea     $10(a5),a5
                            lea     n_sizeof(a6),a6
                            addq.w  #1,d6
                            cmp.w   ptv_channels-ptv_var(a2),d6
                            bne     ptv_CheckEfx_channels
                            rts
ptv_GetNewNote:
                            move.l  ptv_SongDataPtr-ptv_var(a2),a0
                            lea     22(a0),a3                   ; samples infos
                            lea     (a0),a4
                            add.l   (a0),a4                     ; song positions
                            add.l   4(a0),a0                    ; patterns datas
                            moveq   #0,d0
                            moveq   #0,d1
                            move.b  ptv_SongPos-ptv_var(a2),d0
                            move.b  (a4,d0.w),d1
                            lsl.l   #6,d1
                            add.w   ptv_PatternPos-ptv_var(a2),d1
                            add.l   d1,a0
                            move.w  #$8000,ptv_DMACONHi-ptv_var(a2)
                            move.w  #$8000,ptv_DMACONLo-ptv_var(a2)
                            lea     ptv_chan1temp-ptv_var(a2),a6
                            lea     $dff400,a5
                            moveq   #0,d6
ptv_PlayVoice_channels:
                            bsr     ptv_PlayVoice
                            lea     $10(a5),a5
                            lea     n_sizeof(a6),a6
                            addq.w  #1,d6
                            cmp.w   ptv_channels-ptv_var(a2),d6
                            bne     ptv_PlayVoice_channels
                            bra     ptv_SetDMA
ptv_PlayVoice:
                            tst.l   (a6)
                            bne     ptv_plvskip
                            bsr     ptv_PerNop
ptv_plvskip:
                            moveq   #0,d3
                            move.l  ptv_patternssize-ptv_var(a2),d1
                            move.b  (a0),d3                     ; note
                            subq.w  #1,d3
                            add.w   d3,d3
                            move.w  d3,n_noteidx(a6)
                            move.w  ptv_PeriodTable-ptv_var(a2,d3.w),(a6)
                            move.l  d1,d2
                            move.b  (a0,d2.l),d3                ; instrument
                            move.b  d3,d0
                            and.b   #$f0,d3
                            or.b    d3,(a6)
                            and.b   #$f,d0
                            lsl.b   #4,d0
                            add.l   d1,d2
                            move.b  (a0,d2.l),d3                ; fx
                            or.b    d3,d0
                            move.b  d0,n_cmd(a6)                ; half instrument + fx
                            add.l   d1,d2
                            move.b  (a0,d2.l),n_cmdlo(a6)       ; fx datas
                            ; next channel
                            add.l   ptv_chunksize-ptv_var(a2),a0
                            moveq   #0,d2
                            move.b  n_cmd(a6),d2
                            and.b   #$f0,d2
                            lsr.b   #4,d2
                            move.b  (a6),d0                     ; note
                            and.b   #$f0,d0
                            or.b    d0,d2
                            beq     ptv_SetRegs
                            subq.w  #1,d2
                            add.w   d2,d2
                            add.w   d2,d2                       ; *4
                            move.w  d2,d0
                            add.w   d0,d0
                            add.w   d0,d0                       ; *16
                            move.l  ptv_SampleStarts-ptv_var(a2,d2.w),n_start(a6)
                            move.l  (a3,d0.w),n_length(a6)
                            move.b  4(a3,d0.w),n_finetune(a6)
                            move.b  5(a3,d0.w),n_volume(a6)
                            move.l  n_start(a6),d2              ; get start
                            movem.l 6(a3,d0.w),d0/d1            ; get repeat start & replen
                            move.l  d1,n_replen(a6)             ; save replen
                            tst.l   d0
                            beq     ptv_NoLoop
                            move.l  d0,d3
    ifd PTV_PACKED_SMP
                            add.l   d3,d3
    endc
                            add.l   d3,d3
                            add.l   d3,d2                       ; add repeat
                            add.l   d1,d0                       ; add replen
                            move.l  d0,n_length(a6)
ptv_NoLoop:
                            move.l  d2,n_loopstart(a6)
                            move.l  d2,n_wavestart(a6)
ptv_SetRegs:
                            move.w  (a6),d0
                            and.w   #$fff,d0
                            beq     ptv_CheckMoreEfxVolume      ; if no note

    ifd PTV_EFX_SETFINETUNE
                            move.w  n_cmd(a6),d0
                            and.w   #$ff0,d0
                            cmp.w   #$e50,d0
                            beq     ptv_DoSetFineTune
    endc
    
                            move.b  n_cmd(a6),d0
                            and.b   #$f,d0

    ifd PTV_TONEPORTAMENTO
                            cmp.b   #3,d0                       ; tone portamento
                            beq     ptv_ChkTonePorta
    endc

    ifd PTV_TONEPLUSVOLSLIDE
                            cmp.b   #5,d0
                            beq     ptv_ChkTonePorta
    endc

    ifd PTV_SAMPLEOFFSET
                            cmp.b   #9,d0                       ; sample offset
                            bne     ptv_SetPeriod
                            bsr     ptv_CheckMoreEfx
    endc
                            bra     ptv_SetPeriod

    ifd PTV_EFX_SETFINETUNE
ptv_DoSetFineTune:
                            bsr     ptv_SetFineTune
                            bra     ptv_UpdateChannelVolume
    endc

ptv_ChkTonePorta:

    ifd PTV_TONEPORTAMENTO
                            bsr     ptv_SetTonePorta
    endc

ptv_CheckMoreEfxVolume:
                            bsr     ptv_CheckMoreEfx
ptv_UpdateChannelVolume:
                            moveq   #0,d0
                            move.b  n_volume(a6),d0
                            move.b  d0,n_realvolume(a6)
                            mulu    n_panningleft(a6),d0
                            lsr.w   #7,d0
                            lsl.w   #8,d0
                            moveq   #0,d1
                            move.b  n_volume(a6),d1
                            mulu    n_panningright(a6),d1
                            lsr.w   #7,d1
                            or.w    d1,d0
                            move.w  d0,8(a5)
                            rts
ptv_SetPeriod:
                            moveq   #0,d1
                            move.b  n_finetune(a6),d1
                            move.w  ptv_PeriodTablePtr-ptv_var(a2,d1.w*2),d1
                            add.w   n_noteidx(a6),d1
                            move.w  ptv_PeriodTable-ptv_var(a2,d1.w),n_period(a6)

    ifd PTV_EFX_NOTEDELAY
                            move.w  n_cmd(a6),d0
                            and.w   #$ff0,d0
                            cmp.w   #$ed0,d0                    ; notedelay
                            beq     ptv_CheckMoreEfx
    endc

                            cmp.w   #4,d6
                            blt     .ptv_Nohibits
                            move.w  n_dmabithi(a6),$dff296
                            bra     .ptv_Gohibits
.ptv_Nohibits:
                            move.w  n_dmabitlo(a6),$dff096
.ptv_Gohibits:

    ifd PTV_VIBRATO
                            btst    #2,n_wavecontrol(a6)
                            bne     ptv_vibnoc
                            clr.b   n_vibratopos(a6)
ptv_vibnoc:
    else
        ifd PTV_TREMOLO
                            btst    #2,n_wavecontrol(a6)
                            bne     ptv_vibnoc
                            clr.b   n_vibratopos(a6)
ptv_vibnoc:
        endc
    endc

    ifd PTV_TREMOLO
                            btst    #6,n_wavecontrol(a6)
                            bne     ptv_trenoc
                            clr.b   n_tremolopos(a6)
ptv_trenoc:
    endc
                            move.l  n_start(a6),(a5)            ; set start
                            move.l  n_length(a6),4(a5)          ; set length
                            move.w  n_period(a6),$c(a5)         ; set period

                            cmp.w   #4,d6
                            blt     .ptv_Nohibits
                            move.w  n_dmabithi(a6),d0
                            or.w    d0,ptv_DMACONHi-ptv_var(a2)
                            bra     .ptv_Gohibits
.ptv_Nohibits:
                            move.w  n_dmabitlo(a6),d0
                            or.w    d0,ptv_DMACONLo-ptv_var(a2)
.ptv_Gohibits:
                            bra     ptv_CheckMoreEfxVolume
ptv_SetDMA:
                            lea     ptv_dma_interrupt-ptv_var(a2),a1
                            move.l  ptv_vbr-ptv_var(a2),a0
                            move.l  a1,(a0)
                            move.b  #$f0,$bfd600
                            move.b  #1,$bfd700
                            move.b  #$19,$bfdf00
ptv_dskip:
                            addq.w  #1,ptv_PatternPos-ptv_var(a2)
                            move.b  ptv_PattDelTime-ptv_var(a2),d0
                            beq     ptv_dskc
                            move.b  d0,ptv_PattDelTime2-ptv_var(a2)
                            sf.b    ptv_PattDelTime-ptv_var(a2)
ptv_dskc:
                            tst.b   ptv_PattDelTime2-ptv_var(a2)
                            beq     ptv_dska
                            subq.b  #1,ptv_PattDelTime2-ptv_var(a2)
                            beq     ptv_dska
                            subq.w  #1,ptv_PatternPos-ptv_var(a2)
ptv_dska:
                            tst.b   ptv_PBreakFlag-ptv_var(a2)
                            beq     ptv_nnpysk
                            sf.b    ptv_PBreakFlag-ptv_var(a2)
                            moveq   #0,d0
                            move.b  ptv_PBreakPos-ptv_var(a2),d0
                            sf.b    ptv_PBreakPos-ptv_var(a2)
                            move.w  d0,ptv_PatternPos-ptv_var(a2)
ptv_nnpysk:                 cmp.w   #64,ptv_PatternPos-ptv_var(a2)
                            blo     ptv_NoNewPosYet
ptv_NextPosition:
                            moveq   #0,d0
                            move.b  ptv_PBreakPos-ptv_var(a2),d0
                            move.w  d0,ptv_PatternPos-ptv_var(a2)
                            sf.b    ptv_PBreakPos-ptv_var(a2)
                            sf.b    ptv_PosJumpFlag-ptv_var(a2)
                            addq.b  #1,ptv_SongPos-ptv_var(a2)
                            and.b   #$7f,ptv_SongPos-ptv_var(a2)
                            move.b  ptv_SongPos-ptv_var(a2),d1
                            move.l  ptv_SongDataPtr-ptv_var(a2),a0
                            cmp.b   13(a0),d1                   ; max number of positions
                            blo     ptv_NoNewPosYet
                            sf.b    ptv_SongPos-ptv_var(a2)
ptv_NoNewPosYet:
                            tst.b   ptv_PosJumpFlag-ptv_var(a2)
                            bne     ptv_NextPosition
ptv_exit:
                            movem.l (a7)+,d0-d6/a0-a6
                            rte
ptv_Fx_Table:
    ifd PTV_ARPEGGIO
                            dc.w    ptv_Arpeggio-ptv_Fx_Table
    else
                            dc.w    ptv_PerNop-ptv_Fx_Table
    endc
    ifd PTV_PORTAMENTOUP
                            dc.w    ptv_PortaUp-ptv_Fx_Table
    else
                            dc.w    ptv_PerNop-ptv_Fx_Table
    endc
    ifd PTV_PORTAMENTODOWN
                            dc.w    ptv_PortaDown-ptv_Fx_Table
    else
                            dc.w    ptv_PerNop-ptv_Fx_Table
    endc
    ifd PTV_TONEPORTAMENTO
                            dc.w    ptv_TonePortamento-ptv_Fx_Table
    else
                            dc.w    ptv_PerNop-ptv_Fx_Table
    endc
    ifd PTV_VIBRATO
                            dc.w    ptv_Vibrato-ptv_Fx_Table
    else
                            dc.w    ptv_PerNop-ptv_Fx_Table
    endc
    ifd PTV_TONEPLUSVOLSLIDE
                            dc.w    ptv_TonePlusVolSlide-ptv_Fx_Table
    else
                            dc.w    ptv_PerNop-ptv_Fx_Table
    endc
    ifd PTV_VIBRATOPLUSVOLSLIDE
                            dc.w    ptv_VibratoPlusVolSlide-ptv_Fx_Table
    else
                            dc.w    ptv_PerNop-ptv_Fx_Table
    endc
    ifd PTV_TREMOLO
                            dc.w    ptv_Tremolo-ptv_Fx_Table
    else
                            dc.w    ptv_PerNop-ptv_Fx_Table
    endc
                            dc.w    ptv_PerNop-ptv_Fx_Table
                            dc.w    ptv_PerNop-ptv_Fx_Table
    ifd PTV_VOLUMESLIDE
                            dc.w    ptv_VolumeSlidePer-ptv_Fx_Table
    else
                            dc.w    ptv_PerNop-ptv_Fx_Table
    endc
                            dc.w    ptv_PerNop-ptv_Fx_Table
                            dc.w    ptv_PerNop-ptv_Fx_Table
                            dc.w    ptv_PerNop-ptv_Fx_Table
    ifd PTV_EXTEND
                            dc.w    ptv_E_Commands-ptv_Fx_Table
    else
                            dc.w    ptv_PerNop-ptv_Fx_Table
    endc
                            dc.w    ptv_PerNop-ptv_Fx_Table

ptv_CheckEfx:

    ifd PTV_EFX_FUNKIT
                            bsr     ptv_UpdateFunk
    endc

                            move.w  n_cmd(a6),d0
                            and.w   #$fff,d0
                            beq     ptv_PerNop
                            lsr.w   #8,d0
                            move.w  ptv_Fx_Table(pc,d0.w*2),d0
                            jmp     ptv_Fx_Table(pc,d0.w)

ptv_PerNop:
                            move.w  n_period(a6),$c(a5)
ptv_Return:
                            rts

    ifd PTV_ARPEGGIO
ptv_arpeggio_table:         dc.b    0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0,1
ptv_Arpeggio:
                            moveq   #0,d1
                            move.b  ptv_counter-ptv_var(a2),d1
                            move.b  ptv_arpeggio_table(pc,d1.w),d1
                            beq     ptv_Arpeggio2
                            subq.b  #2,d1
                            beq     ptv_Arpeggio1
                            move.b  n_cmdlo(a6),d1
                            lsr.b   #4,d1
                            bra     ptv_Arpeggio3
ptv_Arpeggio2:
                            move.w  n_period(a6),$c(a5)
                            rts
ptv_Arpeggio1:
                            move.b  n_cmdlo(a6),d1
                            and.b   #$f,d1
ptv_Arpeggio3:
                            add.w   d1,d1
                            move.w  n_period(a6),d2
                            moveq   #0,d0
                            move.b  n_finetune(a6),d0
                            move.w  ptv_PeriodTablePtr-ptv_var(a2,d0.w*2),d0
                            lea     ptv_PeriodTable-ptv_var(a2,d0.w),a1
                            moveq   #(NOTES_AMOUNT+1)-1,d3
                            moveq   #0,d0
ptv_Arp_Loop:
                            cmp.w   (a1,d0.w),d2
                            bhs     ptv_Found_Arp
                            addq.w  #2,d0
                            dbf     d3,ptv_Arp_Loop
                            rts
ptv_Found_Arp:
                            add.w   d0,d1
                            move.w  (a1,d1.w),$c(a5)
                            rts
    endc

    ifd PTV_EFX_FINEPORTAUP
ptv_FinePortaUp:
                            tst.b   ptv_counter-ptv_var(a2)
                            bne     ptv_Return
                            move.b  #$f,ptv_LowMask-ptv_var(a2)
    endc

    ifd PTV_PORTAMENTOUP
ptv_PortaUp:
                            moveq   #0,d0
                            move.b  n_cmdlo(a6),d0
                            and.b   ptv_LowMask-ptv_var(a2),d0
                            st.b    ptv_LowMask-ptv_var(a2)
                            sub.w   d0,n_period(a6)
                            move.w  n_period(a6),d0
                            and.w   #$fff,d0
                            cmp.w   #113,d0
                            bpl     ptv_PortaUskip
                            and.w   #$f000,n_period(a6)
                            or.w    #113,n_period(a6)
ptv_PortaUskip:
                            move.w  n_period(a6),d0
                            and.w   #$fff,d0
                            move.w  d0,$c(a5)
                            rts
    endc

    ifd PTV_EFX_FINEPORTADOWN
ptv_FinePortaDown:
                            tst.b   ptv_counter-ptv_var(a2)
                            bne     ptv_Return
                            move.b  #$f,ptv_LowMask-ptv_var(a2)
    endc

    ifd PTV_PORTAMENTODOWN
ptv_PortaDown:              
                            moveq   #0,d0
                            move.b  n_cmdlo(a6),d0
                            and.b   ptv_LowMask-ptv_var(a2),d0
                            st.b    ptv_LowMask-ptv_var(a2)
                            add.w   d0,n_period(a6)
                            move.w  n_period(a6),d0
                            and.w   #$fff,d0
                            cmp.w   #856,d0
                            bmi     ptv_PortaDskip
                            and.w   #$f000,n_period(a6)
                            or.w    #856,n_period(a6)
ptv_PortaDskip:
                            move.w  n_period(a6),d0
                            and.w   #$fff,d0
                            move.w  d0,$c(a5)
                            rts
    endc

    ifd PTV_TONEPORTAMENTO
ptv_SetTonePorta:
                            move.w  (a6),d2
                            and.w   #$fff,d2
                            moveq   #0,d0
                            move.b  n_finetune(a6),d0
                            move.w  ptv_PeriodTablePtr-ptv_var(a2,d0.w*2),d0
                            lea     ptv_PeriodTable-ptv_var(a2,d0.w),a1
                            moveq   #(NOTES_AMOUNT+1)-1,d3
                            moveq   #0,d0
ptv_Stp_Loop:
                            cmp.w   (a1,d0.w),d2
                            bhs     ptv_Stp_Found
                            addq.w  #2,d0
                            dbf     d3,ptv_Stp_Loop
                            move.w  #(NOTES_AMOUNT-1)*2,d0
ptv_Stp_Found:
                            move.b  n_finetune(a6),d2
                            and.b   #8,d2
                            beq     ptv_StpGoss
                            tst.w   d0
                            beq     ptv_StpGoss
                            subq.w  #2,d0
ptv_StpGoss:
                            move.w  (a1,d0.w),d2
                            move.w  d2,n_wantedperiod(a6)
                            move.w  n_period(a6),d0
                            clr.b   n_toneportdirec(a6)
                            cmp.w   d0,d2
                            beq     ptv_ClearTonePorta
                            bge     ptv_Return
                            move.b  #1,n_toneportdirec(a6)
                            rts
ptv_ClearTonePorta:
                            clr.w   n_wantedperiod(a6)
                            rts
    endc

    ifd PTV_TONEPORTAMENTO
ptv_TonePortamento:
                            move.b  n_cmdlo(a6),d0
                            beq     ptv_TonePortNoChange
                            move.b  d0,n_toneportspeed(a6)
                            clr.b   n_cmdlo(a6)
ptv_TonePortNoChange:
                            tst.w   n_wantedperiod(a6)
                            beq     ptv_Return
                            moveq   #0,d0
                            move.b  n_toneportspeed(a6),d0
                            tst.b   n_toneportdirec(a6)
                            bne     ptv_TonePortaUp
ptv_TonePortaDown:
                            add.w   d0,n_period(a6)
                            move.w  n_wantedperiod(a6),d0
                            cmp.w   n_period(a6),d0
                            bgt     ptv_TonePortaSetPer
                            move.w  n_wantedperiod(a6),n_period(a6)
                            clr.w   n_wantedperiod(a6)
                            bra     ptv_TonePortaSetPer
ptv_TonePortaUp:
                            sub.w   d0,n_period(a6)
                            move.w  n_wantedperiod(a6),d0
                            cmp.w   n_period(a6),d0
                            blt     ptv_TonePortaSetPer
                            move.w  n_wantedperiod(a6),n_period(a6)
                            clr.w   n_wantedperiod(a6)
ptv_TonePortaSetPer:
                            move.w  n_period(a6),d2
                            move.b  n_glissfunk(a6),d0
                            and.b   #$f,d0
                            beq     ptv_GlissSkip
                            moveq   #0,d0
                            move.b  n_finetune(a6),d0
                            move.w  ptv_PeriodTablePtr-ptv_var(a2,d0.w*2),d0
                            lea     ptv_PeriodTable-ptv_var(a2,d0.w),a1
                            moveq   #(NOTES_AMOUNT+1)-1,d3
                            moveq   #0,d0
ptv_Gliss_Loop:
                            cmp.w   (a1,d0.w),d2
                            bhs     ptv_Gliss_Found
                            addq.w  #2,d0
                            dbf     d3,ptv_Gliss_Loop
                            move.w  #(NOTES_AMOUNT-1)*2,d0
ptv_Gliss_Found:
                            move.w  (a1,d0.w),d2
ptv_GlissSkip:
                            move.w  d2,$c(a5)                   ; set period
                            rts
    endc

    ifd PTV_VIBRATO
ptv_Vibrato:
                            move.b  n_cmdlo(a6),d0
                            beq     ptv_Vibrato2
                            move.b  n_vibratocmd(a6),d2
                            and.b   #$f,d0
                            beq     ptv_vibskip
                            and.b   #$f0,d2
                            or.b    d0,d2
ptv_vibskip:
                            move.b  n_cmdlo(a6),d0
                            and.b   #$f0,d0
                            beq     ptv_vibskip2
                            and.b   #$f,d2
                            or.b    d0,d2
ptv_vibskip2:
                            move.b  d2,n_vibratocmd(a6)
ptv_Vibrato2:
                            move.b  n_vibratopos(a6),d0
                            lsr.w   #2,d0
                            and.w   #$1f,d0
                            moveq   #0,d2
                            move.b  n_wavecontrol(a6),d2
                            and.b   #3,d2
                            beq.b   ptv_vib_sine
                            lsl.b   #3,d0
                            cmp.b   #1,d2
                            beq     ptv_vib_rampdown
                            st.b    d2
                            bra     ptv_vib_set
ptv_vib_rampdown:
                            tst.b   n_vibratopos(a6)
                            bpl     ptv_vib_rampdown2
                            st.b    d2
                            sub.b   d0,d2
                            bra     ptv_vib_set

ptv_vib_rampdown2:          move.b  d0,d2
                            bra     ptv_vib_set

ptv_vib_sine:               move.b  ptv_VibratoTable-ptv_var(a2,d0.w),d2

ptv_vib_set:                move.b  n_vibratocmd(a6),d0
                            and.w   #$f,d0
                            mulu    d0,d2
                            lsr.w   #7,d2
                            move.w  n_period(a6),d0
                            tst.b   n_vibratopos(a6)
                            bmi     ptv_VibratoNeg
                            add.w   d2,d0
                            bra     ptv_Vibrato3
ptv_VibratoNeg:
                            sub.w   d2,d0
ptv_Vibrato3:
                            move.w  d0,$c(a5)
                            move.b  n_vibratocmd(a6),d0
                            lsr.w   #2,d0
                            and.w   #$3c,d0
                            add.b   d0,n_vibratopos(a6)
                            rts
    endc

    ifd PTV_TONEPLUSVOLSLIDE
ptv_TonePlusVolSlide:
                            bsr     ptv_TonePortNoChange
                            bra     ptv_VolumeSlide
    endc

    ifd PTV_VIBRATOPLUSVOLSLIDE
ptv_VibratoPlusVolSlide:
                            bsr     ptv_Vibrato2
                            bra     ptv_VolumeSlide
    endc

    ifd PTV_TREMOLO
ptv_Tremolo:
                            move.w  n_period(a6),$c(a5)
                            move.b  n_cmdlo(a6),d0
                            beq     ptv_Tremolo2
                            move.b  n_tremolocmd(a6),d2
                            and.b   #$f,d0
                            beq     ptv_treskip
                            and.b   #$f0,d2
                            or.b    d0,d2
ptv_treskip:
                            move.b  n_cmdlo(a6),d0
                            and.b   #$f0,d0
                            beq     ptv_treskip2
                            and.b   #$f,d2
                            or.b    d0,d2
ptv_treskip2:
                            move.b  d2,n_tremolocmd(a6)
ptv_Tremolo2:
                            move.b  n_tremolopos(a6),d0
                            lsr.w   #2,d0
                            and.w   #$1f,d0
                            moveq   #0,d2
                            move.b  n_wavecontrol(a6),d2
                            lsr.b   #4,d2
                            and.b   #3,d2
                            beq     ptv_tre_sine
                            lsl.b   #3,d0
                            cmp.b   #1,d2
                            beq     ptv_tre_rampdown
                            st.b    d2
                            bra     ptv_tre_set
ptv_tre_rampdown:
                            tst.b   n_tremolopos(a6)
                            bpl     ptv_tre_rampdown2
                            st.b    d2
                            sub.b   d0,d2
                            bra     ptv_tre_set
ptv_tre_rampdown2:
                            move.b  d0,d2
                            bra     ptv_tre_set
ptv_tre_sine:
                            move.b  ptv_VibratoTable-ptv_var(a2,d0.w),d2
ptv_tre_set:
                            move.b  n_tremolocmd(a6),d0
                            and.w   #$f,d0
                            mulu    d0,d2
                            lsr.w   #6,d2
                            moveq   #0,d0
                            move.b  n_volume(a6),d0
                            tst.b   n_tremolopos(a6)
                            bmi     ptv_TremoloNeg
                            add.w   d2,d0
                            bra     ptv_Tremolo3
ptv_TremoloNeg:
                            sub.w   d2,d0
ptv_Tremolo3:
                            bpl     ptv_TremoloSkip
                            clr.w   d0
ptv_TremoloSkip:
                            cmp.w   #64,d0
                            bls     ptv_TremoloOk
                            move.w  #64,d0
ptv_TremoloOk:
                            move.b  d0,n_realvolume(a6)
                            move.b  n_tremolocmd(a6),d0
                            lsr.w   #2,d0
                            and.w   #$3c,d0
                            add.b   d0,n_tremolopos(a6)
                            rts
    endc

    ifd PTV_SAMPLEOFFSET
ptv_SampleOffset:
                            moveq   #0,d0
                            move.b  n_cmdlo(a6),d0
                            beq     ptv_sononew
                            move.b  d0,n_sampleoffset(a6)
ptv_sononew:
                            move.b  n_sampleoffset(a6),d0
                            lsl.l   #7,d0
                            cmp.l   n_length(a6),d0
                            bge     ptv_sofskip
                            sub.l   d0,n_length(a6)
                            add.l   d0,d0
                            add.l   d0,n_start(a6)
                            rts
ptv_sofskip:
                            move.l  #1,n_length(a6)
                            rts
    endc

    ifd PTV_VOLUMESLIDE
ptv_VolumeSlidePer:
                            move.w  n_period(a6),$c(a5)
ptv_VolumeSlide:
                            move.b  n_cmdlo(a6),d0
                            lsr.b   #4,d0
                            beq     ptv_VolSlideDown
ptv_VolSlideUp:
                            add.b   d0,n_volume(a6)
                            cmp.b   #64,n_volume(a6)
                            bmi     ptv_vsuskip
                            move.b  #64,n_volume(a6)
ptv_vsuskip:
                            move.b  n_volume(a6),n_realvolume(a6)
                            rts
ptv_VolSlideDown:
                            move.b  n_cmdlo(a6),d0
                            and.b   #$f,d0
ptv_VolSlideDown2:
                            sub.b   d0,n_volume(a6)
                            bpl     ptv_vsdskip
                            clr.b   n_volume(a6)
ptv_vsdskip:
                            move.b  n_volume(a6),n_realvolume(a6)
                            rts
    endc

    ifd PTV_POSITIONJUMP
ptv_PositionJump:
                            move.b  n_cmdlo(a6),ptv_SongPos-ptv_var(a2)
                            sf.b    ptv_PBreakPos-ptv_var(a2)
                            st.b    ptv_PosJumpFlag-ptv_var(a2)
                            rts
    endc

    ifd PTV_VOLUMECHANGE
ptv_VolumeChange:
                            move.b  n_cmdlo(a6),d0
                            cmp.b   #64,d0
                            bls     ptv_VolumeOk
                            moveq   #64,d0
ptv_VolumeOk:
                            move.b  d0,n_volume(a6)
                            rts
    endc

    ifd PTV_PATTERNBREAK
ptv_PatternBreak:
                            move.b  n_cmdlo(a6),ptv_PBreakPos-ptv_var(a2)
                            st.b    ptv_PosJumpFlag-ptv_var(a2)
                            rts
    endc

    ifd PTV_SETSPEED
ptv_SetSpeed:
                            moveq   #0,d0
                            move.b  n_cmdlo(a6),d0
                            beq     ptv_stop
                            cmp.b   #32,d0
                            bhs     ptv_set_tempo
                            sf.b    ptv_counter-ptv_var(a2)
                            move.b  d0,ptv_speed-ptv_var(a2)
                            rts
    endc

    ifd PTV_SETSYNCHRO
ptv_SetSynchro:
                            move.b  n_cmdlo(a6),d0
                            addq.b  #1,d0
                            move.b  d0,ptv_synchro-ptv_var(a2)
                            rts
    endc

ptv_Tick0_Fx_Table:         dc.w    ptv_PerNop-ptv_Tick0_Fx_Table
                            dc.w    ptv_PerNop-ptv_Tick0_Fx_Table
                            dc.w    ptv_PerNop-ptv_Tick0_Fx_Table
                            dc.w    ptv_PerNop-ptv_Tick0_Fx_Table
                            dc.w    ptv_PerNop-ptv_Tick0_Fx_Table
                            dc.w    ptv_PerNop-ptv_Tick0_Fx_Table
                            dc.w    ptv_PerNop-ptv_Tick0_Fx_Table
                            dc.w    ptv_PerNop-ptv_Tick0_Fx_Table
    ifd PTV_SETSYNCHRO
                            dc.w    ptv_SetSynchro-ptv_Tick0_Fx_Table
    else
                            dc.w    ptv_PerNop-ptv_Tick0_Fx_Table
    endc
    ifd PTV_SAMPLEOFFSET
                            dc.w    ptv_SampleOffset-ptv_Tick0_Fx_Table
    else
                            dc.w    ptv_PerNop-ptv_Tick0_Fx_Table
    endc
                            dc.w    ptv_PerNop-ptv_Tick0_Fx_Table
    ifd PTV_POSITIONJUMP
                            dc.w    ptv_PositionJump-ptv_Tick0_Fx_Table
    else
                            dc.w    ptv_PerNop-ptv_Tick0_Fx_Table
    endc        
    ifd PTV_VOLUMECHANGE
                            dc.w    ptv_VolumeChange-ptv_Tick0_Fx_Table
    else
                            dc.w    ptv_PerNop-ptv_Tick0_Fx_Table
    endc        
    ifd PTV_PATTERNBREAK
                            dc.w    ptv_PatternBreak-ptv_Tick0_Fx_Table
    else
                            dc.w    ptv_PerNop-ptv_Tick0_Fx_Table
    endc
    ifd PTV_EXTEND
                            dc.w    ptv_E_Commands-ptv_Tick0_Fx_Table
    else
                            dc.w    ptv_PerNop-ptv_Tick0_Fx_Table
    endc
    ifd PTV_SETSPEED
                            dc.w    ptv_SetSpeed-ptv_Tick0_Fx_Table
    else
                            dc.w    ptv_PerNop-ptv_Tick0_Fx_Table
    endc

ptv_CheckMoreEfx:

    ifd PTV_EFX_FUNKIT
                            bsr     ptv_UpdateFunk
    endc
                            move.b  n_cmd(a6),d0
                            and.w   #$f,d0
                            move.w  ptv_Tick0_Fx_Table(pc,d0.w*2),d0
                            jmp     ptv_Tick0_Fx_Table(pc,d0.w)

    ifd PTV_EXTEND

ptv_E_Table:
    ifd PTV_EFX_FILTERONOFF
                            dc.w    ptv_FilterOnOff-ptv_E_Table
    else
                            dc.w    ptv_Return-ptv_E_Table
    endc
    ifd PTV_EFX_FINEPORTAUP
                            dc.w    ptv_FinePortaUp-ptv_E_Table
    else
                            dc.w    ptv_Return-ptv_E_Table
    endc
    ifd PTV_EFX_FINEPORTADOWN
                            dc.w    ptv_FinePortaDown-ptv_E_Table
    else
                            dc.w    ptv_Return-ptv_E_Table
    endc
    ifd PTV_EFX_SETGLISSCONTROL
                            dc.w    ptv_SetGlissControl-ptv_E_Table
    else
                            dc.w    ptv_Return-ptv_E_Table
    endc
    ifd PTV_EFX_SETVIBRATOCONTROL
                            dc.w    ptv_SetVibratoControl-ptv_E_Table
    else
                            dc.w    ptv_Return-ptv_E_Table
    endc
    ifd PTV_EFX_SETFINETUNE
                            dc.w    ptv_SetFineTune-ptv_E_Table
    else
                            dc.w    ptv_Return-ptv_E_Table
    endc
    ifd PTV_EFX_JUMPLOOP
                            dc.w    ptv_JumpLoop-ptv_E_Table
    else
                            dc.w    ptv_Return-ptv_E_Table
    endc
    ifd PTV_EFX_SETTREMOLOCONTROL
                            dc.w    ptv_SetTremoloControl-ptv_E_Table
    else
                            dc.w    ptv_Return-ptv_E_Table
    endc
    ifd PTV_EFX_KARPLUSTRONG
                            dc.w    ptv_KarplusStrong-ptv_E_Table
    else
                            dc.w    ptv_Return-ptv_E_Table
    endc
    ifd PTV_EFX_RETRIGNOTE
                            dc.w    ptv_RetrigNote-ptv_E_Table
    else
                            dc.w    ptv_Return-ptv_E_Table
    endc
    ifd PTV_EFX_VOLUMEFINEUP
                            dc.w    ptv_VolumeFineUp-ptv_E_Table
    else
                            dc.w    ptv_Return-ptv_E_Table
    endc
    ifd PTV_EFX_VOLUMEFINEDOWN
                            dc.w    ptv_VolumeFineDown-ptv_E_Table
    else
                            dc.w    ptv_Return-ptv_E_Table
    endc
    ifd PTV_EFX_NOTECUT
                            dc.w    ptv_NoteCut-ptv_E_Table
    else
                            dc.w    ptv_Return-ptv_E_Table
    endc
    ifd PTV_EFX_NOTEDELAY
                            dc.w    ptv_NoteDelay-ptv_E_Table
    else
                            dc.w    ptv_Return-ptv_E_Table
    endc
    ifd PTV_EFX_PATTERNDELAY
                            dc.w    ptv_PatternDelay-ptv_E_Table
    else
                            dc.w    ptv_Return-ptv_E_Table
    endc
    ifd PTV_EFX_FUNKIT
                            dc.w    ptv_FunkIt-ptv_E_Table
    else
                            dc.w    ptv_Return-ptv_E_Table
    endc

ptv_E_Commands:
                            move.b  n_cmdlo(a6),d0
                            and.w   #$f0,d0
                            lsr.b   #4,d0
                            move.w  ptv_E_Table(pc,d0.w*2),d0
                            jsr     ptv_E_Table(pc,d0.w)
                            move.b  n_volume(a6),n_realvolume(a6)
                            rts

    ifd PTV_EFX_FILTERONOFF
ptv_FilterOnOff:
                            move.b  n_cmdlo(a6),d0
                            and.b   #1,d0
                            add.b   d0,d0
                            and.b   #$fd,$bfe001
                            or.b    d0,$bfe001
                            rts 
    endc

    ifd PTV_EFX_SETGLISSCONTROL
ptv_SetGlissControl:
                            move.b  n_cmdlo(a6),d0
                            and.b   #$f,d0
                            and.b   #$f0,n_glissfunk(a6)
                            or.b    d0,n_glissfunk(a6)
                            rts
    endc

    ifd PTV_EFX_SETVIBRATOCONTROL
ptv_SetVibratoControl:
                            move.b  n_cmdlo(a6),d0
                            and.b   #$f,d0
                            and.b   #$f0,n_wavecontrol(a6)
                            or.b    d0,n_wavecontrol(a6)
                            rts
    endc

    ifd PTV_EFX_SETFINETUNE
ptv_SetFineTune:
                            move.b  n_cmdlo(a6),d0
                            and.b   #$f,d0
                            move.b  d0,n_finetune(a6)
                            rts
    endc

    ifd PTV_EFX_JUMPLOOP
ptv_JumpLoop:
                            tst.b   ptv_counter-ptv_var(a2)
                            bne     ptv_Return
                            move.b  n_cmdlo(a6),d0
                            and.b   #$f,d0
                            beq.b   ptv_SetLoop
                            tst.b   n_loopcount(a6)
                            beq     ptv_jumpcnt
                            subq.b  #1,n_loopcount(a6)
                            beq     ptv_Return
ptv_jmploop:
                            move.b  n_pattpos(a6),ptv_PBreakPos-ptv_var(a2)
                            st.b    ptv_PBreakFlag-ptv_var(a2)
                            rts
ptv_jumpcnt:
                            move.b  d0,n_loopcount(a6)
                            bra     ptv_jmploop
ptv_SetLoop:
                            move.w  ptv_PatternPos-ptv_var(a2),d0
                            move.b  d0,n_pattpos(a6)
                            rts
    endc

    ifd PTV_EFX_SETTREMOLOCONTROL
ptv_SetTremoloControl:
                            move.b  n_cmdlo(a6),d0
                            and.b   #$f,d0
                            lsl.b   #4,d0
                            and.b   #$f,n_wavecontrol(a6)
                            or.b    d0,n_wavecontrol(a6)
                            rts
    endc

    ifd PTV_EFX_KARPLUSTRONG
ptv_KarplusStrong:
                            movem.l d1-d2/a0-a1,-(a7)
                            move.l  n_loopstart(a6),a0
                            move.l  a0,a1
                            move.l  n_replen(a6),d0
                            add.l   d0,d0
                            subq.l  #1,d0
ptv_KarPLop:
                            move.b  (a0),d1
                            ext.w   d1
                            move.b  1(a0),d2
                            ext.w   d2
                            add.w   d1,d2
                            asr.w   #1,d2
                            move.b  d2,(a0)+
                            subq.l  #1,d0
                            bne     ptv_KarPLop
                            move.b  (a0),d1
                            ext.w   d1
                            move.b  (a1),d2
                            ext.w   d2
                            add.w   d1,d2
                            asr.w   #1,d2
                            move.b  d2,(a0)
                            movem.l (a7)+,d1-d2/a0-a1
                            rts
    endc

    ifd PTV_EFX_RETRIGNOTE
ptv_RetrigNote:
                            moveq   #0,d0
                            move.b  n_cmdlo(a6),d0
                            and.b   #$f,d0
                            beq     ptv_rtnend
                            moveq   #0,d1
                            move.b  ptv_counter-ptv_var(a2),d1
                            bne     ptv_rtnskp
                            move.w  (a6),d1
                            and.w   #$fff,d1
                            bne     ptv_rtnend
                            moveq   #0,d1
                            move.b  ptv_counter-ptv_var(a2),d1
ptv_rtnskp:
                            divu    d0,d1
                            swap    d1
                            tst.w   d1
                            bne     ptv_rtnend
ptv_DoRetrig:
                            cmp.w   #4,d6
                            blt     .ptv_Nohibits
                            move.w  n_dmabithi(a6),d0
                            move.w  d0,$dff296                  ; channel dma off
                            or.w    d0,ptv_DMACONHi-ptv_var(a2)
                            bra     .ptv_Gohibits
.ptv_Nohibits:
                            move.w  n_dmabitlo(a6),d0
                            move.w  d0,$dff096                  ; channel dma off
                            or.w    d0,ptv_DMACONLo-ptv_var(a2)
.ptv_Gohibits:
                            move.l  n_start(a6),(a5)            ; set sampledata pointer
                            move.l  n_length(a6),4(a5)          ; set length
                            lea     ptv_dma_interrupt-ptv_var(a2),a1
                            move.l  ptv_vbr-ptv_var(a2),a4
                            move.l  a1,(a4)
                            move.b  #$f0,$bfd600
                            move.b  #1,$bfd700
                            move.b  #$19,$bfdf00
ptv_rtnend:
                            rts
    endc

    ifd PTV_EFX_VOLUMEFINEUP
ptv_VolumeFineUp:
                            tst.b   ptv_counter-ptv_var(a2)
                            bne     ptv_Return
                            move.b  n_cmdlo(a6),d0
                            and.b   #$f,d0
                            bra     ptv_VolSlideUp
    endc

    ifd PTV_EFX_VOLUMEFINEDOWN
ptv_VolumeFineDown:
                            tst.b   ptv_counter-ptv_var(a2)
                            bne     ptv_Return
                            move.b  n_cmdlo(a6),d0
                            and.b   #$f,d0
                            bra     ptv_VolSlideDown2
    endc

    ifd PTV_EFX_NOTECUT
ptv_NoteCut:
                            move.b  n_cmdlo(a6),d0
                            and.b   #$f,d0
                            cmp.b   ptv_counter-ptv_var(a2),d0
                            bne     ptv_Return
                            sf.b    n_volume(a6)
                            rts
    endc

    ifd PTV_EFX_NOTEDELAY
ptv_NoteDelay:
                            move.b  n_cmdlo(a6),d0
                            and.b   #$f,d0
                            cmp.b   ptv_counter-ptv_var(a2),d0
                            bne     ptv_Return
                            move.w  (a6),d0
                            and.w   #$fff,d0
                            beq     ptv_Return
                            bra     ptv_DoRetrig
    endc

    ifd PTV_EFX_PATTERNDELAY
ptv_PatternDelay:
                            tst.b   ptv_counter-ptv_var(a2)
                            bne     ptv_Return
                            move.b  n_cmdlo(a6),d0
                            and.b   #$f,d0
                            tst.b   ptv_PattDelTime2-ptv_var(a2)
                            bne     ptv_Return
                            addq.b  #1,d0
                            move.b  d0,ptv_PattDelTime-ptv_var(a2)
                            rts
    endc

    ifd PTV_EFX_FUNKIT
ptv_FunkIt:
                            tst.b   ptv_counter-ptv_var(a2)
                            bne     ptv_Return
                            move.b  n_cmdlo(a6),d0
                            and.b   #$f,d0
                            lsl.b   #4,d0
                            and.b   #$f,n_glissfunk(a6)
                            or.b    d0,n_glissfunk(a6)
                            beq     ptv_Return
ptv_UpdateFunk:
                            moveq   #0,d0
                            move.b  n_glissfunk(a6),d0
                            lsr.b   #4,d0
                            beq     ptv_funkend
                            move.b  ptv_FunkTable(pc,d0.w),d0
                            add.b   d0,n_funkoffset(a6)
                            btst    #7,n_funkoffset(a6)
                            beq     ptv_funkend
                            sf.b    n_funkoffset(a6)
                            move.l  n_loopstart(a6),d0
                            moveq   #0,d1
                            move.l  n_replen(a6),d1
                            add.l   d1,d0
                            add.l   d1,d0
                            move.l  n_wavestart(a6),a1
                            addq.l  #1,a1
                            cmp.l   d0,a1
                            blo     ptv_funkok
                            move.l  n_loopstart(a6),a1
ptv_funkok:                 move.l  a1,n_wavestart(a6)
                            moveq   #-1,d0
                            sub.b   (a1),d0
                            move.b  d0,(a1)
ptv_funkend:                rts

ptv_FunkTable:              dc.b    0,5,6,7,8,10,11,13,16,19,22,26,32,43,64,128
    endc

    endc                    ; PTV_EXTEND

ptv_SampleStarts:           dcb.l   31,0
ptv_var:

    ifd PTV_VIBRATO
ptv_VibratoTable:           dc.b    0,24,49,74,97,120,141,161
                            dc.b    180,197,212,224,235,244,250,253
                            dc.b    255,253,250,244,235,224,212,197
                            dc.b    180,161,141,120,97,74,49,24
    endc

ptv_PeriodTablePtr:         dc.w    ptv_PeriodTable-ptv_PeriodTable
    ifd PTV_FINETUNE_1
                            dc.w    ptv_PeriodTable_1-ptv_PeriodTable
    else
                            dc.w    ptv_PeriodTable-ptv_PeriodTable
    endc
    ifd PTV_FINETUNE_2
                            dc.w    ptv_PeriodTable_2-ptv_PeriodTable
    else
                            dc.w    ptv_PeriodTable-ptv_PeriodTable
    endc
    ifd PTV_FINETUNE_3
                            dc.w    ptv_PeriodTable_3-ptv_PeriodTable
    else
                            dc.w    ptv_PeriodTable-ptv_PeriodTable
    endc
    ifd PTV_FINETUNE_4
                            dc.w    ptv_PeriodTable_4-ptv_PeriodTable
    else
                            dc.w    ptv_PeriodTable-ptv_PeriodTable
    endc
    ifd PTV_FINETUNE_5
                            dc.w    ptv_PeriodTable_5-ptv_PeriodTable
    else
                            dc.w    ptv_PeriodTable-ptv_PeriodTable
    endc
    ifd PTV_FINETUNE_6
                            dc.w    ptv_PeriodTable_6-ptv_PeriodTable
    else
                            dc.w    ptv_PeriodTable-ptv_PeriodTable
    endc
    ifd PTV_FINETUNE_7
                            dc.w    ptv_PeriodTable_7-ptv_PeriodTable
    else
                            dc.w    ptv_PeriodTable-ptv_PeriodTable
    endc
    ifd PTV_FINETUNE_M8
                            dc.w    ptv_PeriodTable_m8-ptv_PeriodTable
    else
                            dc.w    ptv_PeriodTable-ptv_PeriodTable
    endc
    ifd PTV_FINETUNE_M7
                            dc.w    ptv_PeriodTable_m7-ptv_PeriodTable
    else
                            dc.w    ptv_PeriodTable-ptv_PeriodTable
    endc
    ifd PTV_FINETUNE_M6
                            dc.w    ptv_PeriodTable_m6-ptv_PeriodTable
    else
                            dc.w    ptv_PeriodTable-ptv_PeriodTable
    endc
    ifd PTV_FINETUNE_M5
                            dc.w    ptv_PeriodTable_m5-ptv_PeriodTable
    else
                            dc.w    ptv_PeriodTable-ptv_PeriodTable
    endc
    ifd PTV_FINETUNE_M4
                            dc.w    ptv_PeriodTable_m4-ptv_PeriodTable
    else
                            dc.w    ptv_PeriodTable-ptv_PeriodTable
    endc
    ifd PTV_FINETUNE_M3
                            dc.w    ptv_PeriodTable_m3-ptv_PeriodTable
    else
                            dc.w    ptv_PeriodTable-ptv_PeriodTable
    endc
    ifd PTV_FINETUNE_M2
                            dc.w    ptv_PeriodTable_m2-ptv_PeriodTable
    else
                            dc.w    ptv_PeriodTable-ptv_PeriodTable
    endc
    ifd PTV_FINETUNE_M1
                            dc.w    ptv_PeriodTable_m1-ptv_PeriodTable
    else
                            dc.w    ptv_PeriodTable-ptv_PeriodTable
    endc

                            dc.w    0

ptv_PeriodTable:            ; Tuning 0,Normal
                            dc.w    3424,3232,3048,2880,2712,2560,2416,2280,2152,2032,1920,1812
                            dc.w    1712,1616,1524,1440,1356,1280,1208,1140,1076,1016, 960, 906
                            dc.w     856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480, 453
                            dc.w     428, 404, 381, 360, 339, 320, 302, 285, 269, 254, 240, 226
                            dc.w     214, 202, 190, 180, 170, 160, 151, 143, 135, 127, 120, 113
    ifd PTV_FINETUNE_1
ptv_PeriodTable_1:
                            ; Tuning 1
                            dc.w    3400,3209,3029,2859,2698,2547,2404,2269,2141,2021,1908,1801
                            dc.w    1700,1604,1514,1429,1349,1273,1202,1134,1070,1010, 954, 900
                            dc.w     850, 802, 757, 715, 674, 637, 601, 567, 535, 505, 477, 450
                            dc.w     425, 401, 379, 357, 337, 318, 300, 284, 268, 253, 239, 225
                            dc.w     213, 201, 189, 179, 169, 159, 150, 142, 134, 126, 119, 113
    endc
    ifd PTV_FINETUNE_2
ptv_PeriodTable_2:
                            ; Tuning 2
                            dc.w    3376,3186,3007,2838,2679,2529,2387,2253,2126,2007,1894,1788
                            dc.w    1688,1593,1503,1419,1339,1264,1193,1126,1063,1003, 947, 894
                            dc.w     844, 796, 752, 709, 670, 632, 597, 563, 532, 502, 474, 447
                            dc.w     422, 398, 376, 355, 335, 316, 298, 282, 266, 251, 237, 224
                            dc.w     211, 199, 188, 177, 167, 158, 149, 141, 133, 125, 118, 112
    endc
    ifd PTV_FINETUNE_3
ptv_PeriodTable_3:
                            ; Tuning 3
                            dc.w    3352,3164,2986,2818,2660,2511,2370,2237,2111,1993,1881,1775
                            dc.w    1676,1582,1493,1409,1330,1255,1185,1118,1055, 996, 940, 887
                            dc.w     838, 791, 746, 704, 665, 628, 592, 559, 528, 498, 470, 444
                            dc.w     419, 395, 373, 352, 332, 314, 296, 280, 264, 249, 235, 222
                            dc.w     209, 198, 187, 176, 166, 157, 148, 140, 132, 125, 118, 111
    endc
    ifd PTV_FINETUNE_4
ptv_PeriodTable_4:
                            ; Tuning 4
                            dc.w    3328,3141,2964,2798,2641,2493,2353,2221,2096,1978,1867,1762
                            dc.w    1664,1570,1482,1399,1320,1246,1176,1110,1048, 989, 933, 881
                            dc.w     832, 785, 741, 699, 660, 623, 588, 555, 524, 495, 467, 441
                            dc.w     416, 392, 370, 350, 330, 312, 294, 278, 262, 247, 233, 220
                            dc.w     208, 196, 185, 175, 165, 156, 147, 139, 131, 124, 117, 110
    endc
    ifd PTV_FINETUNE_5
ptv_PeriodTable_5:
                            ; Tuning 5
                            dc.w    3304,3118,2943,2278,2622,2475,2336,2205,2081,1964,1854,1750
                            dc.w    1652,1559,1471,1389,1311,1237,1168,1102,1040, 982, 927, 875
                            dc.w     826, 779, 736, 694, 655, 619, 584, 551, 520, 491, 463, 437
                            dc.w     413, 390, 368, 347, 328, 309, 292, 276, 260, 245, 232, 219
                            dc.w     206, 195, 184, 174, 164, 155, 146, 138, 130, 123, 116, 109
    endc
    ifd PTV_FINETUNE_6
ptv_PeriodTable_6:
                            ; Tuning 6
                            dc.w    3280,3096,2922,2758,2603,2457,2319,2189,2066,1950,1840,1737
                            dc.w    1640,1548,1461,1379,1301,1228,1159,1094,1033, 975, 920, 868
                            dc.w     820, 774, 730, 689, 651, 614, 580, 547, 516, 487, 460, 434
                            dc.w     410, 387, 365, 345, 325, 307, 290, 274, 258, 244, 230, 217
                            dc.w     205, 193, 183, 172, 163, 154, 145, 137, 129, 122, 115, 109
    endc
    ifd PTV_FINETUNE_7
ptv_PeriodTable_7:
                            ; Tuning 7
                            dc.w    3256,3073,2900,2737,2584,2439,2302,2173,2051,1936,1827,1724
                            dc.w    1628,1536,1450,1368,1292,1219,1151,1086,1025, 968, 913, 862
                            dc.w     814, 768, 725, 684, 646, 610, 575, 543, 513, 484, 457, 431
                            dc.w     407, 384, 363, 342, 323, 305, 288, 272, 256, 242, 228, 216
                            dc.w     204, 192, 181, 171, 161, 152, 144, 136, 128, 121, 114, 108
    endc
    ifd PTV_FINETUNE_M8
ptv_PeriodTable_m8:
                            ; Tuning -8
                            dc.w    3628,3424,3232,3050,2879,2717,2565,2421,2285,2157,2036,1921
                            dc.w    1814,1712,1616,1525,1439,1358,1282,1210,1142,1078,1018, 960
                            dc.w     907, 856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480
                            dc.w     453, 428, 404, 381, 360, 339, 320, 302, 285, 269, 254, 240
                            dc.w     226, 214, 202, 190, 180, 170, 160, 151, 143, 135, 127, 120
    endc
    ifd PTV_FINETUNE_M7
ptv_PeriodTable_m7:
                            ; Tuning -7
                            dc.w    3600,3398,3207,3027,2857,2696,2545,2402,2267,2140,2020,1907
                            dc.w    1800,1699,1603,1513,1428,1348,1272,1201,1133,1070,1010, 953
                            dc.w     900, 850, 802, 757, 715, 675, 636, 601, 567, 535, 505, 477
                            dc.w     450, 425, 401, 379, 357, 337, 318, 300, 284, 268, 253, 238
                            dc.w     225, 212, 200, 189, 179, 169, 159, 150, 142, 134, 126, 119
    endc
    ifd PTV_FINETUNE_M6
ptv_PeriodTable_m6:
                            ; Tuning -6
                            dc.w    3576,3375,3185,3007,2838,2678,2528,2386,2252,2126,2006,1894
                            dc.w    1788,1687,1592,1503,1409,1339,1264,1193,1126,1063,1003, 947
                            dc.w     894, 844, 796, 752, 709, 670, 632, 597, 563, 532, 502, 474
                            dc.w     447, 422, 398, 376, 355, 335, 316, 298, 282, 266, 251, 237
                            dc.w     223, 211, 199, 188, 177, 167, 158, 149, 141, 133, 125, 118
    endc
    ifd PTV_FINETUNE_M5
ptv_PeriodTable_m5:
                            ; Tuning -5
                            dc.w    3548,3348,3160,2983,2816,2657,2508,2368,2235,2109,1191,1879
                            dc.w    1774,1674,1580,1491,1408,1328,1254,1184,1117,1054, 995, 939
                            dc.w     887, 838, 791, 746, 704, 665, 628, 592, 559, 528, 498, 470
                            dc.w     444, 419, 395, 373, 352, 332, 314, 296, 280, 264, 249, 235
                            dc.w     222, 209, 198, 187, 176, 166, 157, 148, 140, 132, 125, 118
    endc
    ifd PTV_FINETUNE_M4
ptv_PeriodTable_m4:
                            ; Tuning -4
                            dc.w    3524,3326,3139,2963,2797,2640,2491,2351,2219,2095,1977,1866
                            dc.w    1762,1663,1569,1481,1398,1320,1245,1175,1109,1047, 988, 933
                            dc.w     881, 832, 785, 741, 699, 660, 623, 588, 555, 524, 494, 467
                            dc.w     441, 416, 392, 370, 350, 330, 312, 294, 278, 262, 247, 233
                            dc.w     220, 208, 196, 185, 175, 165, 156, 147, 139, 131, 123, 117
    endc
    ifd PTV_FINETUNE_M3
ptv_PeriodTable_m3:
                            ; Tuning -3
                            dc.w    3500,3303,3118,2943,2777,2622,2474,2335,2204,2081,1964,1854
                            dc.w    1750,1651,1559,1471,1388,1311,1237,1167,1102,1040, 982, 927
                            dc.w     875, 826, 779, 736, 694, 655, 619, 584, 551, 520, 491, 463
                            dc.w     437, 413, 390, 368, 347, 328, 309, 292, 276, 260, 245, 232
                            dc.w     219, 206, 195, 184, 174, 164, 155, 146, 138, 130, 123, 116
    endc
    ifd PTV_FINETUNE_M2
ptv_PeriodTable_m2:
                            ; Tuning -2
                            dc.w    3472,3277,3093,2919,2755,2601,2455,2317,2187,2064,1948,1839
                            dc.w    1736,1638,1546,1459,1377,1300,1227,1158,1093,1032, 974, 919
                            dc.w     868, 820, 774, 730, 689, 651, 614, 580, 547, 516, 487, 460
                            dc.w     434, 410, 387, 365, 345, 325, 307, 290, 274, 258, 244, 230
                            dc.w     217, 205, 193, 183, 172, 163, 154, 145, 137, 129, 122, 115
    endc
    ifd PTV_FINETUNE_M1
ptv_PeriodTable_m1:
                            ; Tuning -1
                            dc.w    3448,3254,3071,2899,2736,2583,2438,2031,2172,2050,1935,1826
                            dc.w    1724,1627,1535,1449,1368,1291,1219,1150,1086,1025, 967, 913
                            dc.w     862, 814, 768, 725, 684, 646, 610, 575, 543, 513, 484, 457
                            dc.w     431, 407, 384, 363, 342, 323, 305, 288, 272, 256, 242, 228
                            dc.w     216, 203, 192, 181, 171, 161, 152, 144, 136, 128, 121, 114
    endc

; left/right volumes
ptv_PanningTable:           dc.b    $af,$50,$50,$af,$af,$50,$50,$af
                            dc.b    $af,$50,$50,$af,$af,$50,$50,$af
                            dc.b    $af,$50,$50,$af,$af,$50,$50,$af
                            dc.b    $af,$50,$50,$af,$af,$50,$50,$af

    ifd PTV_PACKED_SMP
mpegabase:                  dc.l    0
dosbase:                    dc.l    0
mp3stream:                  dc.l    0
pcm_buffers:                dc.l    0,0
mpa_ctrl:                   dc.l    0
                            dc.w    0
                            dc.w    1,2
                            dc.l    44100
                            dc.w    1,2
                            dc.l    44100
                            dc.w    0
                            dc.w    1,2
                            dc.l    44100
                            dc.w    1,2
                            dc.l    44100
                            dc.w    0
                            dc.l    0
mpeganame:                  dc.b    "mpega.library",0
dosname:                    dc.b    "dos.library",0
smpname:                    dc.b    "RAM:smp",0
                            even
    endc

ptv_chan1temp:              dcb.b   n_sizeof*MAX_CHANNELS,0
ptv_bufferstep:             dc.l    0
ptv_patternssize:           dc.l    0
ptv_chunksize:              dc.l    0
ptv_SongDataPtr:            dc.l    0
ptv_sampleslen:             dc.l    0
ptv_channels:               dc.w    0
ptv_samples:                dc.w    0
ptv_synchro:                dc.b    0
ptv_speed:                  dc.b    0
ptv_counter:                dc.b    0
ptv_SongPos:                dc.b    0
ptv_PBreakPos:              dc.b    0
ptv_PosJumpFlag:            dc.b    0
ptv_PBreakFlag:             dc.b    0
ptv_LowMask:                dc.b    0
ptv_PattDelTime:            dc.b    0
ptv_PattDelTime2:           dc.b    0
ptv_Enable:                 dc.b    0
                            even
ptv_PatternPos:             dc.w    0
ptv_DMACONHi:               dc.w    0
ptv_DMACONLo:               dc.w    0
ptv_vbr:                    dc.l    0
ptv_old_irq:                dc.l    0
ptv_repeat_irq:             dc.l    0
ptv_main_irq:               dc.l    0
ptv_oldCiaTimers:           dc.b    0
                            dc.b    0
                            dc.b    0
                            dc.b    0
ptv_TimerValue:             dc.l    0

fin:
