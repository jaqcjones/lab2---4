/*
 * LED.S - LED support in assembly on the STM32F4-Discovery Board
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
    .global LED_init
    .global LED_on
    .global LED_off
    .global LED_toggle_grn
    .global waitn
    .global light_on

    /* Constants visible to the world ( due to ".global" below ) */
    .equ LED_grn, 0x1
    .equ LED_org, 0x2
    .equ LED_red, 0x4
    .equ LED_blu, 0x8
    .equ LED_all, 0xf

	.equ GPIOD_BSRR_SET_GREEN, 	0x00001000	/*Green LED*/

    .global LED_grn
    .global LED_red
    .global LED_org
    .global LED_blu
    .global LED_all
	.global GPIOD_BSRR_SET_GREEN

    .text

/*
 * LED_init
 *
 * Initialze the GPIOD port to drive the LEDs attached to PD12-PD15
 */
LED_init:
	push {r0-r2, lr}
	/* Enable GPIOD Peripheral Clock (using read-modify-write) */
  	.equ RCC_AHB1ENR,          0x40023830  /* ([1]-2.3 Table 2) */
  	.equ RCC_AHB1ENR_GPIODEN,  0x08        /* ([1]-6.3.12) */
  	ldr r0, =RCC_AHB1ENR          /* r0=addr of GPIO Clock Enable Register */
  	ldr r1, =RCC_AHB1ENR_GPIODEN  /* r1=Port D Enable Bit */
  	ldr r2, [r0]
  	orr r2, r2, r1
  	str r2, [r0]			      /* Store #0x08 into address 0x40023830 */

  	/* Configure GPIOs connected to LEDs as output, push-pull */
   	.equ GPIOD_MODER,          0x40020C00   /* ([1]-2.3, [1]-7.4.1) */
  	.equ GPIOD_MODER_LEDS_OUT, 0x55000000   /* ([1]-7.4.1) */
  	.equ GPIOD_MODER_LEDS_MASK, 0x00fffffff /* Reset bits 23-31 */
  	ldr r0, =GPIOD_MODER
  	ldr r1, =GPIOD_MODER_LEDS_MASK
  	ldr r2, [r0]
  	and r2, r2, r1
  	ldr r1, =GPIOD_MODER_LEDS_OUT
  	orr r2, r2, r1
  	str r2, [r0]

  	/* Return */
  	pop {r0-r2, pc}

	.equ GPIOD_BSRR,	0x40020C18
    .equ GPIOD_IDR,		0x40020C10
    .equ GPIOD_BSRR_SET_GREEN, 	0x00001000	/*Green LED*/
	.equ GPIOD_BSRR_SET_ORANGE,	0x00002000	/*Orange LED*/
	.equ GPIOD_BSRR_SET_RED,	0x00004000	/*Red LED*/
	.equ GPIOD_BSRR_SET_BLUE,	0x00008000	/*Blue LED*/
	.equ GPIOD_BSRR_SET_GOB,	0x0000B000	/*Blue,Orange,Green LEDS*/
    .equ IDR_GREEN_MASK,	0x00001000
	.equ IDR_ORANGE_MASK,	0x00002000
	.equ IDR_BLUE_MASK,		0x00008000
	.equ IDR_GOB_MASK,		0x0000B000
/*
 * LED_on:
 *
 * Turn on the LEDs flagged in register r0
 */
LED_on:
	push {r0,r1,lr}
	/* Replace with your code */
	ldr r1, =GPIOD_BSRR		/**/
	lsl r0, 12
	str r0, [r1]
	pop {r0,r1,pc}


/*
 * LED_off:
 *
 * Turn off the LEDs flagged in register r0
 */
LED_off:
	push {r0,r1,lr}
	/* Replace with your code */
	ldr r1, =GPIOD_BSRR		/**/
	lsl r0, 28
	str r0, [r1]
	pop {r0,r1,pc}

/*
 * LED_toggle_grn:
 *
 * Toggle the state of the green LED
 */
LED_toggle_grn:
	push {r1,r2,r3,r4,r5,lr}
	/* Replace with your code */
	ldr r3, =GPIOD_IDR
	ldr r4, [r3]		/* Get status of LEDS on/off */
	ldr r5, =IDR_GREEN_MASK
	and r4, r4, r5
	cmp r4, #0
	ldr r1, =GPIOD_BSRR_SET_GREEN

	beq toggle_light
	lsl r1, 16

	bne toggle_light
 toggle_light:
	ldr r2, =GPIOD_BSRR		/**/
	str r1, [r2]
	pop {r1,r2,r3,r4,r5,pc}

/*
 * Waits for n seconds
 * Pass n into r0
 */
waitn:
	push {r0,r1,r2,lr}
	mov r1, #0
 loopstart:
	cmp r1, r0
	bge loopend
	.equ BUSYWAIT_1_SECOND, 3200000		/* Wait for 1 second */
	ldr r2, =BUSYWAIT_1_SECOND
 waitloop:
	sub r2, r2, #1
	cmp r2, #0
	bne waitloop
	add r1, #1
	b loopstart
 loopend:
	pop {r0,r1,r2,pc}

/*
 * Turns LED on for a number of seconds
 * Pass LED address into r1
 * Pass # seconds to wait into r0
 */
light_on:
	push {r0,r1,r2,lr}
	ldr r2, =GPIOD_BSRR
	str r1, [r2]
	/*mov r0, #1*/
	bl waitn
	ldr r2, =GPIOD_BSRR
	lsl r1, 16
	str r1, [r2]
	/*mov r0, #1*/
	bl waitn
	pop {r0,r1,r2,pc}

	.end
