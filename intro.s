	include	"custom.i"

;-----------
;- STARTUP -
;-----------

	move.l 4,a6                     ;execbase

;alloc mem

	move.l #$3200,d0                ;400*256 bitplan
	move.l #$10002,d1               ;in chipmem
	jsr -198(a6)                    ;allocmem
	move.l d0,bitplan               ;we store in "bitplan" the address of reserved memory
	beq end
	move.w d0,pth+6                 ;updating copperlist with this address
	swap d0
	move.w d0,pth+2

;saving old copperlist

	lea gfxname,a1
	clr.l d0
	jsr -552(a6)                    ;open graphics.library
	beq end
	move.l d0,a1                    ;graphics.library base
	move.l 38(a1),oldcop            ;saving old copperlist address
	jsr -414(a6)                    ;close graphics.library

;init new DMA, interrupts, display and copperlist

	lea custom,a0
	lea clist,a2

	move.w intenar(a0),d0
	ori.w #$8000,d0                 ;IRQ SET/CLR = 1
	move.w d0,oldintena             ;saving old INT
	move.w #$7FFF,intena(a0)        ;stops all interrupts

	move.w dmaconr(a0),d0
	ori.w #$8000,d0                 ;DMA SET/CLR = 1
	move.w d0,olddma                ;saving old DMA
	
	bsr waitvbl
	move.w #$7FFF,dmacon(a0)        ;stops all DMA
	move.w #$1000,bplcon0(a0)       ;1 bitplan lores non interlaced
	move.w #$0000,bplcon1(a0)
	move.w #$0038,ddfstrt(a0)
	move.w #$00D0,ddfstop(a0)
	move.w #$2C81,diwstrt(a0)
	move.w #$2CC1,diwstop(a0)
	move.w #$0000,bpl1mod(a0)
	move.l a2,cop1lc(a0)            ;setting copper to use our copperlist

	move.l $6c.w,oldinter           ;saving old 68K level 3 interrupt
	move.l #vblint,$6c.w            ;and setting our own vector
	move.w #$C020,intena(a0)        ;starting VBL interrupts

	move.w #$83C0,dmacon(a0)        ;starting Raster+Copper+Blitter DMA ($83E0 to add Sprites DMA)
	clr.w copjmp1(a0)               ;starting copper

	lea mt_data,a0
	bsr mt_init                     ;initializing protracker replay routine
	
;-------------------------------------------
;- Intro code : just calls to sub-routines -
;-------------------------------------------

;routine intro
intro:
	btst #6,$bfe001
	bne intro
	bra end

;---------------------------
;- Level 3 interrupt (VBL) -
;---------------------------

vblint:	
	movem.l	d0-d7/a0-a6,-(a7)       ;saves registers on stack

	bsr mt_music                    ;module playing routine

	lea custom,a0
	move.w #$4020,intreq(a0)        ;clears interrupt flag
	movem.l	(a7)+,d0-d7/a0-a6       ;restores registers from stack
	rte	
	
;------------
;- Wait VBL -
;------------

waitvbl:
	cmp.b #255,$DFF006              ;vhposr (beam position counter)
	bne.s waitvbl
	rts

;----------------
;- Wait blitter -
;----------------

waitblit:
	lea custom,a0
	btst.b #6,dmaconr(a0)
	btst.b #6,dmaconr(a0)
	bne waitblit
	rts

;-------------------
;- Wait 10 seconds -
;-------------------

wait:
	clr.b todmid
wloop:
	btst #6,$bfe001
	beq endwait
	cmp.b #$02,todmid
	bne wloop
endwait:
	rts

;------------------------------------
;- Restore old DMA, IRQ, copperlist -
;------------------------------------
	
end:
	bsr mt_end                      ;stops music
	lea custom,a0	
	move.w olddma,dmacon(a0)        ;restores old DMA
	move.w oldintena,intena(a0)     ;restores old interrupts
	move.l oldinter,$6c.w           ;restores old 68K vector
	move.l oldcop,cop1lc(a0)        ;restores initial copperlist
	move.l bitplan,a1
	move.l #$3200,d0
	move.l 4,a6                     ;execbase
	jsr -210(a6)                    ;freemem
	clr.l d0                        ;return code
	rts
	
;-------------------------
;- Module replay routine -
;-------------------------

    include "ptreplay.s"

;---------------------------------------
;- Variables, datas and replay routine -
;---------------------------------------

    section data,data

bitplan		dc.l	0
oldcop		dc.l	0
olddma		dc.w	0
oldintena	dc.w	0
oldinter	dc.l	0
gfxname		dc.b	"graphics.library",0
	
;--------------
;- Copperlist -
;--------------

	section	data_c,data_c
	
clist       dc.w	$01FC,0                 ;slow fetch mode (AGA compatibility)
            dc.w	$0180,$0004
pth         dc.w	$00E0,0,$00E2,0         ;BPL1PTH and BPL1PTL
            dc.w	$FFFF,$FFFE             ;end of copperlist

;---------------
;- Sprite data -
;---------------
	
even
BlankSprite: dc.l $20002100,0,0

;---------------
;- Module data -
;---------------

mt_data	incbin "assets/mod.neverdie16"
