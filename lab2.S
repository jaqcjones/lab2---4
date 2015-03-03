/*
 * lab2.S - Interrupts and Mutual Exclusion
 *
 * Target: STM32F4-Discovery w/ STM32F407VGT6 processor,
 *         ROM = 1M   @ 0x08000000
 *         RAM = 192k @ 0x20000000
 *
 */
	.syntax unified   			/* Use unified style assembly syntax */
	.thumb            			/* Cortex-M3 only supports Thumb code */

    /* Linker hints for vector table functions */
	.type reset_handler, %function
	.type NMI_handler, %function
	.type fault_handler, %function
	.type default_handler, %function
	.type systick_handler, %function
	.type USART2_handler, %function

	.equ STACK_TOP, 0x20000100     /* 256 bytes of stack in RAM region */

	/*
	 * VECTOR TABLE
	 */
	.section vectors
	/* System Handlers */
	.word STACK_TOP
	.word reset_handler    /* What to do on power-on */
	.word NMI_handler      /* Non-maskable interrupt handler */
	.word fault_handler    /* Hardware fault handler */
	.word fault_handler    /* Memory manager handler (disabled) */
	.word fault_handler    /* Bus fault (disabled) */
	.word fault_handler    /* Usage fault (disabled) */
	.word 0                /* Reserved */
	.word 0                /* Reserved */
	.word 0                /* Reserved */
	.word 0                /* Reserved */
	.word default_handler  /* System service call */
	.word default_handler  /* Debug Monitor */
	.word default_handler  /* Reserved */
	.word default_handler  /* Pendable service call */
	.word systick_handler  /* Systick */
	/* Peripheral Handlers */
	.rept 38  /* Repeat this block 38 times */
	.word default_handler  /* ISRs 0-37 */
	.endr
	.word USART2_handler   /* ISR 38, USART2 handler */
	.rept 43
	.word default_handler  /* ISRs 39-81 */
	.endr

	/* Generic code section */
	.text

	/* In the event of a non-maskable interrupt, loop here forever */
NMI_handler:
	b NMI_handler

	/* In the event of a fault, loop here forever */
fault_handler:
	b fault_handler

	/* Address system tick event */
systick_handler:
	push {lr}
	bl LED_toggle_grn
	pop {pc}

	/* Address USART2 interrupts */
USART2_handler:
	push {r2,lr}
	bl USART2_recv
	bl lock_mutex		/* Get exclusive usage of send fn */
	cmp r2, #1			/* Check if lock failed */
	beq usart2_exit
	bl USART2_send		/*Echo received character*/
	bl unlock_mutex
	bl newline
 usart2_exit:
	pop {r2,pc}

	/* Default handler for un-handled exceptions/interrupts */
default_handler:
	b default_handler


/*
 * NVIC_init:
 *
 * Set the enable bit for Interrupt #38 (USART2).
 * See the Programming Manual section 4.3.2 page 196.
 *
 * NOTE: the NVIC configuration out of power-on/reset is sufficient
 */
NVIC_init:
	.equ NVIC_ISER1, 0xE000E104      /* Interrupt Set Enable Register 1 */
	.equ NVIC_ISER1_USART2_EN, 0x40  /* Enable USART2 Global Interrupts */
	push {r0,r1,lr}
	ldr r0, =NVIC_ISER1
	ldr r1, =NVIC_ISER1_USART2_EN
	str r1, [r0]
	pop {r0,r1,pc}

/*
 * reset_handler:
 *
 * This is the code we want to run out of reset/on start-up
 */
reset_handler:
	/* Global interrupt disable - power on/reset default */
	cpsid i

	/* Enable LEDs and turn them all on */
  	bl LED_init
  	ldr r0, =LED_all
  	bl LED_on

  	/* Initialize USART2 9600 baud, 8 data, no parity, 1 stop */
  	bl USART2_init

  	.equ USART2_CR1, 0x4000440C
  	.equ USART2_SET_RXNEIE,	0x00000020
  	/* Set RXNEIE flag (bit 5) in CR1 to cause interrupt*/
	ldr r1, =USART2_CR1
	ldr r2, =USART2_SET_RXNEIE
	ldr r3, [r1]		/* read-modify-write */
	orr r3, r3, r2
	str r3, [r1]

  	/* Enable peripheral interrupts, see routine above */
  	bl NVIC_init

	/* Enable systick interrupt */
	bl systick_init

	/* Enable User Button inputs*/
	bl userbutton_init

	/* Initialise USART2_send mutex to unlocked */
  	ldr r1, =unlocked
  	ldr r3, =mutex_var
  	ldrex r2,[r3]
  	strex r2,r1,[r3]

  	/* Turn all LEDs off */
  	bl LED_off

  	/* Just toggle green LED on */
  	bl LED_toggle_grn

	/* Global interrupt enable */
  	cpsie i

	/* Show the USART2 peripheral is configured and connected */
  	mov r0, #'!'
  	bl USART2_send

  	/* Check for User button being pressed*/
	userb_loopstart:
	bl userbutton_recv
	mov r1, r0
	cmp r1, #1		/* Switch closed */
	mov r0, #5		/* Count to #n */
	beq print_count
/*	beq userb_closed */
	b userb_loopstart

	userb_closed:
	mov r0, #'u'
	bl USART2_send
	b userb_loopstart

endloop:
	b endloop  /* spin here forever in a tight loop */

/*
 * Print a new line character to terminal
 */
newlinestring:
	.ascii "\n\r"
	.align 2
newline:
	push {r0,r1,lr}
	ldr r1, =newlinestring
	ldrb r0, [r1]
	bl USART2_send
	add r1, 1
	ldrb r0, [r1]
	bl USART2_send
	pop {r0,r1,pc}

/*
 * Initialise the GPIOA port to receive input from user button, pin0
 */
userbutton_init:
	push {r0-r2,lr}
	/* Enable GPIOA peripheral clock*/
	.equ RCC_AHB1ENR,			0x40023830
	.equ RCC_AHB1ENR_GPIOAEN,	0x01
	ldr r0, =RCC_AHB1ENR
	ldr r1, =RCC_AHB1ENR_GPIOAEN
	ldr r2, [r0]
	orr r2, r2, r1
	str r2, [r0]

	/* Configure GPIOA as push-pull output or input*/
	.equ GPIOA_MODER,				0x40020000
	.equ GPIOA_MODER_PIN0_RESET_MASK,	0xfffffffe
	/*.equ GPIOA_MODER_PIN0,		0x00000001*/
	ldr r0, =GPIOA_MODER
	ldr r1, =GPIOA_MODER_PIN0_RESET_MASK
	ldr r2, [r0]		/* Read current settings */
	and r2, r2, r1		/* Reset pin 0 - set to input, 0*/

	pop {r0-r2,pc}

/*
 * Wait for user button to be pressed
 * Debounce switch
 * Return switch status in r0
 */
userbutton_recv:
	push {r1-r3,lr}
	/* Read IDR to get user button status */
	.equ GPIOA_IDR,			0x40020010
	.equ GPIOA_USERB_MASK,	0x00000001
	.equ SAMPLES,			100000
	ldr r0, =GPIOA_IDR
	ldr r1, =GPIOA_USERB_MASK
	ldr r3, =SAMPLES
 debouncer:
 	sub r3, r3, #1
 	cmp r3, #0				/* Sample switch for constant HIGH */
 	beq debouncer_end
	ldr r2, [r0]			/* Get IDR stats*/
	and r2, r2, r1			/* Get User button status from IDR*/
	cmp r2, #1				/* Button closed */
	beq debouncer
 debouncer_end:
	mov r0, r2				/* Return User button status in r0*/
	pop {r1-r3,pc}

/*
 * Output count from 1-n to the terminal in
 * one-second intervals
 * Pass n into r0
 */
print_count:
	push {r0-r2,lr}
	mov r1, r0			/* Move n into r1 */
	mov r0, #49			/* Start from 1 */
	bl lock_mutex
 start_count:
	cmp r1, #0
	beq end_count
	sub r1, r1, 1
	bl USART2_send		/* Takes r0 */
	add r0, r0, #1
 wait_1_second:
 	mov r2, r0		/* Store count value r0 in r2 before calling waitn*/
 	mov r0, #1
 	bl waitn
 	mov r0, r2		/* Restore count value in r0*/
 	b start_count
 end_count:
 	bl unlock_mutex
	pop {r0-r2,pc}

/*
 * Mutex functions
 */

/*
 * Lock mutex variable
 * Return in r2 success (0) / failure (1)
 */
 .lcomm mutex_var,4
 .equ locked,	1
 .equ unlocked,	0
lock_mutex:
	push {r1,r3,lr}
	ldr r1, =locked
	ldr r3, =mutex_var
 check_lock:
	ldrex r2,[r3]
	cmp r2, r1					/* Check if mutex locked */
	beq wait_for_update			/* Abort if locked */
	strex r2,r1,[r3]		/* Attempt to lock if unlocked */
	cmp r2, #1					/* Check if attempt failed */
	beq check_lock
	/* Lock acquired */
	dmb
 wait_for_update:
	pop {r1,r3,pc}

unlock_mutex:
	push {r1,r2,lr}
	ldr r1, =unlocked
	ldr r2, =mutex_var
	dmb
	str r1,[r2]
	pop {r1,r2,pc}

	.end


