/*
 * Life.xc
 * https://www.xmos.com/download/public/XC-1A-Hardware-Manual%281%29.pdf
 *
 * 20111230: performance for 2^21 iter of 27:110 is 72 sec (no led)
 *  @ 28k iter/sec or 3.1 million ops/sec
 *  Created on: Oct 9, 2010
 *  Author: mfobrien
 */

#include <platform.h>
#include <print.h> //http://www.xmos.com/discuss/viewtopic.php?f=6&t=255
#define PERIOD 20000000

// Processor 0 = 4 green + 3r/g LED + 16 I/O, 4 push-buttons
//out port cledB0 = PORT_BUTTONLED;//PORT_CLOCKLED_0;
//out port cled0 = PORT_BUTTONLED;//PORT_CLOCKLED_0;
// anode 4 bit ports
out port cled0 = PORT_CLOCKLED_0;
// Processor 1 = 3r/g LED + 16 I/O
out port cled1 = PORT_CLOCKLED_1;
// Processor 1 = 3r/g LED + 16 I/O
out port cled2 = PORT_CLOCKLED_2;
// Processor 1 = 3r/g LED + 32 I/O
out port cled3 = PORT_CLOCKLED_3;
// cathode 1 bit ports
out port cledG = PORT_CLOCKLED_SELG;
out port cledR = PORT_CLOCKLED_SELR;

/**
 * http://en.wikipedia.org/wiki/XSwitch#XS1-G4_Switch
 */
unsigned long number = 27;
unsigned long maximum = 1 << 18;//138367; // 32 bit registers top out at a 4 billion max for 138367

// Compute the hailstone maximum
unsigned long hailstoneMax(unsigned long start) {
	unsigned long maxNumber = 0;
    unsigned long number = start;
    while(number > 1) {
    	if((number % 2) > 0) {
    		number = (number << 1) + number + 1; // odd
    	} else {
    		number = number >> 1; // even
    	}
    	if(number > maxNumber) {
    		maxNumber = number;
    	}
    }
	return maxNumber;
}

void hailstoneSearch(int coreId, out port led, unsigned long start, unsigned long end) {
  unsigned long number = 27;
  unsigned long maxNumber = 0;
  unsigned long newMax = 0;
  int flip = 0;
  //write_pswitch_reg(get_core_id(), XS1_PSWITCH_PLL_CLK_DIVIDER_NUM, 0x80);
  while(number < end) {
	  newMax = hailstoneMax(number);
	  if(newMax > maxNumber) {
		maxNumber = newMax;
	  }
		// TODO: send message to other cores
		// UART printing really slows down the cores
		/*if(coreId < 1) { // only core 0 prints
			printuint(number);
			printchar(',');
			printchar('\t');
			printuintln(maxNumber);
		}*/
		/*if(flip > 0) {
			flip = 0;
			led <: 0b1111;
		} else {
			flip = 1;
			led <: 0b0000;
		}*/
		if(flip > 1) {
			flip = 0;
			led <: 0b00010011;
		} else {
			if(flip > 0) {
				flip = flip + 1;
				led <: 0b00100110;
			} else {
				if(flip == 0) {
					flip = flip + 1;
					led <: 0b01001100;
				}
			}
		//}

	  }
	number = number + 2;
  }
  printint(coreId); // print core id when finished
}

void hailstoneSearchBench(int coreId, out port led, unsigned long start, unsigned long end) {
  unsigned long number = start;//27;
  unsigned long newMax = 0;
  unsigned long iter1 = 1 << 8;
  unsigned long iter2 = 1 << 5;
  unsigned int flip = 0;
  //write_pswitch_reg(get_core_id(), XS1_PSWITCH_PLL_CLK_DIVIDER_NUM, 0x80);
  for (iter1 = 0; iter1 < 4096; iter1++) {
  //while(iter1 > 0) {
	  //iter1 = iter1 - 1;
	  for (iter2 = 0; iter2 < 256; iter2++) {
		  //iter2 = iter2 - 1;
		  newMax = hailstoneMax(number);
	  }
	  /*if(flip < 256) {
		  flip = flip + 1;
	  } else {
		  flip = 0;
	  }
	  led <: flip;
	  */
		if(flip > 1) {
			flip = 0;
			led <: 0b00010011;
		} else {
			if(flip > 0) {
				flip = flip + 1;
				led <: 0b00100110;
			} else {
				if(flip == 0) {
					flip = flip + 1;
					led <: 0b01001100;
				}
			}
		}

  }
  printint(coreId); // print core id when finished
  // reduce temperature by lowering the PLL multiplier after all cores are done
  write_pswitch_reg(get_core_id(), XS1_PSWITCH_PLL_CLK_DIVIDER_NUM, 0x80);
  while(1) {
	  for(unsigned long i = 0; i<256;i++) {
		  led <: i;
	  }
  }
}

// Search a range of integers for their hailstone maximums
void hailstoneSearch0(int coreId, out port led, out port redCathode, out port greenCathode,
		unsigned long start, unsigned long end) {
	  redCathode <: 0;
	  greenCathode <: 1;
	  //printuint(start);
	  //printchar('-');
	  //printuintln(end);
	  hailstoneSearchBench(coreId, led, start, end);
	  // reduce temperature by lowering the PLL multiplier after all cores are done
	  //write_pswitch_reg(get_core_id(), XS1_PSWITCH_PLL_CLK_DIVIDER_NUM, 0x80);
	  //while(1);
}

void initialize() {
	cledR <: 1;
	cledG <: 1;
}
int main() {
	// concurrent threads p.33 http://www.xmos.com//system/files/xcuser_en.pdf
	//initialize();
	par {
		on stdcore [0]: hailstoneSearch0(0, cled0,cledR,cledG,82, maximum);
		//on stdcore [0]: hailstoneSearchBench(0, cled0,number, maximum);
		on stdcore [1]: hailstoneSearchBench(1, cled1,27, maximum);
		on stdcore [2]: hailstoneSearchBench(2, cled2,27, maximum);
		// one of the cores is used by the UART
		on stdcore [3]: hailstoneSearchBench(3, cled3,27, maximum);
	}
	return 0;
}
