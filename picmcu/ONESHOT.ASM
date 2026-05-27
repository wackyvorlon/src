    title  "Electric Druid One Shot Waveform Generator"
;============================================================================
; The Electric Druid One Shot Waveform Generator
;============================================================================
; Legal stuff
; Copyright 2018 Tom Wiltshire for Electric Druid. Some rights reserved.
; This code is shared under a Creative Commons
; Attribution-NonCommercial-ShareAlike 4.0 International Licence
; For full details see www.electricdruid.net/legalstuff
; or get in touch at www.electricdruid.net/contact.
;============================================================================
; 24th April 2018
; From an idea by Mark Hammer - thanks Mark!
;
; Hardware Notes:
;   PIC16F18313 running at 32 MHz using the internal clock
; 1  +5V
; 2  RA5/AN5		: 0-5V Repeats CV
; 3  RA4			: PDM Output
; 4  RA3/~MCLR/Vpp	: Trigger input
; 5  RA2/AN2		: 0-5V Delay CV
; 6  RA1/AN1		: 0-5V Waveform CV
; 7  RA0/AN0		: 0-5V Rate CV
; 8  Gnd
	
; This code produces a sequence of unipolar 'pings' - mini envelopes. There are
; eight selectable ping shapes, and you can change the rate of the ping so it
; takes longer (up to 2.5secs) or less long (down to 55msecs).
; The number of pings is variable from 1 to 36 and you can set a variable delay
; between pings in the sequence, from 0 to 2.2 secs.
	
    LIST R=DEC
    INCLUDE <p16f18313.inc>
    Errorlevel -302

; 16F18313 Configuration
    __CONFIG _CONFIG1, _FEXTOSC_OFF & _RSTOSC_HFINT32 & _CLKOUTEN_OFF & _CSWEN_OFF & _FCMEN_OFF
    __CONFIG _CONFIG2, _MCLRE_OFF & _PWRTE_OFF &_WDTE_OFF & _LPBOREN_OFF &_BOREN_OFF & _PPS1WAY_OFF & _STVREN_OFF & _DEBUG_OFF
    __CONFIG _CONFIG3, _WRT_OFF & _LVP_OFF
    __CONFIG _CONFIG4, _CP_OFF & _CPD_OFF


;----------------------------------------------------------------------------
;	Variables (80 bytes available here, and 16 more in Common RAM)
;----------------------------------------------------------------------------
 CBLOCK 0x020
	; In this code, the raw ADC values are all IIR filtered before use
 
    ; The filtered control values 
	RATE_HI						; Rate
	WAVE_HI						; Waveform
	DELAY_HI					; Delay
	REPEATS_HI					; Repeats
	RATE_LO
	WAVE_LO
	DELAY_LO
	REPEATS_LO
	
	; The working storage for the Control filters
	CTRL_IN_HI					; This is shared by all four filters
	CTRL_IN_LO	
	
	; The final value used in the code
	WAVEFORM					; Waveform 0-7			
	
	; Input debouncing routine for Trigger input
	DEBOUNCE_BIT3				; Debounce vertical counter
	DEBOUNCE_BIT2
	DEBOUNCE_BIT1
	DEBOUNCE_BIT0
	IN_STATE					; State of all inputs (flags)
	IN_CHANGES					; Input changes (flags)
	
	; The One Shot waveform generator
    FREQ_HI						; The 24-bit frequency increment
    FREQ_MID
    FREQ_LO
    PHASE_HI					; The 24-bit phase accumulator
    PHASE_MID
    PHASE_LO
	
	; The frequency increment for when we're doing a delay between pings
	WAIT_HI
    WAIT_MID
    WAIT_LO
	
	; The Offset (if any)
	OFFSET_HI					; This allows us to start from non-zero
	OFFSET_LO
	
	; The current output level (the volume)
	LEVEL_HI					; This decreases according to REPEATS
	LEVEL_LO
	
	; The rate of volume decay (sets the number of repeats)
	DECAY_HI
	DECAY_LO
	
    ; The waveform interpolation variables
    WAVE_X_HI					; We interp between two 16-bit variables
    WAVE_X_LO
    WAVE_Y_HI
    WAVE_Y_LO
    INTERP_INDEX				; This is the index
	
    ; The raw waveform output from the tables (10-bit, left-aligned)
    WAVEFORM_HI
    WAVEFORM_LO
	
 ENDC

;----------------------------------------------------------------------------
; 0x70-0x7F  Common RAM - Special variables available in all banks
;----------------------------------------------------------------------------
 CBLOCK 0x070	
    ; Various flag bits. 1 is on,obviously.
    FLAGS						; See Define statements below for details
    TEMP						; Basic temporary storage
    ; The current A/D channel and value
    ADC_CHANNEL
    ADC_VALUE
    ; The final output, as sent to the PWM/PDM module
    FINAL_UP
    FINAL_HI
    FINAL_LO
 ENDC

;----------------------------------------------------------------------------
;	DEFINE STATEMENTS
;----------------------------------------------------------------------------

; Useful bit definitions for clarity
#define	ZERO			STATUS, Z		; Zero Flag
#define CARRY			STATUS, C		; Carry
#define NOT_BORROW		STATUS, C		; Borrow is the same as Carry

; System Flag bit definitions
#define TRIGGERED		FLAGS, 0		; 0=Not running, 1=Running
#define DELAY_ON		FLAGS, 1		; 0=Delay off, 1=Delay on
#define DELAY_NOT_PING	FLAGS, 2		; 0=Ping, 1=Delay between pings
#define OFFSET_APPLIED	FLAGS, 3		; 0=No offset, 1=Offset being applied
 
; Trigger input
#define TRIGGER			PORTA, 3
 
; Bits in the debounce variables
#define	TRIG_STATE		IN_STATE, 3		; Debounced state of Trigger Input
#define	TRIG_CHANGED	IN_CHANGES, 3	; Has TRIG_STATE changed?


;----------------------------------------------------------------------------
;	In the beginning, all was 0x000 and NOP...
;----------------------------------------------------------------------------
    org     0x0000				; Processor reset vector
    nop							; for ICD use
    goto    Main				; Go to the main program

;----------------------------------------------------------------------------
;	Interrupt Routines
;----------------------------------------------------------------------------
    org     0x0004				; Interrupt vector location
InterruptEnter:
    movlb	D'0'				; Bank 0
    bcf		PIR1, TMR2IF		; Clear TMR2 interrupt flag
	
	; Do we actually need to do anything?
	btfss	TRIGGERED
	goto	InterruptExit		; No, we haven't been triggered
	
	; Are we doing a ping or a delay?
	btfsc	DELAY_NOT_PING
	goto	DoDelayBetweenPings

; Produce a ping
;------------------------------------------------------------------------------
DoPing:							; Looking at you, Lance Armstrong!
	; Add 24-bit freq inc to 24-bit phase accumulator
    movf	FREQ_LO, w
    addwf	PHASE_LO, f
    movf	FREQ_MID, w
    addwfc	PHASE_MID, f
    movf	FREQ_HI, w
    addwfc	PHASE_HI, f
	; Did the phase overflow? (This would be the ping finishing)
    btfsc	CARRY
    goto	PingFinished		; Yes, it finished
	
	; Did we reach the maximum value? (the halfway point?)
	btfss	OFFSET_APPLIED		; Do we even need to check?
	goto	SelectWaveform		; No, we don't
	; OK, we might have reached halfway
	btfss	PHASE_HI, 7
	goto	SelectWaveform		; No, we haven't reached it yet
	; We've reached halfway. We can ignore the offset from here
	clrf	OFFSET_LO			; Clear the offset
	clrf	OFFSET_HI
	movlw	D'255'				; Clear the Level scaling (use max)
	movwf	LEVEL_LO
	movwf	LEVEL_HI
	bcf		OFFSET_APPLIED		; Offset is no longer applied
	goto	SelectWaveform
	
PingFinished:
; Yes, the ping waveform finished
	; Reset the phase
	clrf	PHASE_HI
	clrf	PHASE_MID
	clrf	PHASE_LO
	; If the delay is on, we do a delay before the next ping
	btfsc	DELAY_ON
	bsf		DELAY_NOT_PING		; Ok, we're doing a delay next time
	; Decrement the LEVEL for the next one
	movf	DECAY_LO, w
	subwf	LEVEL_LO, f
	movf	DECAY_HI, w
	subwfb	LEVEL_HI, f
	; LEVEL may have overshot zero into negative numbers
	btfss	CARRY
	goto	OneShotEnded		; Yes, it's negative
	; Has the LEVEL reached zero?
	btfsc	ZERO
	goto	OneShotEnded		; Yes, we've hit zero
	; Otherwise, we have more repeats still to do

; Which waveform table should we use?
SelectWaveform:
    movf	WAVEFORM, w			; Get current waveform
    brw
    goto	Sine
    goto	Cosine
	goto	LogDown
    goto	LogUp
	goto	ExpoDown
    goto	RampDown	
    goto	RampUp
    goto	InvSine

	
; This is essentially a waveform output routine for the "off" state.
OneShotEnded:
	; Make sure we zero the output and the level
	clrf	WAVEFORM_HI
	clrf	WAVEFORM_LO
;	clrf	OFFSET_HI
;	clrf	OFFSET_LO	
	clrf	LEVEL_HI	
	bcf		TRIGGERED			; Turn the One-shot off again
	; Ok, we're all done until next time, but we need to make sure that
	; the NCO outputs nothing, so we continue until the end of the interrupt.


; All waveforms return to here
ReturnWithValue:
	; (Sometimes I've needed to do stuff in here before we deal with Level)
	
; Modify the output level (Make echoes die away)
;---------------------------------------------------------
MultiplyByLevel:
	clrf	FINAL_HI
	clrf	FINAL_LO
	movf	LEVEL_HI, w
	clrc
	btfsc	WAVEFORM_LO, 0
	addwf	FINAL_HI, f
	rrf		FINAL_HI, f
	rrf		FINAL_LO, f
	btfsc	WAVEFORM_LO, 1
	addwf	FINAL_HI, f
	rrf		FINAL_HI, f
	rrf		FINAL_LO, f
	btfsc	WAVEFORM_LO, 2
	addwf	FINAL_HI, f
	rrf		FINAL_HI, f
	rrf		FINAL_LO, f
	btfsc	WAVEFORM_LO, 3
	addwf	FINAL_HI, f
	rrf		FINAL_HI, f
	rrf		FINAL_LO, f
	btfsc	WAVEFORM_LO, 4
	addwf	FINAL_HI, f
	rrf		FINAL_HI, f
	rrf		FINAL_LO, f
	btfsc	WAVEFORM_LO, 5
	addwf	FINAL_HI, f
	rrf		FINAL_HI, f
	rrf		FINAL_LO, f
	btfsc	WAVEFORM_LO, 6
	addwf	FINAL_HI, f
	rrf		FINAL_HI, f
	rrf		FINAL_LO, f
	btfsc	WAVEFORM_LO, 7
	addwf	FINAL_HI, f
	rrf		FINAL_HI, f
	rrf		FINAL_LO, f
; Need to start clearing the carry from here on because bits can go off the RHS
	clrc
	btfsc	WAVEFORM_HI, 0
	addwf	FINAL_HI, f
	rrf		FINAL_HI, f
	rrf		FINAL_LO, f
	clrc
	btfsc	WAVEFORM_HI, 1
	addwf	FINAL_HI, f
	rrf		FINAL_HI, f
	rrf		FINAL_LO, f
	clrc
	btfsc	WAVEFORM_HI, 2
	addwf	FINAL_HI, f
	rrf		FINAL_HI, f
	rrf		FINAL_LO, f
	clrc
	btfsc	WAVEFORM_HI, 3
	addwf	FINAL_HI, f
	rrf		FINAL_HI, f
	rrf		FINAL_LO, f
	clrc
	btfsc	WAVEFORM_HI, 4
	addwf	FINAL_HI, f
	rrf		FINAL_HI, f
	rrf		FINAL_LO, f
	clrc
	btfsc	WAVEFORM_HI, 5
	addwf	FINAL_HI, f
	rrf		FINAL_HI, f
	rrf		FINAL_LO, f
	clrc
	btfsc	WAVEFORM_HI, 6
	addwf	FINAL_HI, f
	rrf		FINAL_HI, f
	rrf		FINAL_LO, f
	clrc
	btfsc	WAVEFORM_HI, 7
	addwf	FINAL_HI, f
	rrf		FINAL_HI, f
	rrf		FINAL_LO, f
	
	; Add any offset we need
	movf	OFFSET_LO, w
	addwf	FINAL_LO, f
	movf	OFFSET_HI, w
	addwf	FINAL_HI, f
	
	; Ok, we've got our final ping signal
	goto	PDMOutput
	

; Produce a delay between pings
;------------------------------------------------------------------------------
DoDelayBetweenPings:
	; Increment the phase accumulator
    movf	WAIT_LO, w
    addwf	PHASE_LO, f
    movf	WAIT_MID, w
    addwfc	PHASE_MID, f
    movf	WAIT_HI, w
    addwfc	PHASE_HI, f
	; Did the phase overflow? (This would be the delay finishing)
    btfss	CARRY
    goto	OutputNothing		; No, not yet
	
; Yes, the delay finished
	; Reset the phase
	clrf	PHASE_HI
	clrf	PHASE_MID
	clrf	PHASE_LO
	bcf		DELAY_NOT_PING		; Ok, we're doing a ping next time
	
OutputNothing:
; We output zero when we're doing a delay - very simple
	clrf	FINAL_LO
	clrf	FINAL_HI	
	
	
; Output the final value using the NCO peripheral for pulse density modulation
;------------------------------------------------------------------------------
PDMOutput:
	
	; DEBUG - Show me the LEVEL directly
;	movf	PHASE_LO, w
;	movwf	FINAL_LO
;	movf	PHASE_HI, w
;	movwf	FINAL_HI	
;	
	
	; Put the final value in the NCO without altering FINAL_HI/LO
	movlb	D'9'				; Bank 9
	clrf	FINAL_UP
    ; Do a shift up
    lslf	FINAL_LO, w
	rlf		FINAL_HI, w
	movwf	NCO1INCH
	rlf		FINAL_UP, w
	movwf	NCO1INCU
    lslf	FINAL_LO, w		; NCO's internal Buffered INC registers are..
	movwf	NCO1INCL		; loaded after NCO1INCL is written
	

InterruptExit:
    retfie


;----------------------------------------------------------------------------
; Analogue to Digital conversion subroutine
;----------------------------------------------------------------------------
; This is used by the main code loop
; It expects to be passed the required channel in W
DoADConversion:
	movlb	D'1'				; Bank 1
	movwf	ADCON0				; Set ADC to required channel
    ; Short delay whilst the channel settles
	movlw   D'100'
	movwf   TEMP			
	nop
	decfsz  TEMP, f
	goto    $-2
	; Start the conversion
	bsf     ADCON0, GO
	; Wait for it to finish
	btfsc   ADCON0, GO			 ; Is it done?
	goto   $ - 1
	;  Read the ADC Value and store it
	movf    ADRESH, w			; Get the CV
	movwf	ADC_VALUE
	movlb	D'0'				; Bank 0
	return

	
;----------------------------------------------------------------------------
;	MAIN PROGRAM
; This sets everything up before moving into the ADC reading loop.
;----------------------------------------------------------------------------
Main:
	; Clock is set for 32MHz internal by config flags

	; Set up the IO Ports
	movlb	D'1'				; Bank 1
	movlw	B'00101111'			; All inputs except RA4, the PDM output
	movwf	TRISA

	; Interrupt Enables
	bsf		INTCON, GIE			; Enable interrupts
	bsf		INTCON, PEIE		; Enable Peripheral interrupts
	bsf		PIE1, TMR2IE		; Enable Timer2 interrupt

	; Set up weak pull-ups
	movlb	D'4'				; Bank 4
	movlw	B'00001000'			; Weak pull up on RA3 (Trigger) only
	movwf	WPUA

	; Set up Analog-to-digital convertor and ADC inputs
	movlb	D'3'				; Bank 3
	movlw	B'00100111'			; 4 Analog inputs on RA0-RA2, RA5
	movwf	ANSELA
	movlb	D'1'				; Bank 1
	movlw	B'01100000'			; Left-justified, Fosc/64
	movwf	ADCON1

	; Set up both indirection pointers for Bank0
	clrf	FSR0H				; Used by main code
	clrf	FSR1H				; Used by interrupt

 	; Set up Timer2 for sample rate timebase
	movlb	D'0'				; Bank 0
	bcf		PIR1, TMR2IF		; Clear interrupt flag
	clrf	TMR2				; Clear timer
	movlw	B'00000000'			; Prescale 1:1, Postscale 1:1
	movwf	T2CON
	movlw	D'255'				; 10-bit period register
	movwf	PR2					; 32MHz/1024 = 31.25KHz

;----------------------------------
; Option 1 - Set up for PWM output
;----------------------------------
 	; Set up Peripheral Pin Select
;	movlb	D'29'				; Bank 29
;	movlw	B'00000010'			; Rxy source is PWM5
;	movwf	RA4PPS				; RA4 is PWM5 output
 
	; Set up PWM1 module
;	movlb	D'12'				; Bank 12
;	clrf	PWM5CON				; PWM Off, Non-inverted
;	movlw	D'128'				; 50% Duty cycle default
;	movwf	PWM5DCH				; Upper 8 bits
;	clrf	PWM5DCL				; Lower 2 bits
;	bsf		PWM5CON, PWM5EN		; Switch it on!
	
	
;----------------------------------
; Option 2 - Set up for NCO output
;----------------------------------
	; Set up Peripheral Pin Select
	movlb	D'29'				; Bank 29
	movlw	B'00011101'			; Rxy source is NCO
	movwf	RA4PPS				; RA4 is NCO output

 	; Set up Numerically Controlled Oscillator
	movlb	D'9'				; Bank 9
	movlw	B'10000001'			; Enable NCO, Active high, Pulse frequency mode
	movwf	NCO1CON
	movlw	B'01100000'
	movwf	NCO1CLK				; Output active for 8 clocks, 16MHz HFINTOSC
	clrf	NCO1ACCL			; Clear accumulator
	clrf	NCO1ACCH
	clrf	NCO1ACCU
	; Set up a frequency increment
	clrf	NCO1INCU			; (Regs are loaded when NCOxINCL is set)
	clrf	NCO1INCH
	clrf	NCO1INCL

	; Set up initial values of the variables
	movlb	D'0'				; Bank 0
	clrf	FLAGS
	clrf	ADC_CHANNEL			; We start by inc, so Channel 1
	
	; Clear the debounce variables
	clrf	DEBOUNCE_BIT3
	clrf	DEBOUNCE_BIT2
	clrf	DEBOUNCE_BIT1
	clrf	DEBOUNCE_BIT0

	; Set up input filter variables
	clrf	RATE_HI				; The filter high bytes
	clrf	WAVE_HI
	clrf	DELAY_HI
	clrf	REPEATS_HI
	clrf	RATE_LO				; The filter low bytes
	clrf	WAVE_LO
	clrf	DELAY_LO
	clrf	REPEATS_LO
	
	; This is a derived variable that we use in the rest of the code
	clrf	WAVEFORM			; Waveform 0-7

	; Set up one shot waveform generator
	clrf	PHASE_LO			; Clear Accumulator
	clrf	PHASE_MID
	clrf	PHASE_HI
	clrf	FREQ_LO				; Clear Frequency Increment
	clrf	FREQ_MID
	clrf	FREQ_HI
	clrf	WAIT_LO				; Clear Freq Inc for delay between pings
	clrf	WAIT_MID
	clrf	WAIT_HI

	; Start up the sample rate timer and we're off!
	bsf		T2CON, TMR2ON		; Switch it on!

;----------------------------------------------------------------------------
;	MAIN LOOP
;----------------------------------------------------------------------------
; This just cyclically scans the controls and updates variables as required.
	
MainLoop:
;---------------------------------------------------------
;	Test and debounce the digital inputs
;---------------------------------------------------------
; Do Scott Dattalo's vertical counter debounce (www.dattalo.com)
; This could debounce eight inputs, but I'm only using one: RA3 TRIGGER
; This is not efficient for a single input, but I don't care.

DebounceInputs:
	; Increment the vertical counter
	; Deal with Bit 3
	movf	DEBOUNCE_BIT0, w
	andwf	DEBOUNCE_BIT1, w
	andwf	DEBOUNCE_BIT2, w	
	xorwf	DEBOUNCE_BIT3, f	
	; Deal with Bit 2
	movf	DEBOUNCE_BIT0, w
	andwf	DEBOUNCE_BIT1, w
	xorwf	DEBOUNCE_BIT2, f
	; Deal with Bit 1
	movf	DEBOUNCE_BIT0, w
	xorwf	DEBOUNCE_BIT1, f
	; Deal with Bit 0
	comf	DEBOUNCE_BIT0, f
	; See if any changes occured
	movf	PORTA, w			; Get the RA3 input
	xorwf	IN_STATE, w			; Test for changes
	; Reset the counter if no change occured
	andwf	DEBOUNCE_BIT3, f
	andwf	DEBOUNCE_BIT2, f
	andwf	DEBOUNCE_BIT1, f
	andwf	DEBOUNCE_BIT0, f
	; If there is a pending change and the count has rolled over
	; to 0, then the change has been filtered
	xorlw	0xFF				; Invert the changes
	iorwf	DEBOUNCE_BIT3, w	; If count is 0, all bits are 0
	iorwf	DEBOUNCE_BIT2, w
	iorwf	DEBOUNCE_BIT1, w
	iorwf	DEBOUNCE_BIT0, w
	; Any bit in W that is clear at this point means that the input
	; has changed and the count rolled over
	xorlw	0xFF				; Invert the changes
	xorwf	IN_STATE, f			; Update the changes
	; W is left holding state of all filtered bits that have changed.
	movwf	IN_CHANGES
	
	
;---------------------------------------------------------
; Deal with the TRIGGER Input
;---------------------------------------------------------
; I'm only interested in when the TAP_IN goes low (button pressed)
; and not in when it is released, so that is ignored.
TriggerInput:
	; Has the TRIGGER input changed state?
	btfss	TRIG_CHANGED
	goto	NextADCChannel		; No, so skip
	; Has it gone low (pressed)?
	btfsc	TRIG_STATE
	goto	NextADCChannel		; No, so skip

;  Our One-Shot has been triggered!
Triggered:
	; We always start with a ping..
	bcf		DELAY_NOT_PING		; ..so clear this flag!
	; Reset One-shot to beginning of cycle
	clrf	PHASE_HI	
	clrf	PHASE_MID
	clrf	PHASE_LO
	; Reset the level (it decayed to zero)
	movlw	D'255'
	movwf	LEVEL_HI
	movwf	LEVEL_LO
	; Do I need to use an offset?
	movf	WAVEFORM, w
	andlw	0x06				; We only use offset and scaling for..
	btfss	ZERO				; ..the sine and cosine waveforms
	goto	NoOffset
	
UseOffset:
	; Get our current output to use as the offset
	; To correctly scale the output, I need LEVEL = Max - Offset
	movf	FINAL_LO, w
	movwf	OFFSET_LO			; Note this offset may be zero
	subwf	LEVEL_LO, f
	movf	FINAL_HI, w
	movwf	OFFSET_HI
	subwfb	LEVEL_HI, f
	; Start the One-shot
	bsf		TRIGGERED
	bsf		OFFSET_APPLIED
	goto	NextADCChannel
	
NoOffset:
	clrf	OFFSET_LO
	clrf	OFFSET_HI
	; Start the One-shot
	bsf		TRIGGERED
	bcf		OFFSET_APPLIED
	
;---------------------------------------------------------
;	Check the Control inputs
;---------------------------------------------------------
NextADCChannel:
	; Change to next A/D channel
	incf	ADC_CHANNEL, f

SelectADCChannel:
	movf	ADC_CHANNEL, w		; Get current channel
	andlw	D'3'				; Only need two LSBs
	brw
	goto	RateControl
	goto	WaveformControl
	goto	DelayControl
	goto	RepeatsControl	
	

;----------------------------------------------------------------------------
;	CONTROL KNOBS
;----------------------------------------------------------------------------
	
RateControl:
	movlw	b'00000001'			; AN0	Rate CV
	call	DoADConversion		; Returns value in ADC_VALUE
	; Store input value as 16 bit value
	movwf	CTRL_IN_HI
	clrf	CTRL_IN_LO
	; Subtract stored filter value from new CTRL_IN 
	movf	RATE_LO, w
    subwf	CTRL_IN_LO, f		; CTRL_IN = CTRL_IN - FILTER
    movf	RATE_HI, w
    subwfb	CTRL_IN_HI, f
    ; Flip the state of the borrow flag
    movf	STATUS, w			; Copy STATUS to W
    xorlw	0x01				; Invert the Carry/Borrow flag
    movwf	STATUS				; Write it back
    ; Do the downshifts (x 1/16 effectively)
    rrf		CTRL_IN_HI, f		; Shift in the borrow flag
    rrf		CTRL_IN_LO, f
    asrf	CTRL_IN_HI, f		; ASRF propagates it down into the result
    rrf		CTRL_IN_LO, f
    asrf	CTRL_IN_HI, f
    rrf		CTRL_IN_LO, f
    asrf	CTRL_IN_HI, f
    rrf		CTRL_IN_LO, f		; 4 shifts total
    ; Add it to FILTER
    movf	CTRL_IN_LO, w
    addwf	RATE_LO, f
    movf	CTRL_IN_HI, w
    addwfc	RATE_HI, f			; This is our filtered control value
	
	; Work out the table index to look up the Freq Inc
	movf    RATE_HI, w
	movwf	FSR0L				; Store index x 1
	clrf	FSR0H
	lslf	FSR0L, f
	rlf		FSR0H, f			; Shift up to x2
	; Add the base address of the table
	movlw	LOW FreqControlLookup
	addwf	FSR0L, f
	movlw	HIGH FreqControlLookup
	addwfc	FSR0H, f
	; Read the values/Do the conversion
	clrf	FREQ_HI
	moviw	FSR0++
	movwf	FREQ_MID
	moviw	FSR0++
	movwf	FREQ_LO
	; All done! Go back to the beginning!
	goto	ReciteMantra
	
	
WaveformControl:
	movlw	b'00000101'			; AN1	Waveform CV
	call	DoADConversion		; Returns value in ADC_VALUE
	; Store input value as 16 bit value
	movwf	CTRL_IN_HI
	clrf	CTRL_IN_LO
	; Subtract stored filter value from new CTRL_IN 
	movf	WAVE_LO, w
    subwf	CTRL_IN_LO, f		; CTRL_IN = CTRL_IN - FILTER
    movf	WAVE_HI, w
    subwfb	CTRL_IN_HI, f
    ; Flip the state of the borrow flag
    movf	STATUS, w			; Copy STATUS to W
    xorlw	0x01				; Invert the Carry/Borrow flag
    movwf	STATUS				; Write it back
    ; Do the downshifts (x 1/16 effectively)
    rrf		CTRL_IN_HI, f		; Shift in the borrow flag
    rrf		CTRL_IN_LO, f
    asrf	CTRL_IN_HI, f		; ASRF propagates it down into the result
    rrf		CTRL_IN_LO, f
    asrf	CTRL_IN_HI, f
    rrf		CTRL_IN_LO, f
    asrf	CTRL_IN_HI, f
    rrf		CTRL_IN_LO, f		; 4 shifts total
    ; Add it to FILTER
    movf	CTRL_IN_LO, w
    addwf	WAVE_LO, f
    movf	CTRL_IN_HI, w
    addwfc	WAVE_HI, f			; This is our filtered control value
	; Apply hysteresis to the CV by checking if ADC_VALUE and
	; ADC_VALUE+4 give the same result
	movf	WAVE_HI, w
	addlw	D'4'				; Add 4 to the AD value in W
	andlw	B'11100000'			; Get the top 3 bits (Result 1)
	movwf	TEMP
	movf	WAVE_HI, w
	andlw	B'11100000'			; Get the top 3 bits (Result 2)
	xorwf	TEMP, w				; Test if the two results are the same
	btfss	ZERO				; If zero, they're the same
	goto	ReciteMantra		; Not the same, no need to change waveform
	; We need to change the waveform
	swapf	WAVE_HI, w			; Get the high nibble
	andlw	0x0E				; Mask unwanted bits
	movwf	WAVEFORM
	lsrf	WAVEFORM, f			; Shift down to 0-7 range
	; All done! Go back to the beginning!
	goto	ReciteMantra


DelayControl:
	movlw	b'00001001'			; AN2	Delay CV
	call	DoADConversion		; Returns value in ADC_VALUE
	; Store input value as 16 bit value
	movwf	CTRL_IN_HI
	clrf	CTRL_IN_LO
	; Subtract stored filter value from new CTRL_IN 
	movf	DELAY_LO, w
    subwf	CTRL_IN_LO, f		; CTRL_IN = CTRL_IN - FILTER
    movf	DELAY_HI, w
    subwfb	CTRL_IN_HI, f
    ; Flip the state of the borrow flag
    movf	STATUS, w			; Copy STATUS to W
    xorlw	0x01				; Invert the Carry/Borrow flag
    movwf	STATUS				; Write it back
    ; Do the downshifts (x 1/16 effectively)
    rrf		CTRL_IN_HI, f		; Shift in the borrow flag
    rrf		CTRL_IN_LO, f
    asrf	CTRL_IN_HI, f		; ASRF propagates it down into the result
    rrf		CTRL_IN_LO, f
    asrf	CTRL_IN_HI, f
    rrf		CTRL_IN_LO, f
    asrf	CTRL_IN_HI, f
    rrf		CTRL_IN_LO, f		; 4 shifts total
    ; Add it to FILTER
    movf	CTRL_IN_LO, w
    addwf	DELAY_LO, f
    movf	CTRL_IN_HI, w
    addwfc	DELAY_HI, f		; This is our filtered control value
	
	; Work out the table index to look up the Freq Inc
	; This is weird because it works back-to-front, from the end of the table
	; towards the beginning. It's a sneaky trick to save Prog Mem.
	; Set up the base address of the table (at the end)
	movlw	LOW DelayControlLookup
	movwf	FSR0L
	movlw	HIGH DelayControlLookup
	movwf	FSR0H
	; Now subtract the index from it
	lslf    DELAY_HI, w			; Index = DELAY_HI x 2
	subwf	FSR0L, f
	movlw	D'0'				; Subtract the MSBit of DELAY_HI
	btfsc	DELAY_HI, 7
	movlw	D'1'	
	subwfb	FSR0H, f
	; Read the values/Do the conversion
	clrf	WAIT_HI
	moviw	FSR0++
	movwf	WAIT_MID
	moviw	FSR0++
	movwf	WAIT_LO
	; Is the Delay actually on (fastest settings disable it)
	bsf		DELAY_ON			; Assume it's on
	btfsc	WAIT_MID, 7
	bcf		DELAY_ON			; Turn it off if required
	; All done! Go back to the beginning!
	goto	ReciteMantra


RepeatsControl:
	movlw	b'00010101'			; AN5	Repeats CV
	call	DoADConversion		; Returns value in ADC_VALUE
	; Store input value as 16 bit value
	movwf	CTRL_IN_HI
	clrf	CTRL_IN_LO
	; Subtract stored filter value from new CTRL_IN 
	movf	REPEATS_LO, w
    subwf	CTRL_IN_LO, f		; CTRL_IN = CTRL_IN - FILTER
    movf	REPEATS_HI, w
    subwfb	CTRL_IN_HI, f
    ; Flip the state of the borrow flag
    movf	STATUS, w			; Copy STATUS to W
    xorlw	0x01				; Invert the Carry/Borrow flag
    movwf	STATUS				; Write it back
    ; Do the downshifts (x 1/16 effectively)
    rrf		CTRL_IN_HI, f		; Shift in the borrow flag
    rrf		CTRL_IN_LO, f
    asrf	CTRL_IN_HI, f		; ASRF propagates it down into the result
    rrf		CTRL_IN_LO, f
    asrf	CTRL_IN_HI, f
    rrf		CTRL_IN_LO, f
    asrf	CTRL_IN_HI, f
    rrf		CTRL_IN_LO, f		; 4 shifts total
    ; Add it to FILTER
    movf	CTRL_IN_LO, w
    addwf	REPEATS_LO, f
    movf	CTRL_IN_HI, w
    addwfc	REPEATS_HI, f		; This is our filtered control value

	; Work out the table index to look up the level decrement
	lsrf    REPEATS_HI, w		; Shift down
	andlw	0x7E				; Mask unwanted bits
	movwf	FSR0L				; Store index
	clrf	FSR0H
	; Add the base address of the table
	movlw	LOW RepeatsControlLookup
	addwf	FSR0L, f
	movlw	HIGH RepeatsControlLookup
	addwfc	FSR0H, f
	; Read the values/Do the conversion
	moviw	FSR0++
	movwf	DECAY_HI
	moviw	FSR0++
	movwf	DECAY_LO
	; All done! Go back to the beginning!
	goto	ReciteMantra
	

; Recite the sacred mantra into WREG and contemplate the brimming void deep in
; our code, a reflection of our world.
ReciteMantra:
	movlw	#'O'
	movlw	#'M'

	movlw	#'M'
	movlw	#'A'
	movlw	#'N'
	movlw	#'I'
	
	movlw	#'P'
	movlw	#'A'
	movlw	#'D'
	movlw	#'M'
	movlw	#'E'
	
	movlw	#'H'
	movlw	#'U'
	movlw	#'M'	
	goto	MainLoop


;----------------------------------------------------------------------------
;	Waveform Routines
;----------------------------------------------------------------------------
; These return full 16-bit data for the waveforms. Sometimes this is
; calculated. Other times it is looked-up and interpolated.
	
RampUp:
	movf	PHASE_HI, w				; Top two bytes of Phase Accumulator
	movwf	WAVEFORM_HI
	movf	PHASE_MID, w
	movwf	WAVEFORM_LO
	goto	ReturnWithValue


RampDown:
	comf	PHASE_HI, w				; Invert top bytes of Phase Accumulator
	movwf	WAVEFORM_HI
	comf	PHASE_MID, w
	movwf	WAVEFORM_LO
	goto	ReturnWithValue


LogUp:
	clrf	FSR1H
	movf	PHASE_HI, w				; Index 0-255
	andlw	0xFE					; Clear lowest bit (index is 0-254)
	movwf	FSR1L
	; Set up table position
	movlw	LOW LogTable			; Add base address
	addwf	FSR1L, f
	movlw	HIGH LogTable
	addwfc	FSR1H, f
	; Set up interp index
	rrf		PHASE_HI, w				; Get lowest bit of high byte
	rrf		PHASE_MID, w			; Shift it & middle byte into W
	movwf	INTERP_INDEX			; We use top four bits of this
	; Get the waveform data
	call	WaveformFetchAndInterp	; 16-bit data returned in WAVEFORM_HI/LO
	goto	ReturnWithValue
	

LogDown:
	clrf	FSR1H
	comf	PHASE_HI, w				; Invert index 0-255
	andlw	0xFE					; Clear lowest bit (index is 0-254)
	movwf	FSR1L
	; Set up table position
	movlw	LOW LogTable			; Add base address
	addwf	FSR1L, f
	movlw	HIGH LogTable
	addwfc	FSR1H, f
	; Set up interp index
	rrf		PHASE_HI, w				; Get lowest bit of high byte
	rrf		PHASE_MID, w			; Shift it & middle byte into W
	xorlw	D'255'					; Invert interp index too
	movwf	INTERP_INDEX			; We use top four bits of this
	; Get the waveform data
	call	WaveformFetchAndInterp	; 16-bit data returned in WAVEFORM_HI/LO
	goto	ReturnWithValue

ExpoDown:
	clrf	FSR1H
	movf	PHASE_HI, w				; Index 0-255
	andlw	0xFE					; Clear lowest bit (index is 0-254)
	movwf	FSR1L
	; Set up table position
	movlw	LOW LogTable			; Add base address
	addwf	FSR1L, f
	movlw	HIGH LogTable
	addwfc	FSR1H, f
	; Set up interp index
	rrf		PHASE_HI, w				; Get lowest bit of high byte
	rrf		PHASE_MID, w			; Shift it & middle byte into W
	movwf	INTERP_INDEX			; We use top four bits of this
	; Get the waveform data
	call	WaveformFetchAndInterp	; 16-bit data returned in WAVEFORM_HI/LO
	comf	WAVEFORM_HI, f			; Invert the data
	comf	WAVEFORM_LO, f
	goto	ReturnWithValue

	
Sine:
	clrf	FSR1H
	movf	PHASE_HI, w				; Index 0-255
	andlw	0xFE					; Clear lowest bit (index is 0-254)
	movwf	FSR1L
	; Set up table position
	movlw	LOW SineTable			; Add base address
	addwf	FSR1L, f
	movlw	HIGH SineTable
	addwfc	FSR1H, f
	; Set up interp index
	rrf		PHASE_HI, w				; Get lowest bit of high byte
	rrf		PHASE_MID, w			; Shift it & middle byte into W
	movwf	INTERP_INDEX			; We use top four bits of this
	; Get the waveform data
	call	WaveformFetchAndInterp	; 16-bit data returned in WAVEFORM_HI/LO
	goto	ReturnWithValue

	
Cosine:
	clrf	FSR1H
	movf	PHASE_HI, w				; Index 0-255
	andlw	0xFE					; Clear lowest bit (index is 0-254)
	movwf	FSR1L
	; Set up table position
	movlw	LOW CosineTable			; Add base address
	addwf	FSR1L, f
	movlw	HIGH CosineTable
	addwfc	FSR1H, f
	; Set up interp index
	rrf		PHASE_HI, w				; Get lowest bit of high byte
	rrf		PHASE_MID, w			; Shift it & middle byte into W
	movwf	INTERP_INDEX			; We use top four bits of this
	; Get the waveform data
	call	WaveformFetchAndInterp	; 16-bit data returned in WAVEFORM_HI/LO
	goto	ReturnWithValue

InvSine:
	clrf	FSR1H
	movf	PHASE_HI, w				; Index 0-255
	andlw	0xFE					; Clear lowest bit (index is 0-254)
	movwf	FSR1L
	; Set up table position
	movlw	LOW SineTable			; Add base address
	addwf	FSR1L, f
	movlw	HIGH SineTable
	addwfc	FSR1H, f
	; Set up interp index
	rrf		PHASE_HI, w				; Get lowest bit of high byte
	rrf		PHASE_MID, w			; Shift it & middle byte into W
	movwf	INTERP_INDEX			; We use top four bits of this
	; Get the waveform data
	call	WaveformFetchAndInterp	; 16-bit data returned in WAVEFORM_HI/LO
	comf	WAVEFORM_HI, f			; Invert the data
	comf	WAVEFORM_LO, f
	goto	ReturnWithValue
	

;------------------------------------------------------------------------------
;	Waveform Fetch and Interpolation
;------------------------------------------------------------------------------
; This general routine reads from the data tables and interpolates
; the data to get smoother results.
; FSR1 should be pointed at the table position required before entry.
WaveformFetchAndInterp:
	; Read the bytes
	moviw	FSR1++
	movwf	WAVE_X_HI				; I get the post-inc for free with the
	moviw	FSR1++					; enhanced instruction set. Nice!
	movwf	WAVE_X_LO
	moviw	FSR1++
	movwf	WAVE_Y_HI
	moviw	FSR1++
	movwf	WAVE_Y_LO
; 8 instructions, very short and straightforward.

WaveformInterpolation:
	; Set up ready for the interpolation
	movf	WAVE_X_HI, w			; We start off with one copy of this.
	movwf	WAVEFORM_HI
	movf	WAVE_X_LO, w
	movwf	WAVEFORM_LO
	
	; Test a single bit and add X or Y as required
	movf	WAVE_X_LO, w
	btfsc	INTERP_INDEX, 4
	movf	WAVE_Y_LO, w
	addwf	WAVEFORM_LO, f
	movf	WAVE_X_HI, w
	btfsc	INTERP_INDEX, 4
	movf	WAVE_Y_HI, w
	addwfc	WAVEFORM_HI, f
	rrf		WAVEFORM_HI, f			; Shift the result down (shift carry in)
	rrf		WAVEFORM_LO, f

	movf	WAVE_X_LO, w
	btfsc	INTERP_INDEX, 5
	movf	WAVE_Y_LO, w
	addwf	WAVEFORM_LO, f
	movf	WAVE_X_HI, w
	btfsc	INTERP_INDEX, 5
	movf	WAVE_Y_HI, w
	addwfc	WAVEFORM_HI, f
	rrf		WAVEFORM_HI, f
	rrf		WAVEFORM_LO, f

	movf	WAVE_X_LO, w
	btfsc	INTERP_INDEX, 6
	movf	WAVE_Y_LO, w
	addwf	WAVEFORM_LO, f
	movf	WAVE_X_HI, w
	btfsc	INTERP_INDEX, 6
	movf	WAVE_Y_HI, w
	addwfc	WAVEFORM_HI, f
	rrf		WAVEFORM_HI, f
	rrf		WAVEFORM_LO, f
	
	movf	WAVE_X_LO, w
	btfsc	INTERP_INDEX, 7
	movf	WAVE_Y_LO, w
	addwf	WAVEFORM_LO, f
	movf	WAVE_X_HI, w
	btfsc	INTERP_INDEX, 7
	movf	WAVE_Y_HI, w
	addwfc	WAVEFORM_HI, f
	rrf		WAVEFORM_HI, f
	rrf		WAVEFORM_LO, f
; 44 Instructions
	return


;----------------------------------------------------------------------------
;	Frequency Control Lookup Table (255 x 16-bit)
; Turns a 0-255 input into a 16-bit frequency increment for the One-Shot
;----------------------------------------------------------------------------
FreqControlLookup:
	dt	D'0', D'215', D'0', D'218', D'0', D'221', D'0', D'225'
	dt	D'0', D'228', D'0', D'231', D'0', D'235', D'0', D'238'
	dt	D'0', D'242', D'0', D'246', D'0', D'249', D'0', D'253'
	dt	D'1', D'1', D'1', D'5', D'1', D'9', D'1', D'13'
	dt	D'1', D'17', D'1', D'21', D'1', D'25', D'1', D'29'
	dt	D'1', D'34', D'1', D'38', D'1', D'42', D'1', D'47'
	dt	D'1', D'51', D'1', D'56', D'1', D'61', D'1', D'66'
	dt	D'1', D'70', D'1', D'75', D'1', D'80', D'1', D'85'

	dt	D'1', D'90', D'1', D'96', D'1', D'101', D'1', D'106'
	dt	D'1', D'112', D'1', D'117', D'1', D'123', D'1', D'129'
	dt	D'1', D'135', D'1', D'140', D'1', D'146', D'1', D'152'
	dt	D'1', D'159', D'1', D'165', D'1', D'171', D'1', D'178'
	dt	D'1', D'184', D'1', D'191', D'1', D'197', D'1', D'204'
	dt	D'1', D'211', D'1', D'218', D'1', D'225', D'1', D'233'
	dt	D'1', D'240', D'1', D'248', D'1', D'255', D'2', D'7'
	dt	D'2', D'15', D'2', D'23', D'2', D'31', D'2', D'39'

	dt	D'2', D'47', D'2', D'55', D'2', D'64', D'2', D'73'
	dt	D'2', D'82', D'2', D'90', D'2', D'100', D'2', D'109'
	dt	D'2', D'118', D'2', D'128', D'2', D'137', D'2', D'147'
	dt	D'2', D'157', D'2', D'167', D'2', D'177', D'2', D'188'
	dt	D'2', D'198', D'2', D'209', D'2', D'220', D'2', D'231'
	dt	D'2', D'242', D'2', D'253', D'3', D'9', D'3', D'21'
	dt	D'3', D'32', D'3', D'44', D'3', D'57', D'3', D'69'
	dt	D'3', D'82', D'3', D'95', D'3', D'107', D'3', D'121'

	dt	D'3', D'134', D'3', D'148', D'3', D'161', D'3', D'175'
	dt	D'3', D'190', D'3', D'204', D'3', D'219', D'3', D'234'
	dt	D'3', D'249', D'4', D'8', D'4', D'24', D'4', D'39'
	dt	D'4', D'55', D'4', D'72', D'4', D'88', D'4', D'105'
	dt	D'4', D'122', D'4', D'139', D'4', D'157', D'4', D'174'
	dt	D'4', D'192', D'4', D'211', D'4', D'229', D'4', D'248'
	dt	D'5', D'11', D'5', D'31', D'5', D'51', D'5', D'71'
	dt	D'5', D'91', D'5', D'112', D'5', D'133', D'5', D'154'

	dt	D'5', D'175', D'5', D'197', D'5', D'220', D'5', D'242'
	dt	D'6', D'9', D'6', D'32', D'6', D'56', D'6', D'80'
	dt	D'6', D'104', D'6', D'129', D'6', D'154', D'6', D'180'
	dt	D'6', D'205', D'6', D'232', D'7', D'2', D'7', D'29'
	dt	D'7', D'57', D'7', D'85', D'7', D'113', D'7', D'142'
	dt	D'7', D'171', D'7', D'200', D'7', D'230', D'8', D'5'
	dt	D'8', D'36', D'8', D'67', D'8', D'99', D'8', D'131'
	dt	D'8', D'164', D'8', D'197', D'8', D'231', D'9', D'10'

	dt	D'9', D'44', D'9', D'80', D'9', D'116', D'9', D'152'
	dt	D'9', D'189', D'9', D'227', D'10', D'9', D'10', D'48'
	dt	D'10', D'87', D'10', D'127', D'10', D'167', D'10', D'208'
	dt	D'10', D'250', D'11', D'36', D'11', D'79', D'11', D'123'
	dt	D'11', D'167', D'11', D'212', D'12', D'2', D'12', D'48'
	dt	D'12', D'95', D'12', D'143', D'12', D'191', D'12', D'240'
	dt	D'13', D'34', D'13', D'85', D'13', D'136', D'13', D'188'
	dt	D'13', D'241', D'14', D'39', D'14', D'94', D'14', D'149'

	dt	D'14', D'205', D'15', D'6', D'15', D'64', D'15', D'123'
	dt	D'15', D'183', D'15', D'243', D'16', D'49', D'16', D'111'
	dt	D'16', D'175', D'16', D'239', D'17', D'48', D'17', D'115'
	dt	D'17', D'182', D'17', D'250', D'18', D'63', D'18', D'134'
	dt	D'18', D'205', D'19', D'22', D'19', D'95', D'19', D'170'
	dt	D'19', D'246', D'20', D'67', D'20', D'145', D'20', D'224'
	dt	D'21', D'49', D'21', D'130', D'21', D'213', D'22', D'42'
	dt	D'22', D'127', D'22', D'214', D'23', D'46', D'23', D'135'

	dt	D'23', D'226', D'24', D'62', D'24', D'155', D'24', D'250'
	dt	D'25', D'91', D'25', D'188', D'26', D'32', D'26', D'132'
	dt	D'26', D'235', D'27', D'82', D'27', D'188', D'28', D'39'
	dt	D'28', D'147', D'29', D'1', D'29', D'113', D'29', D'227'
	dt	D'30', D'86', D'30', D'203', D'31', D'66', D'31', D'186'
	dt	D'32', D'53', D'32', D'177', D'33', D'47', D'33', D'175'
	dt	D'34', D'49', D'34', D'181', D'35', D'58', D'35', D'194'
	dt	D'36', D'76', D'36', D'216', D'37', D'102', D'37', D'246'
	

	
;----------------------------------------------------------------------------
;	Delay Control Lookup Table
; Turns a 0-255 input into a 16-bit freq inc for the delay time
;----------------------------------------------------------------------------
; Now, this is weird! Since I need to save Prog Flash, this works
; back-to-front so that it can reuse the Freq control table, which has fast
; settings at the end (e.g. short delays).
	; These first few settings turn the delay off
	dt	D'128', D'0', D'128', D'0', D'128', D'0', D'128', D'0'	
	dt	D'128', D'0', D'128', D'0', D'128', D'0', D'128', D'0'
DelayControlLookup:


;----------------------------------------------------------------------------
;	Repeats Control Lookup Table (64 x 16-bit)
; Turns a 0-63 input into a 16-bit decrement for the output level
;----------------------------------------------------------------------------
RepeatsControlLookup:
	dt	D'255', D'255', D'255', D'255', D'255', D'255', D'255', D'255'
	dt	D'128', D'0', D'128', D'0', D'128', D'0', D'128', D'0'
	dt	D'85', D'85', D'85', D'85', D'85', D'85', D'85', D'85'
	dt	D'64', D'0', D'64', D'0', D'64', D'0', D'64', D'0'
	dt	D'51', D'51', D'51', D'51', D'51', D'51', D'51', D'51'
	dt	D'42', D'171', D'42', D'171', D'42', D'171', D'42', D'171'
	dt	D'36', D'147', D'36', D'147', D'36', D'147', D'36', D'147'
	dt	D'32', D'0', D'32', D'0', D'32', D'0', D'32', D'0'

	dt	D'28', D'114', D'28', D'114', D'28', D'114', D'28', D'114'
	dt	D'25', D'154', D'25', D'154', D'25', D'154', D'25', D'154'
	dt	D'23', D'70', D'23', D'70', D'21', D'86', D'19', D'178'
	dt	D'19', D'178', D'18', D'74', D'17', D'17', D'17', D'17'
	dt	D'16', D'0', D'15', D'15', D'14', D'57', D'13', D'122'
	dt	D'12', D'205', D'12', D'49', D'11', D'163', D'11', D'34'
	dt	D'10', D'62', D'9', D'217', D'9', D'124', D'8', D'212'
	dt	D'8', D'137', D'8', D'0', D'7', D'136', D'7', D'29'
	
	
;----------------------------------------------------------------------------
;	Sine Waveform Lookup Table (129 x 16-bit)
;----------------------------------------------------------------------------
SineTable:
	dt	D'0', D'0', D'6', D'72', D'12', D'144', D'18', D'213'
	dt	D'25', D'24', D'31', D'86', D'37', D'144', D'43', D'196'
	dt	D'49', D'241', D'56', D'23', D'62', D'52', D'68', D'71'
	dt	D'74', D'80', D'80', D'77', D'86', D'62', D'92', D'34'
	dt	D'97', D'247', D'103', D'189', D'109', D'116', D'115', D'25'
	dt	D'120', D'173', D'126', D'46', D'131', D'156', D'136', D'245'
	dt	D'142', D'57', D'147', D'104', D'152', D'127', D'157', D'127'
	dt	D'162', D'103', D'167', D'54', D'171', D'235', D'176', D'133'

	dt	D'181', D'4', D'185', D'104', D'189', D'174', D'193', D'216'
	dt	D'197', D'227', D'201', D'208', D'205', D'158', D'209', D'76'
	dt	D'212', D'218', D'216', D'71', D'219', D'147', D'222', D'189'
	dt	D'225', D'197', D'228', D'169', D'231', D'107', D'234', D'9'
	dt	D'236', D'130', D'238', D'216', D'241', D'8', D'243', D'19'
	dt	D'244', D'249', D'246', D'185', D'248', D'83', D'249', D'199'
	dt	D'251', D'20', D'252', D'58', D'253', D'58', D'254', D'18'
	dt	D'254', D'195', D'255', D'77', D'255', D'176', D'255', D'235'

	dt	D'255', D'255', D'255', D'235', D'255', D'176', D'255', D'77'
	dt	D'254', D'195', D'254', D'18', D'253', D'58', D'252', D'58'
	dt	D'251', D'20', D'249', D'199', D'248', D'83', D'246', D'185'
	dt	D'244', D'249', D'243', D'19', D'241', D'8', D'238', D'216'
	dt	D'236', D'130', D'234', D'9', D'231', D'107', D'228', D'169'
	dt	D'225', D'197', D'222', D'189', D'219', D'147', D'216', D'71'
	dt	D'212', D'218', D'209', D'76', D'205', D'158', D'201', D'208'
	dt	D'197', D'227', D'193', D'216', D'189', D'174', D'185', D'104'

	dt	D'181', D'4', D'176', D'133', D'171', D'235', D'167', D'54'
	dt	D'162', D'103', D'157', D'127', D'152', D'127', D'147', D'104'
	dt	D'142', D'57', D'136', D'245', D'131', D'156', D'126', D'46'
	dt	D'120', D'173', D'115', D'25', D'109', D'116', D'103', D'189'
	dt	D'97', D'247', D'92', D'34', D'86', D'62', D'80', D'77'
	dt	D'74', D'80', D'68', D'71', D'62', D'52', D'56', D'23'
	dt	D'49', D'241', D'43', D'196', D'37', D'144', D'31', D'86'
	dt	D'25', D'24', D'18', D'213', D'12', D'144', D'6', D'72'

	dt	D'0', D'0'				; One extra for interpolation
		

;----------------------------------------------------------------------------
;	Cosine Waveform Lookup Table (129 x 16-bit)
;----------------------------------------------------------------------------
CosineTable:
	dt	D'0', D'0', D'0', D'39', D'0', D'158', D'1', D'99'
	dt	D'2', D'118', D'3', D'214', D'5', D'131', D'7', D'123'
	dt	D'9', D'190', D'12', D'74', D'15', D'29', D'18', D'54'
	dt	D'21', D'146', D'25', D'48', D'29', D'14', D'33', D'40'
	dt	D'37', D'125', D'42', D'10', D'46', D'204', D'51', D'192'
	dt	D'56', D'227', D'62', D'50', D'67', D'169', D'73', D'70'
	dt	D'79', D'4', D'84', D'224', D'90', D'216', D'96', D'230'
	dt	D'103', D'7', D'109', D'56', D'115', D'116', D'121', D'184'

	dt	D'128', D'0', D'134', D'71', D'140', D'139', D'146', D'199'
	dt	D'152', D'248', D'159', D'25', D'165', D'39', D'171', D'31'
	dt	D'176', D'251', D'182', D'185', D'188', D'86', D'193', D'205'
	dt	D'199', D'28', D'204', D'63', D'209', D'51', D'213', D'245'
	dt	D'218', D'130', D'222', D'215', D'226', D'241', D'230', D'207'
	dt	D'234', D'109', D'237', D'201', D'240', D'226', D'243', D'181'
	dt	D'246', D'65', D'248', D'132', D'250', D'124', D'252', D'41'
	dt	D'253', D'137', D'254', D'156', D'255', D'97', D'255', D'216'

	dt	D'255', D'255', D'255', D'216', D'255', D'97', D'254', D'156'
	dt	D'253', D'137', D'252', D'41', D'250', D'124', D'248', D'132'
	dt	D'246', D'65', D'243', D'181', D'240', D'226', D'237', D'201'
	dt	D'234', D'109', D'230', D'207', D'226', D'241', D'222', D'215'
	dt	D'218', D'130', D'213', D'245', D'209', D'51', D'204', D'63'
	dt	D'199', D'28', D'193', D'205', D'188', D'86', D'182', D'185'
	dt	D'176', D'251', D'171', D'31', D'165', D'39', D'159', D'25'
	dt	D'152', D'248', D'146', D'199', D'140', D'139', D'134', D'71'

	dt	D'128', D'0', D'121', D'184', D'115', D'116', D'109', D'56'
	dt	D'103', D'7', D'96', D'230', D'90', D'216', D'84', D'224'
	dt	D'79', D'4', D'73', D'70', D'67', D'169', D'62', D'50'
	dt	D'56', D'227', D'51', D'192', D'46', D'204', D'42', D'10'
	dt	D'37', D'125', D'33', D'40', D'29', D'14', D'25', D'48'
	dt	D'21', D'146', D'18', D'54', D'15', D'29', D'12', D'74'
	dt	D'9', D'190', D'7', D'123', D'5', D'131', D'3', D'214'
	dt	D'2', D'118', D'1', D'99', D'0', D'158', D'0', D'39'

	dt	D'0', D'0'		; One extra for interpolation

	
;----------------------------------------------------------------------------
;	Log Waveform Lookup Table (129 x 16-bit)
;----------------------------------------------------------------------------
LogTable:
	dt	D'0', D'0', D'0', D'0', D'0', D'0', D'0', D'0'
	dt	D'0', D'1', D'0', D'3', D'0', D'6', D'0', D'10'
	dt	D'0', D'15', D'0', D'22', D'0', D'31', D'0', D'41'
	dt	D'0', D'53', D'0', D'68', D'0', D'85', D'0', D'105'
	dt	D'0', D'127', D'0', D'153', D'0', D'182', D'0', D'214'
	dt	D'0', D'249', D'1', D'33', D'1', D'76', D'1', D'124'
	dt	D'1', D'175', D'1', D'232', D'2', D'37', D'2', D'103'
	dt	D'2', D'173', D'2', D'250', D'3', D'75', D'3', D'162'

	dt	D'3', D'255', D'4', D'98', D'4', D'204', D'5', D'59'
	dt	D'5', D'177', D'6', D'46', D'6', D'178', D'7', D'61'
	dt	D'7', D'207', D'8', D'105', D'9', D'11', D'9', D'180'
	dt	D'10', D'101', D'11', D'31', D'11', D'225', D'12', D'172'
	dt	D'13', D'127', D'14', D'92', D'15', D'66', D'16', D'49'
	dt	D'17', D'41', D'18', D'44', D'19', D'56', D'20', D'79'
	dt	D'21', D'111', D'22', D'155', D'23', D'209', D'25', D'17'
	dt	D'26', D'93', D'27', D'180', D'29', D'23', D'30', D'133'

	dt	D'31', D'255', D'33', D'133', D'35', D'23', D'36', D'182'
	dt	D'38', D'97', D'40', D'25', D'41', D'222', D'43', D'176'
	dt	D'45', D'143', D'47', D'124', D'49', D'118', D'51', D'127'
	dt	D'53', D'149', D'55', D'186', D'57', D'237', D'60', D'46'
	dt	D'62', D'127', D'64', D'223', D'67', D'77', D'69', D'203'
	dt	D'72', D'89', D'74', D'246', D'77', D'164', D'80', D'97'
	dt	D'83', D'47', D'86', D'13', D'88', D'252', D'91', D'252'
	dt	D'95', D'13', D'98', D'47', D'101', D'98', D'104', D'168'

	dt	D'107', D'255', D'111', D'104', D'114', D'227', D'118', D'112'
	dt	D'122', D'17', D'125', D'195', D'129', D'137', D'133', D'98'
	dt	D'137', D'78', D'141', D'78', D'145', D'98', D'149', D'137'
	dt	D'153', D'196', D'158', D'20', D'162', D'120', D'166', D'241'
	dt	D'171', D'126', D'176', D'33', D'180', D'216', D'185', D'165'
	dt	D'190', D'136', D'195', D'128', D'200', D'143', D'205', D'179'
	dt	D'210', D'238', D'216', D'63', D'221', D'167', D'227', D'38'
	dt	D'232', D'188', D'238', D'105', D'244', D'45', D'250', D'9'

	dt	D'255', D'253'	; One extra for interpolation
	
	
; We never reach here
	end
