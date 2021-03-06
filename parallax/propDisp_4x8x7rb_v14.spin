''=============================================================================
''
'' @file     propDisp_4x8_7rb
'' @target   Propeller
'' @purpose  Display driver for 4 rows of 8 7-seg LED digits
''           Drivers software is via USB serial port from PC
''
''
'' @author   Michael O'Brien 
''
'' @version  V1.0 - Oct 21, 2010
'' @changes
''  - original version
'' 20101024 - working version for 4 threads on 32 total led characters
'' 20101025 - add comm code for data download from host JVM on PC
''=============================================================================
                                                         
CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

VAR
  ' shared display RAM for the 4 display cogs
  long buffer[32]                                         
  long Stack0[64]                                         ' Stack Space
  long Stack1[64]                                         ' Stack Space
  long Stack2[64]                                         ' Stack Space
  long Stack3[64]                                         ' Stack Space
  long Stack4[16]                                         ' Stack Space
  long Stack5[16]                                         ' Stack Space
  long Stack6[16]                                         ' Stack Space
  byte Cog[6]                                             ' Cog ID
  byte flashFlag                                          ' visual clock bit
  long  randomNum
  
OBJ
   SER    : "FullDuplexSerial"    
  
PUB main | mIndex, mValue, lRec, i,lastRawTemp, lastRawHumidity, prevOnesDigit, rawTemp, rawHumidity, tempC, tempC2, tempPoint2, rh, dewC, tPin, tempPoint, tempTen, tempOne, humTen, humOne
  ' initialize array prior to any PC connection
  buffer[0] := 11
  buffer[1] := 11
  buffer[2] := 11
  buffer[3] := 11
  buffer[4] := 11
  buffer[5] := 11
  buffer[6] := 11
  buffer[7] := 11

  buffer[8] := 11
  buffer[9] := 11
  buffer[10] := 11
  buffer[11] := 11
  buffer[12] := 11
  buffer[13] := 11
  buffer[14] := 11
  buffer[15] := 11

  buffer[16] := 11
  buffer[17] := 11
  buffer[18] := 11
  buffer[19] := 11
  buffer[20] := 11
  buffer[21] := 11
  buffer[22] := 11
  buffer[23] := 11

  buffer[24] := 11
  buffer[25] := 11
  buffer[26] := 11
  buffer[27] := 11
  buffer[28] := 11
  buffer[29] := 11
  buffer[30] := 11
  buffer[31] := 11

  {{
    Each line of 8 LED 7-segments are driven by a 595 SIPO pair by a single cog
    No resistors are required as the inherent resistance of the 595 output pins
    is enough to limit the current below 20ma.
    The 3 pin parameters below are for the Shift Clock, Register Clock and Data pins.

  }}
  Cog[0] := cognew(Push8seg(0,buffer,2,3,4, 24_000,0), @Stack0) + 1
  Cog[1] := cognew(Push8seg(8,buffer,5,6,7,50_000,0), @Stack1) + 1
  Cog[2] := cognew(Push8seg(16,buffer,8,9,10,24_000,0), @Stack2) + 1
  Cog[3] := cognew(Push8seg(24,buffer,11,12,13,30_000,0), @Stack3) + 1
  'Cog[4] := cognew(Flasher8(80), @Stack4) + 1
  'Cog[5] := cognew(FlasherPoint(50), @Stack5) + 1

  ' echo Comm port data back to the sender
  ' we are currently only seeing every 2nd char
  ' comm control needs 2 cogs
  ser.start(31,30,0,38400)
  lRec := 48
  i := 0
   repeat
     ' wait for char
     lRec := ser.rx
     ' check for command 32 with index:value next
     if lRec == 32
       ser.tx(32)
       ' get index
       lRec := ser.rx
       mIndex := lRec - 96
       ' get value
       lRec := ser.rx
       mValue := lRec - 48              
       lRec := ser.rx       
     ' check for EOL
     if lRec == 13
       if i < 32
         i := i + 1
       else
         i := 0
       'ser.tx(32)
       'ser.tx(mIndex + 96)
       ser.tx(mValue + 48)
       ser.tx(mIndex + 96)
       'ser.tx(13)
     else
         ser.tx(lRec) ' this represents the value
         'buffer[31] := 8                       
        'buffer[mIndex] := 0'mIndex'mValue
         buffer[mValue - 48] := lRec

{{
7seg CA CC (China) blue=ca, red=cc

    g  f  +  a  b
    1  2  3  4  5
 
    -a
  f|  |b
    -g
  e|  |c
    -d.dp
    
   10  9  8  7  6
    e  d  +  c  dp
}}
PUB Write595BitD(Data2,cpin,dpin,delay)
  ' write data
  outa[dpin] := Data2
  ' toggle clock
  outa[cpin] := 0
  waitcnt(cnt + clkfreq / delay * 1)
   
  outa[cpin] := 1
  waitcnt(cnt + clkfreq / delay * 1)
  
PUB Write595Bit(Data2,cpin,dpin)
  ' write data
  outa[dpin] := Data2
  ' toggle clock
  outa[cpin] := 0
  'waitcnt(cnt + clkfreq / 390 * 1)
   
  outa[cpin] := 1
  'waitcnt(cnt + clkfreq / 390 * 1)

PUB Flasher8(delay) | index, offset, address, valueHold
 repeat
  waitcnt(clkfreq * 181 + cnt)
  repeat offset from 0 to 0
    repeat index from 7 to 0
      address := index + (8 * offset)
      if buffer[address] < 16
        valueHold := buffer[address]
        buffer[address] := 8'buffer[address] + 16
        waitcnt(clkfreq / delay + cnt)
        buffer[address] := valueHold'buffer[address] - 16
      else
        valueHold := buffer[address]
        buffer[address] := valueHold'buffer[address] - 16
        waitcnt(clkfreq / delay + cnt)
        buffer[address] := 8'buffer[address] + 16
 '     waitcnt(clkfreq / delay + cnt)
  {  repeat index from 0 to 7
      address := index + (8 * offset)    
      if buffer[address] < 16
        buffer[address] := buffer[address] + 16
        waitcnt(clkfreq / delay + cnt)
        buffer[address] := buffer[address] - 16
      else
        buffer[address] := buffer[address] - 16
        waitcnt(clkfreq / delay + cnt)
        buffer[address] := buffer[address] + 16
'      waitcnt(clkfreq / delay + cnt)
   }
PUB FlasherPoint(delay) | index, offset, address, valueHold
 repeat
  waitcnt(clkfreq * 5 + cnt)
  repeat offset from 1 to 2
    repeat index from 0 to 7
      address := index + (8 * offset)
      if buffer[address] < 16
        buffer[address] := buffer[address] + 16
        waitcnt(clkfreq / delay + cnt)
        buffer[address] := buffer[address] - 16
      else
        buffer[address] := buffer[address] - 16
        waitcnt(clkfreq / delay + cnt)
        buffer[address] := buffer[address] + 16
  
PUB Push8seg(dOffset, Data,cpin,rpin,dpin, delay,mux) | dValue,loop, index, muxOffset, dByte, blueOn, cBit, dBit, sft595, tempPartAddress, segValue, colVal, hiddenColumn
  ' LED display is driven by 2 595 shift registers
  ' 595-1 is the column driver
  ' 595-2 is the data driver
  
  dira[cpin] := 1
  outa[cpin] := 0
  dira[rpin] := 1
  outa[rpin] := 0
  dira[dpin] := 1
  outa[dpin] := 0
  ' Hardware configuration
  ' 76543210 <--  sweep direction
  ' BBBBRRRR(BlueCA/RedCC)
  ' In format --> shift direction
  ' 0.............15
  ' gfab.cde0000c000
  
  muxOffset := 0
  repeat
   if muxOffset > 0
    muxOffset := 0
   else
    muxOffset := 1
   repeat loop from 16 to 100
    
    ' initially blank display
    ' shift 16 bits into 1 of 4 rows 0-7=column, 8-f=data
    ' blue 4 digits - common anode
     repeat dByte from 0 to 7'buffSize
       dValue := buffer[dByte + dOffset]
     ' do PWM
      if mux > 0
       repeat 1'loop / 16
        'waitcnt(clkfreq / 1000 + cnt)
        if muxOffset > 0
         repeat 16
          Write595Bit(0,cpin,dpin)
        ' push storage reg to output reg
         outa[rpin] := 0
         outa[rpin] := 1
       
      waitcnt(clkfreq / (delay) + cnt)
       if dByte < 4
         colVal := 0
       else
         colVal := 1       
       ' shift in data bits first
       repeat dBit from 0 to 7
         'segValue := segDigit[8 * buffer[dByte] + (7 - dBit)]
         if dValue < 16
           segValue := segDigit[(8 * dValue + (7 - dBit))]
         else 
           segValue := segDigit2[(8 * (dValue - 16) + (7 - dBit))]
         if colVal < 1       
            Write595Bit(segValue,cpin,dpin)
         else
            Write595Bit(1 - segValue,cpin,dpin)
          
        
       ' shift in column bits last
         {
       ' 0...:...7
         1000:1111
         0100:1111
         0010:1111
         0001:1111
         0000:0111
         0000:1011
         0000:1101
         0000:1110
         }
       ' skip initial blue
       hiddenColumn := 0
       blueOn := 1
       if dByte < 4 ' red
         ' 4 blank blue
         repeat 4
           Write595Bit(1 - blueOn,cpin,dpin)          
         repeat (3 - dByte)
           Write595Bit(blueOn,cpin,dpin)
         Write595Bit(1 - blueOn,cpin,dpin)          
         repeat dByte
           Write595Bit(blueOn,cpin,dpin)
       else ' blue
         repeat (3 - (dByte - 4))
           Write595Bit(1 - blueOn,cpin,dpin)
         Write595Bit(blueOn,cpin,dpin)          
         repeat (dByte - 4)
           Write595Bit(1 - blueOn,cpin,dpin)
         ' 4 blank red
         repeat 4
           Write595Bit(blueOn,cpin,dpin)          

     ' push storage reg to output reg
      outa[rpin] := 0
      outa[rpin] := 1
       ' delay for display persistence

PUB Push8segRand(Data,cpin,rpin,dpin, delay) | index, dByte, cBit, dBit, sft595, tempPartAddress, segValue
  ' LED display is driven by 2 595 shift registers
  ' 595-1 is the column driver
  ' 595-2 is the data driver
  
  dira[cpin] := 1
  outa[cpin] := 0
  dira[rpin] := 1
  outa[rpin] := 0
  dira[dpin] := 1
  outa[dpin] := 0
  ' 01234567
  ' BBBBRRRR
  ' BBBBRRRR
  ' BBBBRRRR
  ' BBBBRRRR
  ' In format gfab.cde0000c000
     
  repeat
    ' initially blank display
    ' shift 16 bits in 4 rows
    repeat index from 0 to 7
      if ?RandomNum > 4000
        Write595BitD(1,cpin,dpin,delay)
      else      
        Write595BitD(0,cpin,dpin,delay)
        
      if ?RandomNum > 4000        
       outa[rpin] := 0
       outa[rpin] := 1
      ' delay for display persistence
       waitcnt(cnt + clkfreq / 390 * 1)
                   
DAT
'7seg CA CC SURE Electronics blue=ca, red=cc
'    g  f  +  a  b
'    1  2  3  4  5
'
'    -a
'  f|  |b
'    -g
'  e|  |c
'    -d.dp
'
'   10  9  8  7  6
'    e  d  +  c  dp
'

  'gfab.cde                                                                                                                       
  ' 0 1 2 3 4 5 6 7 8 9 a b c d e f g h i j k l m n o p q r s t u v w x y z - +
  segDigit byte 0,1,1,1, 0,1,1,1,  0,0,0,1, 0,1,0,0,  1,0,1,1, 0,0,1,1,  1,0,1,1, 0,1,1,0,  1,1,0,1, 0,1,0,0,  1,1,1,0, 0,1,1,0,  1,1,1,0, 0,1,1,1,  0,0,1,1, 0,1,0,0,  1,1,1,1, 0,1,1,1,  1,1,1,1, 0,1,1,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 1,0,0,0
  segDigit2 byte 0,1,1,1, 1,1,1,1,  0,0,0,1, 1,1,0,0,  1,0,1,1, 1,0,1,1,  1,0,1,1, 1,1,1,0,  1,1,0,1, 1,1,0,0,  1,1,1,0, 1,1,1,0,  1,1,1,0, 1,1,1,1,  0,0,1,1, 1,1,0,0,  1,1,1,1, 1,1,1,1,  1,1,1,1, 1,1,1,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0
Digit7seg     word %01110111 '0
              word %00010100 '1
              word %10110011 '2
              word %10110110 '3
              word %11010100 '4
              word %11100110 '5
              word %11100111 '6
              word %00110100 '7
              word %11110111 '8
              word %11110110 '9
              word %00000000 '10 blanking digit

{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}