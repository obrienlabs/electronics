''=============================================================================
''
'' @file     propCollatz
'' @target   Propeller
'' @purpose  Calculate Hailstone sequence in support of the Collatz conjecture
''
''
'' @see
''   http://wiki.eclipse.org/EclipseLink/Examples/Distributed
''   http://obrienscience.blogspot.com/2011/01/sequences-and-patterns.html
''   http://en.wikipedia.org/wiki/Collatz_conjecture
''   http://oeis.org/A006877
''   http://oeis.org/A006878
''   Tomás Oliveira e Silva
''   http://www.ieeta.pt/~tos/3x+1.html
''   Eric_Roosendaal_On The 3x + 1 Problem
''   http://www.ericr.nl/wondrous/index.html
''   http://www.ericr.nl/wondrous/pathrecs.html
''   http://propeller.wikispaces.com/MATH
''   http://ucontroller.com/spinreference.pdf
''   deSilva (2007)
''   http://forums.parallax.com/showthread.php?96594-Machine-Language-Tutorial!&p=668559
''   http://forums.parallax.com/attachment.php?attachmentid=48819&d=1187755108
''   http://forums.parallax.com/showthread.php?126592-Floating-point-math-and-the-propeller
''   http://forums.parallax.com/showthread.php?87722-Assembly-Code-Examples-for-the-Beginner&p=601870
''   http://www.parallax.com/Portals/0/Downloads/docs/cols/nv/prop/col/nvp6.pdf
''   Fixed point math
''   http://www.emesystems.com/BS2math6.htm
''   R2000: 67,457,283,406,188,652 = P:2000 M:168,195,644,987,150,592,625,336
''
'' @author   Michael O'Brien 
''
'' @version  V0.001 - 2011 Jan 26
'' @changes
''  - original version
'' 20110126 - start
''            For 80MHz (1of8 cogs) we take 76sec to do 10000 iterations of num 27 (111 path)
''            which is 2.2million ops/76sec = 29.2KIPS for interpreted SPIN
''            or 148 seq/sec or about 1000 times slower than a P4 on a JVM
'' 20110312 - start PASM machine language version
''            Wrote my first assembly routing for the propeller in 2 hours - a testament to deSilva's PDF to page 14
''            stats: 20bits = 50 sec for collatz#27:110 or 115 million iter / 50 sec
''            = 2.3million iter/sec at 32 bit precision
'' 20111226 - v12 (removed OUTA and shifting for LED output from assembly loop)
''            20 bits / 48 sec for collatz#27:110 or = 21850 seq/sec for 27:111 or 150x faster than the spin version
''            = 2.4 million iter/sec
''            = 24000 times slower than 2.2Ghz T4400 x86 c code (or we need 3000 chips to equal one 32nm pentium) 
'' 36 sec for 2^35 of 27:111:9232 on 64-bit i7-920 2.8Ghz 32-bit code = 955 million seq/sec = 105 billion iter/sec
'' 46 sec for 2^35 of 27:111:9232 on 64-bit E8400 3.0Ghz 32-bit code  = 747 million seq/sec =  82 billion iter/sec
'' 53 sec for 2^35 of 27:111:9232 on 64-bit Q6600 2.6Ghz 32-bit code  = 648 million seq/sec =  71 billion iter/sec
'' 65 sec for 2^35 of 27:111:9232 on 32-bit T4400 2.1Ghz 32-bit code  = 528 million seq/sec =  58 billion iter/sec


''
''            
''=============================================================================
CON
  _clkmode = xtal1 + pll16x ' serial IO does not work below 2x
  _xinfreq = 5_000_000
  ' 0-7   hypercube inputs
  HCUBE_0_IN  = 0
  HCUBE_1_IN  = 2
  HCUBE_2_IN  = 4
  HCUBE_3_IN  = 6  
  ' 8-15  NEWS LI/RO/LO/RI
  NEWS_LI_IN  = 8
  NEWS_RO_OUT = 10
  NEWS_LO_OUT = 12
  NEWS_RI_IN  = 14  
  ' 16-23 LED/hypercube output
  HCUBE_0_OUT = 16
  HCUBE_1_OUT = 18
  HCUBE_2_OUT = 20
  HCUBE_3_OUT = 22
  LED_1_OUT = 17
  LED_3_OUT = 19
  LED_5_OUT = 21
  LED_7_OUT = 23  
  ' 24 clk
  GLOBAL_CLK_IN = 24
  ' 26 reset
  GLOBAL_RES_IN = 26
  
VAR
  ' shared display RAM for the 4 display cogs
  long  buffer[32]                                         
  long  Stack0[128]                                         ' Stack Space
  byte  Cog[7]                                             ' Cog ID
  long  randomNum
  long  range
  long  aCounter
  long  aCounter2
  long  result0[8]
  long  result1[8]
OBJ
  SER  : "Parallax Serial Terminal.spin"                   ' part of the IDE library  
  STR  : "STREngine.spin"                                  ' in the current directory
PUB main | tCnt, milestone,start,number,index, lRec,x,i, mIndex, mValue, path,height, maxPath, maxHeight
  ' wait for user to switch to terminal
  waitcnt((clkfreq * 5) + cnt)

  ' SET global pins
  dira[HCUBE_0_IN]    := 0
  dira[HCUBE_1_IN]    := 0
  dira[HCUBE_2_IN]    := 0
  dira[HCUBE_3_IN]    := 0  
  ' 8-15  NEWS LI/RO/LO/RI
  dira[NEWS_LI_IN]    := 0
  dira[NEWS_RO_OUT]   := 1
  dira[NEWS_LO_OUT]   := 1
  dira[NEWS_RI_IN]    := 0  
  ' 16-23 LED/hypercube output
  dira[HCUBE_0_OUT]   := 1
  dira[HCUBE_1_OUT]   := 1
  dira[HCUBE_2_OUT]   := 1
  dira[HCUBE_3_OUT]   := 1
  dira[LED_1_OUT]     := 1
  dira[LED_3_OUT]     := 1
  dira[LED_5_OUT]     := 1
  dira[LED_7_OUT]     := 1  
  
  ' 24 clk
  dira[GLOBAL_CLK_IN] := 0
  ' 26 reset
  dira[GLOBAL_RES_IN] := 0
  
  maxPath := 0
  maxHeight := 0
  milestone := 0 ' track whether we got a path or max height hit
  range := 1 << 17'7

  ser.Start(115_200)'31,30,0,38400)
  ser.Home
  ser.Clear
  ser.Str(string("Collatz Conjecture", ser#NL))
  ' 44  1,410,123,943  7,125,885,122,794,452,160  31 63 


  aCounter := 77671'27'1410123943'270271'77671'159487
  aCounter2 := 27'1410123943'270271'77671'159487
  ser.Str(string("Start:  "))
  ser.Str(STR.numberToDecimal(aCounter,16))
  ser.Str(string(ser#NL))
  tCnt := cnt
'  _nextVal0 := @aCounter ' pass word to assembly via hub ram
'  ser.Str(string("Max Value for "))
'  ser.Str(STR.numberToDecimal(aCounter,8))
'  ser.Str(string(" is "))
  ' do PASM machine language first
  Cog[1] := cognew(@entry, @aCounter) + 1
  'Cog[2] := cognew(@entry, @aCounter2) + 1
  'Cog[3] := cognew(@entry, @aCounter) + 1
  'Cog[4] := cognew(@entry, @aCounter) + 1
  'Cog[5] := cognew(@entry, @aCounter) + 1
  'Cog[6] := cognew(@entry, @aCounter) + 1
  'Cog[7] := cognew(@entry, @aCounter) + 1
  ' check semaphore
  
  waitcnt((clkfreq * 1) + cnt)  ' it takes 100ms to load a core
  ser.Str(STR.numberToDecimal(cnt - tCnt,32))
  'waitcnt((512 << 4) + cnt)  ' it takes 100ms to load a core
  ser.Str(string(ser#NL))  
  ser.Str(string("Max:    "))
  ser.Str(STR.numberToDecimal(aCounter2,32))
  ser.Str(string(ser#NL))
  ser.Str(string("Path:   "))
  ser.Str(STR.numberToDecimal(_path,32))
  ser.Str(string(ser#NL))
  ' wait for the PASM cog to signal it is finished
  'repeat
    milestone := 1
  'repeat until aCounter > 9231
  '  maxPath := 0
  ser.Str(STR.numberToDecimal(aCounter,8))

  'loop
  repeat 
   'ser.Str(string("x"))
   waitcnt((clkfreq / 10) + cnt)    
  
  ' then do SPIN  
  ' main loop
 {{ repeat x from 1 to range step 2 ' last valid # for 32 bit longs is 113381 - we use 2 << 17
     start := x'77031'27
     path := 1 ' optimize for ending 4-2-1 sequence 
     height := 0
     number := start     
     repeat until number == 4
       ' if odd transform by 3n+1, else n/2 
       if (number // 2) == 0
         number := number >> 1
       else
         number := (number << 1) + number + 1

       path := path + 1  
       if height < number
         height := number

     ' check maximums
     if maxHeight < height
       maxHeight := height
       milestone := 1 ' flag a hit
        
     if maxPath < path
       ser.Str(string(ser#NL))
       maxPath := path
       if milestone > 0
         ser.Str(string("PM: "))
       else
         ser.Str(string(" P: "))
         milestone := 1 ' flag a hit
     else
       if milestone > 0
         ser.Str(string(ser#NL))
         ser.Str(string(" M: "))
           
  '  print out result if a new record
     if milestone > 0 
       ser.Str(STR.numberToDecimal(x,8))
       ser.Str(string(" Path: "))
       ser.Str(STR.numberToDecimal(path,8))
       ser.Str(string(" Max:  "))
       ser.Str(STR.numberToDecimal(height,31))
       milestone := 0  

  ser.Str(string(ser#NL))
  ser.Str(string("End of line", ser#NL))
  ser.Str(string(ser#NL))

  ' wait to allow the port to catch up before closing    
  waitcnt((clkfreq * 4) + cnt)    
}}
  ser.stop
      
{{
  http://www.parallax.com/dl/docs/prod/prop/AssemblyElements.pdf
6 Bits: instruction or operation code (OPCODE)
3 Bits: setting flags (Z, C) and result
1 Bit: immediate addressing
4 Bits: execution condition
9 Bits: dest-register
9 Bits: source register or immediate value
}}  
DAT
              ORG       0
entry         ' iterate the collatz sequence for _nextVal
              MOV       _time, CNT         ' get a copy of the system counter
              ADD       _time, _toffset    ' add timing offset
              WAITCNT   _time, _toffset    ' wait, with synchronized offset
              
              RDLONG    _nextVal0, PAR     ' read from shared ram (7-22 cycles)
              MOV       _loops, #1
              SHL       _loops, #1         ' load 2^24 iteration count (16777216)
              MOV       DIRA, _ledDir
              MOV       OUTA, 27'_loops
              SHL       OUTA, #9
:reset
              'MOV       _nextVal0, #27      ' hardcode start of search at 27
              CMP       _loops, #0 WZ
         IF_E JMP       #:finish
              SUB       _loops, #1
              MOV       OUTA, _loops
              SHL       OUTA, #9
              'MOV       _bit0, #1           ' create mask
:iterate
              'MOV       OUTA, _loops
              'SHL       OUTA, #9
              ADD       _path, #1           ' increment path
              'MOV       _bit0, #1           ' create mask
              AND       _bit0, _nextVal0 NR,WZ ' check bit 0 - affect zero flag. do not write to target
        IF_NE JMP       #:mul3x1
:div2         ' if even we divide by 2
              SHR       _nextVal1, #1 WC    ' divide upper 32 bits by 2 with carry propagation
              SHR       _nextVal0, #1 WC    ' divide lower 32 bits by 2
              CMP       _nextVal0, #0
         IF_NE JMP       #:continue2             ' sequence returned to 1 - exit               
              CMP       _nextVal0, #1 WZ    ' check for 1 value == finished
         IF_E JMP       #:reset             ' sequence returned to 1 - exit              
:continue2    JMP       #:iterate           ' return to top of loop
:mul3x1       ' if odd we transform by 3n + 1
              MOV       _3rdVal0, _nextVal0  ' save n for adding later
              MOV       _3rdVal1, _nextVal1
              SHL       _nextVal0, #1 WC     ' multiply by 2
              SHL       _nextVal1, #1 WC     ' multiply by 2              
              ADD       _nextVal0, #1 WC      ' add 1
              ADD       _nextVal1, #0 WC      ' add 0 (to propagate carry)
              ADD       _nextVal0, _3rdVal0 WC  ' add to multiply by 3
              ADDX      _nextVal1, _3rdVal1 WC ' add next 32 bits
              
              'MOV       OUTA, _nextVal0
              'SHL       OUTA, #9
              
:maxValue     ' check for maximum value (check msb first
              MIN       _maxVal1, _nextVal1 ' VERY ODD (max is actually min)
              MIN       _maxVal0, _nextVal0 ' VERY ODD (max is actually min)
              JMP       #:iterate           ' return to top of loop
:finish
              SUB       _path, #1           ' we discount the first path count
              'MOV       _nextVal0, _path    ' copy path to return val
              'WRLONG    _nextVal0, PAR      ' write back to hub ram (thank you deSilva for reverse flow explanation)
              WRLONG    _maxVal0, PAR               
              MOV       _time, CNT         ' get a copy of the system counter
              ADD       _time, _toffset    ' add timing offset
:endlessLoop  ' toggle LEDs 
              MOV       OUTA, #1'170
              SHL       OUTA, #16
              'WAITPEQ   OUTA, #1     f       ' wait for a pin transition at 13% power
              WAITCNT   _time, _toffset
              MOV       OUTA, #0'#85
              SHL       OUTA, #16
              WAITCNT   _time, _toffset
              JMP       #:endlessLoop       ' keep the cog running
_3rdVal1      long      $00000000
_3rdVal0      long      $00000000
_nextVal1     long      $00000000      
_nextVal0     long      $00000000      
_maxVal1      long      $00000000
_maxVal0      long      $00000000
_path         long      $00000000
_bit0         long      $00000001
_loops        long      $00000000
_ledDir       long      $FFFF<<16
_ledOut       long      $FFFFFFFF
_time         long      $00000000 ' copy of cnt counter
_toffset      long      $000cffff ' sync time offset addition
              FIT       496                 ' do we fit in 496 ram deSilva (16 I/O registers in 496-511)

'' http://forums.parallax.com/showthread.php?96594-Machine-Language-Tutorial!&p=668559              

{{
>Java
PM,N,0,26623,   26623,L,307     ,M,  106358020  ,T,254
M,N,0,31911,    31911,L,160     ,M,  121012864  ,T,277
P,N,0,34239,    34239,L,310     ,M,   18976192  ,T,288
P,N,0,35655,    35655,L,323     ,M,   41163712  ,T,294
P,N,0,52527,    52527,L,339     ,M,  106358020  ,T,376
M,N,0,60975,    60975,L,334     ,M,  593279152  ,T,415
P,N,0,77031,    77031,L,350     ,M,   21933016  ,T,487
M,N,0,77671,    77671,L,231     ,M, 1570824736  ,T,490
P,N,0,106239,   106239,L,353    ,M,  104674192  ,T,623
M,N,0,113383,   113383,L,247    ,M, 2482111348  ,T,659
M,N,0,138367,   138367,L,162    ,M, 2798323360  ,T,789
P,N,0,142587,   142587,L,374    ,M,  593279152  ,T,811
P,N,0,156159,   156159,L,382    ,M,   41163712  ,T,880
M,N,0,159487,   159487,L,183    ,M,17202377752  ,T,898
P,N,0,216367,   216367,L,385    ,M,   11843332  ,T,1179
P,N,0,230631,   230631,L,442    ,M,   76778008  ,T,1253
M,N,0,270271,   270271,L,406    ,M,24648077896  ,T,1453


>SPIN
PH:  00026623 Path:  00000307 Max:   0106358020
 H:  00031911 Path:  00000160 Max:   0121012864
 P:  00034239 Path:  00000310 Max:   0018976192
 P:  00035655 Path:  00000323 Max:   0041163712
 P:  00052527 Path:  00000339 Max:   0106358020
 H:  00060975 Path:  00000334 Max:   0593279152
 P:  00077031 Path:  00000350 Max:   0021933016
 H:  00077671 Path:  00000231 Max:   1570824736
 P:  00106239 Path:  00000353 Max:   0104674192
 H:  00113383 Path:  00000247 Max:   1861583512 ' 32-bit overflow
 H:  00138367 Path:  00000162 Max:   1865548906 ' 32-bit overflow
 P:  00142587 Path:  00000374 Max:   0593279152
 P:  00156159 Path:  00000382 Max:   0041163712
 H:  00198079 Path:  00000279 Max:   2030295616 ' 32-bit overflow, wrong path
 P:  00216367 Path:  00000385 Max:   0011843332 ' 
 P:  00230631 Path:  00000442 Max:   0076778008
 H:  00270271 Path:  00000415 Max:   2138110162 ' 32-bit overflow, wrong path

}}
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