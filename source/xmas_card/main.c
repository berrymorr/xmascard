#define STM8S103 1
#include <STM8S103F3P.h>
//#include <iostm8s103.h>

#include "stm8s.h" //4 constants and types definitionz
//local constants
#define d1s (65535-3000) //3 seconds, not one)
#define d100ms (65535-1)

typedef struct {
	uint8_t  note;
	uint16_t dly;
}part; //song's element

#include "song.h" //uze just 4 vars init

const fcode uint16_t note2dly[128]={
	65535,65535,65535,65535,65535,65535,65535,65535,65535,65535,65535,64793,
  61156,57724,54484,51426,48540,45815,43244,40817,38526,36364,34323,32396,
  30578,28862,27242,25713,24270,22908,21622,20408,19263,18182,17161,16198,
  15289,14431,13621,12856,12135,11454,10811,10204,9631, 9091, 8581, 8099,
  7645, 7215, 6810, 6428, 6067, 5727, 5405, 5102, 4816, 4545, 4290, 4050,
  3822, 3608, 3405, 3214, 3034, 2863, 2703, 2551, 2408, 2273, 2145, 2025,
  1911, 1804, 1703, 1607, 1517, 1432, 1351, 1276, 1204, 1136, 1073, 1012,
  956,  902,  851,  804,  758,  716,  676,  638,  602,  568,  536,  506,
  478,  451,  426,  402,  379,  358,  338,  319,  301,  284,  268,  253,
  239,  225,  213,  201,  190,  179,  169,  159,  150,  142,  134,  127,
  119,  113,  106,  100,  95,   89,   84,   80
};
/* XMAS CARD by berrymorr, 2011
 *
 *
 * SET AFR0 bit in OPT2 - remap TIM1_CH1 to PC6!
 *
 *
 */
 
/*#define uint8_t unsigned char
#define sint8_t signed char
#define uint16_t unsigned int
#define sint16_t signed int*/


volatile uint16_t tmp_delay,tmp_note,counter;


INTERRUPT_HANDLER(TIM2_UPD_OVF_BRK_IRQHandler, 13)
{
	TIM2_SR1=(uint8_t)~TIM2_SR1_UIF;
	TIM1_BKR&=(uint8_t)(~TIM1_BKR_MOE);//switch tim1 out off
  if (counter % 2) //counter mod 2
	{
		tmp_note=0;
		tmp_delay=d100ms;
	}
	else {
		if (song[counter / 2].note<128) {
		tmp_note=note2dly[song[counter / 2].note];
		tmp_delay=song[counter / 2].dly;
	  }
	  else {
  	  if (song[counter / 2].note==0xDD) {
			tmp_note=0;										//genereate ultrasound ;)
			tmp_delay=song[counter / 2].dly;	//uze delay
		  }
	    else {
  			counter=-1;										//wrong note. goto start of song
			  tmp_note=0;										//ultrasound again
			  tmp_delay=d1s;							//wait for 1s before playing again
		  }
	  };
  };
  TIM1_ARRH=(uint8_t)(tmp_note >> 8);
  TIM1_ARRL=(uint8_t)(tmp_note);
	TIM2_CNTRH=(uint8_t)(tmp_delay >> 8);
  TIM2_CNTRL=(uint8_t)(tmp_delay);
	counter++;
  if (tmp_note>0) {TIM1_BKR|=TIM1_BKR_MOE;}; //enable pwmoutputs
	TIM2_CR1|=TIM2_CR1_CEN; // Enable timer
}


void clk_init ()
{
  CLK_CKDIVR=0; //ƒелители частоты =1
}

void port_init ()
{
  PC_DDR|=(1<<6); //PC6 на выход
  PC_CR1|=(1<<6); //PC6 Push pull
}

void tim1_init()
{//выход на пиликалку - TIM1_CH1
	CLK_PCKENR1|=CLK_PCKENR1_TIM1;
  TIM1_SR1&=(uint8_t)(~TIM1_SR1_UIF);  //—бросим признак прерывани€
  TIM1_PSCRH=0; // Prescaler 1MHz @ 16MHz /2 (cauze of half-period)
  TIM1_PSCRL=8;
  TIM1_ARRH=0x00;
  TIM1_ARRL=0x01; // Auto-reload value
  TIM1_CCMR1|=0x30; //OC1REF toggle mode
	TIM1_CCER1|=TIM1_CCER1_CC1E;
  TIM1_CR1|=TIM1_CR1_CEN | TIM1_CR1_DIR; // Enable timer, downcount
}

void tim2_init()
{//загрузку новой ноты - в прерывании тим2
  CLK_PCKENR1|=CLK_PCKENR1_TIM2;
  TIM2_SR1&=~TIM2_SR1_UIF;  //—бросим признак прерывани€
	TIM2_PSCR=0x0E; // Prescaler=16384
	TIM2_CNTRH=(uint8_t)(tmp_delay >> 8);
  TIM2_CNTRL=(uint8_t)(tmp_delay);
  TIM2_IER|=TIM2_IER_UIE; // Enable interrupt
  TIM2_CR1|=TIM2_CR1_CEN | TIM2_CR1_OPM | TIM2_CR1_URS; // Enable timer
}

main()
{
	counter=0;
	tmp_delay=d1s;//delay before melody starts - 1s
	tmp_note=0;
	
	clk_init(); //16 MHz core clock
  port_init();//PC6 push-pull
	tim1_init();
	tim2_init();
  enableInterrupts();
  while(1);

  return(0);
}

/*const uint16_t note2dly[60]={
// C    C#   D    D#   E    F    F#   G    G#   A    A#   H
	7634,7194,6803,6410,6061,5714,5405,5102,4808,4545,4292,4049, //small octave (from 0)
	3817,3610,3401,3215,3030,2865,2703,2551,2410,2273,2146,2024, //1st octave (from 12)
	1912,1805,1704,1608,1517,1433,1351,1276,1203,1136,1073,1012, //2nd octave (from 24)
	955, 902, 851, 803, 758, 716, 676, 638, 602, 568, 536, 506,  //3rd octave (from 36)
  478, 451, 426, 402, 379, 358, 338, 319, 301, 284, 268, 253   //4th octave (from 48)
};*/

  /*
  TIM1_BKR|=TIM1_BKR_MOE; //enable pwmoutputs
	TIM1_BKR&=(uint8_t)(~TIM1_BKR_MOE); //disable pwmoutputs
	TIM1_BKR^=TIM1_BKR_MOE; //toggle pwmoutputs
  */

/*tmpccr1 = (uint16_t)(tmpccr1l);
  tmpccr1 |= (uint16_t)((uint16_t)tmpccr1h << 8);
	TIM1->ARRH = (uint8_t)(TIM1_Period >> 8);
  TIM1->ARRL = (uint8_t)(TIM1_Period);*/