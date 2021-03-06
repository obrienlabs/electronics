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
'' 20101212 - soldered prototype requires 1 cog for 4 lines (PASM)
''=============================================================================
CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000
VAR
  ' shared display RAM for the 4 display cogs
  long buffer[32]                                         
  long Stack0[80]                                         ' Stack Space
  long Stack1[64]                                         ' Stack Space
  long Stack2[64]                                         ' Stack Space
  byte Cog[6]                                             ' Cog ID
  long  randomNum
  byte rotate
OBJ
   SER    : "FullDuplexSerial"    
  
PUB main | mIndex, mValue, lRec, i,lastRawTemp, lastRawHumidity, prevOnesDigit, rawTemp, rawHumidity, tempC, tempC2, tempPoint2, rh, dewC, tPin, tempPoint, tempTen, tempOne, humTen, humOne
  ' initialize array prior to any PC connection
  repeat i from 0 to 31
   buffer[i] := 11
{
  buffer[0] := 10
  buffer[1] := 10
  buffer[2] := 10
  buffer[3] := 10
  buffer[4] := 11
  buffer[5] := 11
  buffer[6] := 11
  buffer[7] := 11

  buffer[8] := 2
  buffer[9] := 3
  buffer[10] := 4
  buffer[11] := 5
  buffer[12] := 11
  buffer[13] := 11
  buffer[14] := 11
  buffer[15] := 11

  buffer[16] := 11
  buffer[17] := 3
  buffer[18] := 4
  buffer[19] := 5
  buffer[20] := 6
  buffer[21] := 10
  buffer[22] := 11
  buffer[23] := 11

  buffer[24] := 9
  buffer[25] := 8
  buffer[26] := 7
  buffer[27] := 6
  buffer[28] := 5
  buffer[29] := 4
  buffer[30] := 11
  buffer[31] := 11
  }
  ' set rotation off
  rotate := 0'7
   

  {{
    Each line of 8 LED 7-segments are driven by a 595 SIPO pair by a single cog
    No resistors are required as the inherent resistance of the 595 output pins
    is enough to limit the current below 20ma.
    The 3 pin parameters below are for the Shift Clock, Register Clock and Data pins.

  }}
  Cog[0] := cognew(Push8segAllRed(1,buffer,2,3,4, 24_000,0), @Stack0) + 1
'  Cog[1] := cognew(Push8seg(1,8,buffer,5,6,7,50_000,0), @Stack1) + 1
'  Cog[2] := cognew(Push8seg(1,16,buffer,8,9,10,24_000,0), @Stack2) + 1
'  Cog[3] := cognew(Push8seg(1,24,buffer,11,12,13,30_000,0), @Stack3) + 1
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
       rotate := 0
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
{PUB Write595Bit(Data2,cpin,dpin)
  ' write data
  outa[dpin] := Data2
  ' toggle clock
  outa[cpin] := 0
  'waitcnt(cnt + clkfreq / 390 * 1)
  outa[cpin] := 1
  'waitcnt(cnt + clkfreq / 390 * 1)
}

{ This update routine has rolled out most of the shifting code
  SPIN can just barely update 4 rows of 8 chars without seeing the refresh rate.
  A PASM version will be required for more than 32 characters.
}
PUB Push8segAllRed(allRed,Data,cpin,rpin,dpin, delay,mux) | char,tPartAddress,tPartAddress2,dOffset, line,dValue,loop, index, dByte, blueOn, cBit, dBit, sft595,segValue, colVal
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
  ' BBBBRRRR(BlueCA/RedCC) or RRRRRRRR
  ' In format --> shift direction
  ' 0.............15
  ' gfab.cde0000c000
  
  repeat
    repeat char from 0 to rotate
     repeat 8
      ' shift 16 bits into 1 of 4 rows 0-7=column, 8-f=data
      repeat dByte from 0 to 7'buffSize
       repeat line from 0 to 24 step 8
         'dOffset := line << 3
         dValue := buffer[dbyte + char + line]'dOffset]
'         waitcnt(clkfreq / (delay) + cnt)
         ' shift in data bits first
         tPartAddress := dValue << 3
         'tPartAddress2 := (dValue - 16) << 3
         repeat dBit from 0 to 7
           'if dValue < 16
             segValue := segDigit[(tPartAddress + (7 - dBit))]
           'else 
           '  segValue := segDigit2[(tPartAddress2 + (7 - dBit))]
           'Write595Bit(1 - segValue,cpin,dpin)
           outa[dpin] := 1 - segValue
           outa[cpin] := 0
           outa[cpin] := 1

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
         repeat (7 - dByte)
         'Write595Bit(0,cpin,dpin)
           outa[dpin] := 0
           outa[cpin] := 0
           outa[cpin] := 1
         'Write595Bit(1,cpin,dpin)'1 - blueOn,cpin,dpin)          
         outa[dpin] := 1
         outa[cpin] := 0
         outa[cpin] := 1
         repeat dByte
           'Write595Bit(0,cpin,dpin)
           outa[dpin] := 0
           outa[cpin] := 0
           outa[cpin] := 1

      ' push storage reg to output reg
       outa[rpin] := 0
       outa[rpin] := 1
       ' delay for display persistence
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

'7seg CC 4x7seg small module SURE Electronics red=cc
'    digits 4-3-2-1
'    g  f  +  a  b
'    12 11 10 9  8  7
'
'    -a
'  f|  |b
'    -g
'  e|  |c
'    -d.dp
'
'    1  2  3  4  5  6
'    e  d  +  c  dp
'

  'gfab.cde                                                                                                                       
  ' 0 1 2 3 4 5 6 7 8 9 a b c d e f g h i j k l m n o p q r s t u v w x y z - +
  segDigit byte 0,1,1,1, 0,1,1,1,  0,0,0,1, 0,1,0,0,  1,0,1,1, 0,0,1,1,  1,0,1,1, 0,1,1,0,  1,1,0,1, 0,1,0,0,  1,1,1,0, 0,1,1,0,  1,1,1,0, 0,1,1,1,  0,0,1,1, 0,1,0,0,  1,1,1,1, 0,1,1,1,  1,1,1,1, 0,1,1,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 1,0,0,0
  segDigit2 byte 0,1,1,1, 1,1,1,1,  0,0,0,1, 1,1,0,0,  1,0,1,1, 1,0,1,1,  1,0,1,1, 1,1,1,0,  1,1,0,1, 1,1,0,0,  1,1,1,0, 1,1,1,0,  1,1,1,0, 1,1,1,1,  0,0,1,1, 1,1,0,0,  1,1,1,1, 1,1,1,1,  1,1,1,1, 1,1,1,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0
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