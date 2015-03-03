/*
 * systick.S - systick support in assembly on the STM32F4-Discovery Board
 *
 * Target: STM32F4-Discovery w/ STM32F407VGT6 processor,
 *         ROM = 1M   @ 0x08000000
 *         RAM = 192k @ 0x20000000
 *
 * REFERENCES:
 *
 * All documentation references written as "[#]-<section>" where:
 *
 * [1] = RM0090 STM32F407 Reference Manual.pdf
 * [2] = STM32F4 Discovery Schematic.pdf
 * [3] = STM32F407xx Data Sheet.pdf
 *
 */
	.syntax unified   			/* Use unified style assembly syntax */
	.thumb            			/* Cortex-M3 only supports Thumb code */

    /* Make these routines visible to other modules */
    .global systick_init

    .text

/*
 * systick_init
 *
 *
 */
 	.equ SYSTICK_CV,	0xE000E018
	.equ SYSTICK_RV,	0xE000E014
	.equ SYSTICK_CS,	0xE000E010
	.equ WAIT_CYCLES,	16000000	/*5 seconds (3200000*5)*/
systick_init:
	push {r0-r2, lr}

	ldr r0, =SYSTICK_CS		/* Disable Timer */
	mov r1, #0
	str r1, [r0]
	ldr r0, =SYSTICK_RV		/* Load # Processor cycles before interrupt*/
	ldr r2, =WAIT_CYCLES
	str r2, [r0]
	ldr r0, =SYSTICK_CV		/* Clear the current count value to 0*/
	str r1, [r0]
	ldr r0, =SYSTICK_CS
	mov r1, #7
	str r1, [r0]

  	/* Return */
  	pop {r0-r2, pc}

