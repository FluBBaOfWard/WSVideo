//
//  WSAudio.s
//  Bandai WonderSwan Sound emulation for GBA/NDS.
//
//  Created by Fredrik Ahlström on 2006-07-23.
//  Copyright © 2006-2022 Fredrik Ahlström. All rights reserved.
//

#ifdef __arm__
#include "Sphinx.i"

	.global wsAudioReset
	.global wsAudioMixer

	.syntax unified
	.arm

	.section .text
	.align 2
;@----------------------------------------------------------------------------
wsAudioReset:				;@ spxptr=r12=pointer to struct
;@----------------------------------------------------------------------------
	mov r0,#0x00000800
	str r0,[spxptr,#pcm1CurrentAddr]
	str r0,[spxptr,#pcm2CurrentAddr]
	str r0,[spxptr,#pcm3CurrentAddr]
	str r0,[spxptr,#pcm4CurrentAddr]
	mov r0,#0x80000000
	str r0,[spxptr,#noise4CurrentAddr]
	bx lr

;@----------------------------------------------------------------------------
wsAudioMixer:				;@ r0=len, r1=dest, r12=spxptr
;@----------------------------------------------------------------------------
	stmfd sp!,{r0,r1,r4-r11,lr}
;@--------------------------
	ldr r10,=vol1_L

	ldrb r5,[spxptr,#wsvHWVolume]
	add r6,r5,#1
	rsb r5,r5,#3
	cmp r5,#3
	mov r7,#0xF0
	moveq r7,#0
	mov r7,r7,lsr r5
	ldrb r9,[spxptr,#wsvSoundCtrl]

	ands r4,r9,#1					;@ Ch 1 on?
	movne r4,r7
	ldrb r2,[spxptr,#wsvSound1Vol]
	and r3,r4,r2,lsl r6
	and r2,r4,r2,lsr r5
	strb r2,[r10,#vol1_L-vol1_L]
	strb r3,[r10,#vol1_R-vol1_L]

	ands r4,r9,#2					;@ Ch 2 on?
	movne r4,r7
	tst r9,#0x20					;@ Ch 2 voice?
	movne r4,#0
	ldrb r2,[spxptr,#wsvSound2Vol]
	and r3,r4,r2,lsl r6
	and r2,r4,r2,lsr r5
	strb r2,[r10,#vol2_L-vol1_L]
	strb r3,[r10,#vol2_R-vol1_L]

	ands r4,r9,#4					;@ Ch 3 on?
	movne r4,r7
	ldrb r2,[spxptr,#wsvSound3Vol]
	and r3,r4,r2,lsl r6
	and r2,r4,r2,lsr r5
	strb r2,[r10,#vol3_L-vol1_L]
	strb r3,[r10,#vol3_R-vol1_L]

	ands r4,r9,#8					;@ Ch 4 on?
	movne r4,r7
	ldrb r2,[spxptr,#wsvSound4Vol]
	and r3,r4,r2,lsl r6
	and r2,r4,r2,lsr r5
	strb r2,[r10,#vol4_L-vol1_L]
	strb r3,[r10,#vol4_R-vol1_L]

	add r2,spxptr,#pcm1CurrentAddr
	ldmia r2,{r3-r8}
;@--------------------------
	ldrh r2,[spxptr,#wsvSound1Freq]
	mov r3,r3,lsr#11
	orr r3,r2,r3,lsl#11
;@--------------------------
	ldrh r2,[spxptr,#wsvSound2Freq]
	mov r4,r4,lsr#11
	orr r4,r2,r4,lsl#11
;@--------------------------
	ldrh r2,[spxptr,#wsvSound3Freq]
	mov r5,r5,lsr#11
	orr r5,r2,r5,lsl#11

	ldrb r2,[spxptr,#wsvSweepTime]
	add r2,r2,#1
	orr r8,r2,r8,lsl#6
	mov r8,r8,ror#6
;@--------------------------
	ands r2,r9,#0x80			;@ Ch 4 noise on?
	bic r7,r7,#0x80
	orr r7,r7,r2
	and r2,r9,#0x1F
	rsb r2,r2,#0x1F

	ldrh r9,[spxptr,#wsvSound4Freq]
	mov r6,r6,lsr#11
	orreq r6,r9,r6,lsl#11
	orrne r6,r6,r2,ror#5
	movne r6,r6,ror#21
;@--------------------------

	ldr r10,[spxptr,#gfxRAM]
	ldrb r2,[spxptr,#wsvSampleBase]
	add r10,r10,r2,lsl#6
	ldmfd sp,{r0,r1}			;@ r0=len, r1=dest buffer
	mov r0,r0,lsl#2
	b pcmMix
pcmMixReturn:
	add r0,spxptr,#pcm1CurrentAddr	;@ Counters
	stmia r0,{r3-r8}

	ldmfd sp!,{r0,r1,r4-r11,pc}
;@----------------------------------------------------------------------------

#ifdef NDS
	.section .itcm						;@ For the NDS ARM9
#elif GBA
	.section .iwram, "ax", %progbits	;@ For the GBA
#endif
	.align 2

#define PSG_DIVIDE 16
#define PSG_ADDITION 0x00008000*PSG_DIVIDE
#define PSG_SWEEP_ADD 0x00002000*4*PSG_DIVIDE
#define PSG_NOISE_FEED 0x00050001

;@----------------------------------------------------------------------------
;@ r0  = Length
;@ r1  = Destination
;@ r2  = Mixer register
;@ r3  = Channel 1
;@ r4  = Channel 2
;@ r5  = Channel 3
;@ r6  = Channel 4
;@ r10 = Sample pointer
;@ r11 =
;@----------------------------------------------------------------------------
pcmMix:				;@ r0=len, r1=dest, r12=snptr
// IIIIIVCCCCCCCCCCC0001FFFFFFFFFFF
// I=sampleindex, V=overflow, C=counter, F=frequency
;@----------------------------------------------------------------------------
mixLoop:
	mov r2,#0x80000000
innerMixLoop:
	add r3,r3,#PSG_ADDITION
	movs r9,r3,lsr#27
	mov lr,r3,lsl#20
	addcs r3,r3,lr,lsr#5
vol1_L:
	mov lr,#0x00				;@ Volume left
vol1_R:
	orrs lr,lr,#0xFF0000		;@ Volume right
	ldrb r11,[r10,r9,lsr#1]		;@ Channel 1
	tst r9,#1
	moveq r11,r11,lsr#4
	andne r11,r11,#0xF
	mla r2,lr,r11,r2

	add r4,r4,#PSG_ADDITION
	movs r9,r4,lsr#27
	add r9,r9,#0x20
	mov lr,r4,lsl#20
	addcs r4,r4,lr,lsr#5
vol2_L:
	mov lr,#0x00				;@ Volume left
vol2_R:
	orrs lr,lr,#0xFF0000		;@ Volume right
	ldrb r11,[r10,r9,lsr#1]		;@ Channel 2
	tst r9,#1
	moveq r11,r11,lsr#4
	andne r11,r11,#0xF
	mla r2,lr,r11,r2

	add r5,r5,#PSG_ADDITION
	movs r9,r5,lsr#27
	add r9,r9,#0x40
	mov lr,r5,lsl#20
	addcs r5,r5,lr,lsr#5
vol3_L:
	mov lr,#0x00				;@ Volume left
vol3_R:
	orrs lr,lr,#0xFF0000		;@ Volume right
	ldrb r11,[r10,r9,lsr#1]		;@ Channel 3
	tst r9,#1
	moveq r11,r11,lsr#4
	andne r11,r11,#0xF
	mla r2,lr,r11,r2

	add r6,r6,#PSG_ADDITION
	movs r9,r6,lsr#27
	add r9,r9,#0x60
	mov lr,r6,lsl#20
	addcs r6,r6,lr,lsr#5

	movcs lr,r7,lsr#16
	addscs r7,r7,lr,lsl#16
	ldrcs lr,=PSG_NOISE_FEED
	eorcs r7,r7,lr
	tst r7,#0x80				;@ Noise 4 enabled?
	ldrbeq r11,[r10,r9,lsr#1]	;@ Channel 4
	andsne r11,r7,#0x00000001
	movne r11,#0xFF
	tst r9,#1
	moveq r11,r11,lsr#4
	andne r11,r11,#0xF
vol4_L:
	mov lr,#0x00				;@ Volume left
vol4_R:
	orrs lr,lr,#0xFF0000		;@ Volume right
	mla r2,lr,r11,r2

	sub r0,r0,#1
	tst r0,#3
	bne innerMixLoop

//	subs r8,r8,#PSG_SWEEP_ADD
//	bhi noSweep
//	ldrb lr,[spxptr,#wsvSweepTime]
//	add lr,lr,#1
//	add r8,r8,lr,lsl#26
//	ldrsb lr,[spxptr,#wsvSweepValue]
//	mov r5,r5,ror#11
//	adds r5,r5,lr,lsl#21
//	mov r5,r5,ror#21
noSweep:
	eor r2,#0x00008000
	cmp r0,#0
	strpl r2,[r1],#4
	bhi mixLoop				;@ ?? cycles according to No$gba

	mov r2,r7,lsr#17
	strh r2,[spxptr,#wsvNoiseCntr]
	b pcmMixReturn
;@----------------------------------------------------------------------------


#endif // #ifdef __arm__
