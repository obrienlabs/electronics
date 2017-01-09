{ 20081202
  Propeller Array Driver

  Michael O'Brien
  michael@obrienm.com

  automation:
   propellent /port COM3 _propDisp4x8_1inch_blue_7seg.spin
  
  20100630 : POC
  20100803 : k: 4 levels of brightness (2-bit)
  20100804 : l: all 4 quads now independent
  20100804 : m: quads are in proper x,y order of 0,2,1,3 instead of 0,1,2,3
  20100804 : n: 7 cogs controlling display data, 1 cog to display it 
                          
             
}
CON                                                                 
  ' 40 Pin DIP
{
   WARNING:
   Do Not use PLL16X (20 MIPS) - keep multiplier between 1 and 4 (1.2 and 5 MIPS)
   Or the power transistor will OVERHEAT.
   WARNING:
}
  
'  _CLKMODE = XINPUT + PLL1X     ' clock speed to low = 1X=5Mhz
'  _XINFREQ = 5_000_000
  ' non-spin stamp
  _CLKMODE = XTAL1 + PLL16X     ' clock speed to high = 80Mhz
  _XINFREQ = 5_000_000

  NUM_PROC_CELLS     = 8
  STACK_SIZE = 64
  
  
  ' output/input pin assignments for a vector/ring topology
  ' these numbers are propeller demo board friendly 0-8 data, 16-23 LED
  '
  ' 
  CHIP_LED0  = 0'23
  CON0_OUT  = 25'8
  CON1_OUT  = 26'9
  CON2_OUT  = 27'10
  RESET_OUT = 9
  RESET_IN  = 8
  P165S_OUT = 2 
  P165C_OUT = 3
  P165D_IN  = 4
  P595D_A_OUT        = 7
  P595D_R_OUT        = 6
  P595D_S_OUT        = 5

  DISPLAY_LINE_HOLD  = 500'500_400
'  DISPLAY_LINE_HOLD  = 100_400  
 ' DISPLAY_BIT_HOLD   = 1_000_000  

  _pageSize       = 64
  _memCellsTotal  = 256
  _gridCellsTotal = 256
    
  

VAR
  ' object level variables
  ' stack mem per processor
  long  regStack0[STACK_SIZE]
  long  regStack1[STACK_SIZE]
  long  regStack2[STACK_SIZE]
  long  regStack3[STACK_SIZE]    
  long  regStack4[STACK_SIZE]    
  long  regStack5[STACK_SIZE]    
  long  regStack6[16]    
  long  randomNum
  long  generation
  byte  syncState 
  byte  resetComplete
  byte  prevGrid[256]
  byte  nextGrid[256]

  ' Inter processor communication
  ' We dont want to change frames in mid display-processing
  byte  sigReloadFrame ' signal processing cog that display cog is finished with frame
  ' In memory 16x16 
  byte  prevMemGrid[256]
  byte  nextMemGrid[256]  

  ' CA Cog variables
{  byte  caColor
  byte  caValue
  long  caCellAddress
  long  caTempAddress
  byte  caTseqTemp
  byte  caSum
'  byte  caX1
'  byte  caY1
  long  caCurrentFrame
}  
   
OBJ
  SER    : "FullDuplexSerial"  
                 
DAT
  cog         long  0               'cog flag/id
  ' shared global variables
  state       long 0
  

PUB Main
  ' initialize digit store
  randomNum := 65535
  syncState := 0
  generation := 0  

  ' prepare pins for input (dont use repeat - for flexibility)
  ' INPUT
  dira[P165D_IN]   := 0
  dira[RESET_IN]   := 0

  ' OUTPUT
  dira[CHIP_LED0]  := 1
  dira[RESET_OUT]  := 1
  dira[CON0_OUT]   := 1
  dira[CON1_OUT]   := 1
  dira[CON2_OUT]   := 1
  dira[P165S_OUT]  := 1
  dira[P165C_OUT]  := 1

'  dira[P595_A_STATE_OUT]   := 1
'  dira[P595_RCLK1_OUT]     := 1
'  dira[P595_SCLK1_OUT]     := 1
  

  ' Toggle RESET_OUT immediately so we can cascade programming other propellers
  outa[RESET_OUT] := 0
  outa[RESET_OUT] := 1

   ' set chip state pin
'  outa[CHIP_LED0] := 1     

  {
    Grid
    0 1
    2 3
    4 5
    6 7
  }
  {

Core Enumeration
----------------
         0  1  adj#
 NW7    | N0 | NE1
15    7 |6  7| 6     2
+-------+====+----
14    1 |0  1| 0     3
13 W6 3 |2  3| 2 E2  4
12    5 |4  5| 4     5
11    7 |6  7| 6     6
+-------+====+----
10    1 |0  1| 0     7
 SW5    | S4 | SE3
         9  8
 }  
' adjacent cells
' 0 ext(0,1,13,14,15)
' 1 ext(0,1,2,3,4) 
' 2 ext(12,13,14) 
' 3 ext(3,4,5) 
' 4 ext(11,12,13) 
' 5 ext(4,5,6) 
' 6 ext(8,9,10,11,12) 
' 7 ext(5,6,7,8,9) 

' 0 int(1,2,3)
' 1 int(0,2,3) 
' 2 int(0,1,3,4,5) 
' 3 int(0,1,2,4,5) 
' 4 int(2,3,5,6,7) 
' 5 int(2,3,4,5,7) 
' 6 int(4,5,7) 
' 7 int(4,5,6) 

{ Concurrency Issues
--------------------
1) Each core handles a calcuation and setting of its' finished bit
2) Who resets the finished bits for all cogs for the next generation?
   A) The first one that sees all finished bits set to [1]
}
'  ser.start(31,30,0,38400)
'  ser.tx(0)
   ClearGrid(0)
   
'   SetNextCell(0,0,0)
'   SetNextCell(0,7,1)
'   SetNextCell(7,0,2)
'   SetNextCell(7,7,3)

'  cognew(ControlBitsProcess(1, 0, 0), @regStack1)
'  cognew(Push(1, 0), @regStack1)

'  cogNew(TestModifyGrid(0,0,0,16,1_000_000), @regStack0)
'  cogNew(TestModifyGrid(1,1,0,17,2_000_000), @regStack1)
'  cogNew(TestModifyGrid(2,5,3,18,3_000_000), @regStack2)    
'  cogNew(TestModifyGrid(3,2,7,19,4_000_000), @regStack3)
'  cogNew(TestModifyGrid(4,10,2,20,6_000_000), @regStack4)
'  cogNew(TestModifyGrid(5,14,15,22,10_000_000), @regStack5)
'  cogNew(FlashGrid(0,14,15,22,105_000_000,8_000_000), @regStack6)
  cogNew(FlashGrid(0,14,15,22,400,300), @regStack6)    
  PushLEDGrid(1, 0)
  ' load current processor 0 last
'  InputShiftRegisterProcess(0, COG0_OUT, cog0state)
  repeat
    outa[CHIP_LED0]~~
     
PUB ControlBitsProcess(procNum,lStatePin,initState) | lCounter
  repeat
    outa[CON0_OUT]~~
    waitcnt(4_000_000 + cnt)                                                               

' 165HC PISO shift register handler
PUB InputShiftRegisterProcess 

PUB ResetListener(processorNum) | inVal
  ' Toggle RESET_OUT immediately so we can cascade programming other propellers
  dira[RESET_OUT] := 1  
  outa[RESET_OUT] := 0
  outa[RESET_OUT] := 1

  dira[RESET_IN]  := 0
  ' wait for reset return signal
  repeat
    inVal := ina[RESET_IN]
    if inVal < 1
      waitcnt(60_400_000 + cnt)      
      resetComplete := 1 - resetComplete
      'outa[RESET_OUT] := 0
      'outa[RESET_OUT] := 1

  ' write control word to 595 buffers
{PUB PushControlWord(Data) | index, dByte, bitPos, cBit, bitValue
  ' shift out C15 first
  repeat bitPos from 0 to 7
    bitValue := 1 
    Write595Bit(bitValue)
    ' unfinished
 }
{ LED sweep ("Sure Inc" writing top)
column 0 --> 4
Row
    C0 1 2 3 4 5 6 7
R0 0
   1
 | 2
 | 3
 L 4
   5
   6
   7

}
PUB PushLEDSubQuad(quad, colLine,quadOffset) | colOffset,dBit
  repeat colLine
    outa[P595D_A_OUT] := 1
    ' shift bit into shift register
    outa[P595D_S_OUT] := 0
    outa[P595D_S_OUT] := 1

  outa[P595D_A_OUT] := 0
  ' shift bit into shift register
  outa[P595D_S_OUT] := 0
  outa[P595D_S_OUT] := 1
 
  repeat ((8 - (colLine + 1)))
    outa[P595D_A_OUT] := 1
    ' shift bit into shift register
    outa[P595D_S_OUT] := 0
    outa[P595D_S_OUT] := 1

  colOffset := colLine << 3 ' any multiplication must be done outside of a loop if possible  
  repeat dBit from 0 to 7
    outa[P595D_A_OUT] := nextGrid[quadOffset + colOffset + dBit]'dValue
    ' shift bit into shift register
    outa[P595D_S_OUT] := 0
    outa[P595D_S_OUT] := 1   
    
PUB PushLEDGrid(processorNum,initState) | quad,colLine
  dira[P595D_A_OUT] := 1
  dira[P595D_R_OUT] := 1
  dira[P595D_S_OUT] := 1
  ' setup 595 chips
  outa[P595D_A_OUT] := 1

  ' push out 16 bits to the 595 shift register
  ' --> [0..7 row] [0..7 col]
  repeat
    repeat colLine from 0 to 7
      PushLEDSubQuad(quad,colLine,192)
      PushLEDSubQuad(quad,colLine,64)
      PushLEDSubQuad(quad,colLine,128)
      PushLEDSubQuad(quad,colLine,0)
    '' Latch output register
          
     'waitcnt(DISPLAY_LINE_HOLD + cnt)    
     outa[P595D_R_OUT] := 0
     outa[P595D_R_OUT] := 1 

{PUB Pull(processorNum,initState) | dataOut
 ' read in 8x#proc bits from the 165 shift register
 repeat NUM_PROC_CELLS
  ' read data bit
  ' shift next bit
  outa[P595_SCLK1_OUT] := 0
  dira[P595_A_STATE_OUT] := 1
  dira[P595_RCLK1_OUT]   := 1
  dira[P595_SCLK1_OUT]   := 1
  ' setup 595 chips
  outa[P595_A_STATE_OUT] := 1

  ' push out 16 bits to the 595 shift register
  repeat
   repeat 1
     waitcnt(200_000 + cnt)   
     'outa[P595_A_STATE_OUT] := 1
     ' shift bit into shift register
     'outa[P595_SCLK1_OUT] := 0
     'outa[P595_SCLK1_OUT] := 1   
     ' latch output register
     'outa[P595_RCLK1_OUT] := 0
     'outa[P595_RCLK1_OUT] := 1 

     ' write data bit
     dataOut := 1
     if ?RandomNum > 6000
       dataOut := 0
     outa[P595_A_STATE_OUT] := dataOut
     ' shift bit into shift register
     outa[P595_SCLK1_OUT] := 0
     outa[P595_SCLK1_OUT] := 1   
   ' latch output register
     outa[P595_RCLK1_OUT] := 0
     outa[P595_RCLK1_OUT] := 1 
 
 }
PUB Push1(processorNum,initState) | lPulseMod
   lPulseMod :=  1'56
   if ?RandomNum > 6000
    lPulseMod :=  16'56

PUB FlashGrid(c,a,b,p,delay,delayFlash) | x, y, z
  repeat
    repeat x from 0 to 7
      repeat y from 0 to 7
        repeat z from 0 to 3
          SetNextCell(x,y,z)      
    SetNextCell(0,0,0)
    SetNextCell(7,0,1)
    SetNextCell(0,7,2)
    SetNextCell(7,7,3)
    waitcnt(delayFlash + cnt)    
    repeat x from 0 to 7
      repeat y from 0 to 7
        repeat z from 0 to 3
          ResetNextCell(x,y,z)      
    ResetNextCell(0,0,0)
    ResetNextCell(7,0,1)
    ResetNextCell(0,7,2)
    ResetNextCell(7,7,3)
    waitcnt(delay + cnt)    

    
PUB TestModifyGrid(c, a,b,p,delay) | x,y,px,py,dx,dy,pxo,pyo,xo,yo,qx,qy,qpy,qpx,it,ito,itd,xi, c1,pv
 dira[p] := 1
 pv := 0
 x := a
 y := b
 px := 0
 py := 0
 dx := 1
 dy := 1
 xo := 0
 yo := 0
 qpx := 0
 qpy := 0
 pxo := 0
 pyo := 0
 itd := 1
 ito := 0
 it := 123
 repeat
  repeat xi from 0 to 15
   x := xi'ito
'   y := ito
    ' iterate start position
     ito := ito + itd
     if ito < 0
       ito := 0
       itd := 1 ' reverse direction
     if itd > 15
       ito := 15
       itd := -1 ' reverse direction        
    repeat it
'     if c > 0
      if ?RandomNum > 4000
        if ?RandomNum > 2000
          if ?RandomNum > 1000
            if ?RandomNum > 500 ' limit of 8 stacks            
              x := x - dx
              pv := 1 - pv
              outa[p] := 1'pv
'              if c < 1
'                ReverseGrid(0)
'     if c > 0       
      if ?RandomNum > 4000
        if ?RandomNum > 2000
          if ?RandomNum > 1000
            if ?RandomNum > 500 ' limit of 8 stacks
              y := y - dy
'              ClearGrid(1)
                     
     x := x + dx
     y := y + dy
     if x < 0
       dx := 1
        x := 0
     if x > 15
       dx := -1
        x := 15
     if y < 0
       dy := 1
        y := 0
     if y > 15
       dy := -1
       y := 15

     ' compute offsets
     if x > 7
       xo := 64
       qx := x - 8
     else
       xo := 0
       qx := x
     if y > 7
       yo := 128
       qy := y - 8
     else
       yo := 0
       qy := y

     ' compute in quad x and y
     nextGrid[pxo + pyo + (8*qpy) + qpx] := 0
     pxo := xo
     pyo := yo
     px := x
     py := y
     qpx := qx
     qpy := qy
     nextGrid[xo + yo + (8*qy) + qx] := 1
     
     outa[p] := 0
     waitcnt(delay + cnt)     
             

           
PUB SetPrevCell(x,y,q)
  prevGrid[(q*64) + (y*8) + x] := 1
PUB ResetPrevCell(x,y,q)
  prevGrid[(q*64) + (y*8) + x] := 0
PUB SetNextCell(x,y,q)
  nextGrid[(q*64) + (y*8) + x] := 1
PUB ResetNextCell(x,y,q)
  nextGrid[(q*64) + (y*8) + x] := 0

PUB ReverseGrid(v) | x
  repeat x from 0 to 255
    nextGrid[x] := 1 - nextGrid[x]
    prevGrid[x] := 1 - prevGrid[x]
              
PUB ClearGrid(v) | x
  repeat x from 0 to 255
    nextGrid[x] := v
    prevGrid[x] := v

PUB CA_MAIN(Type) | caCurrentFrame
  caCurrentFrame := 0
  repeat
     CA_Recompute(0)
     CA_Transfer(0)
     if caCurrentFrame > 30
      caCurrentFrame := 0
      CA_LoadTestPatternLayer(1)      














PUB CA_Recompute(Type) | x1,y1,caX1,caY1,caSum
  ' Calculate center grid
  repeat x1 from 1 to 14
   repeat y1 from 1 to 14
     caSum := 0
     repeat caX1 from x1-1 to x1+1
      repeat caY1 from y1-1 to y1+1
       'caValue := GetMemCellLayer(x1,y1,0)
       caSum := caSum + getMemCellLayer(caX1,caY1,0)
       ' lookup
     CA_Transition(x1, y1, caSum)

PUB CA_Transition(x1a, y1a, sum) : newValue
     case sum
      0..1:
       SetNextMemCellLayer0(x1a,y1a,0)
      '2: ' keep alive
       'SetNextMemCellLayer0(x1a,y1a,caValue)      
      3: ' create cell
       SetNextMemCellLayer0(x1a,y1a,1)      
      4..9:
       SetNextMemCellLayer0(x1a,y1a,0)    

PUB SetMemCellLayer0(x, y, l0)  
  case y
   0..7:
    prevGrid[ ((7 -(y - 0)) * 16) + x] := l0
   8..15:
    prevGrid[(1 * _pageSize) + ((7 -(y - 8)) * 16) + x] := l0
   16..23:
    prevGrid[(2 * _pageSize) + ((7 -(y - 16)) * 16) + x] := l0
   24..31:
    prevGrid[(3 * _pageSize) + ((7 -(y - 24)) * 16) + x] := l0
PUB SetNextMemCellLayer0(x, y, l0)  
  case y
   0..7:
    nextGrid[(0 * _pageSize) + ((7 -(y - 0)) * 16) + x] := l0
   8..15:
    nextGrid[(1 * _pageSize) + ((7 -(y - 8)) * 16) + x] := l0
   16..23:
    nextGrid[(2 * _pageSize) + ((7 -(y - 16)) * 16) + x] := l0
   24..31:
    nextGrid[(3 * _pageSize) + ((7 -(y - 24)) * 16) + x] := l0

PUB GetMemCellLayer(x, y, l): retColor
  case y
   0..7:
    case l
     0:
      retColor := prevGrid[((7 -(y - 0)) * 16) + x]
     1:
      retColor := prevGrid[((7 -(y - 0)) * 16) + x + 8]
   8..15:
    case l
     0:
      retColor := prevGrid[_pageSize + ((7 -(y - 8)) * 16) + x]
     1:
      retColor := prevGrid[_pageSize + ((7 -(y - 8)) * 16) + x + 8]
   16..23:
    case l
     0:
      retColor := prevGrid[(_pageSize << 1) + ((7 -(y - 16)) * 16) + x]
     1:
      retColor := prevGrid[(_pageSize << 1) + ((7 -(y - 16)) * 16) + x + 8]
   24..31:
    case l
     0:
      retColor := prevGrid[(3 * _pageSize) + ((7 -(y - 24)) * 16) + x]
     1:
      retColor := prevGrid[(3 * _pageSize) + ((7 -(y - 24)) * 16) + x + 8]
PUB GetNextMemCellLayer(x, y, l): retColor
  case y
   0..7:
    case l
     0:
      retColor := nextGrid[((7 -(y - 0)) * 16) + x]
     1:
      retColor := nextGrid[((7 -(y - 0)) * 16) + x + 8]
   8..15:
    case l
     0:
      retColor := nextGrid[_pageSize + ((7 -(y - 8)) * 16) + x]
     1:
      retColor := nextGrid[_pageSize + ((7 -(y - 8)) * 16) + x + 8]
   16..23:
    case l
     0:
      retColor := nextGrid[(_pageSize << 1) + ((7 -(y - 16)) * 16) + x]
     1:
      retColor := nextGrid[(_pageSize << 1) + ((7 -(y - 16)) * 16) + x + 8]
   24..31:
    case l
     0:
      retColor := nextGrid[(3 * _pageSize) + ((7 -(y - 24)) * 16) + x]
     1:
      retColor := nextGrid[(3 * _pageSize) + ((7 -(y - 24)) * 16) + x + 8]
 


PUB CA_Transfer(Type) | x1,y1
   repeat x1 from 0 to 7
    repeat y1 from 0 to 31
     SetMemCellLayer0(x1,y1,getNextMemCellLayer(x1,y1,0))
       
PUB CA_LoadTestPattern(xColor) | p1, x1,y1
  repeat p1 from 0 to 3
   repeat x1 from 2 to 5
    repeat y1 from 2 to 5
     if ?RandomNum < 5000
      OrMemCell(p1, x1, y1, 1)
     else
       NorMemCell(p1, x1, y1, 1)

PUB OrMemCell(p, x, y, c)
  case c
   1:
    prevGrid[(p * _pageSize) + (y * 16) + x] := 1
   2:
    prevGrid[(p * _pageSize) + (y * 16) + x + 8] := 1
' Nor a color
PUB NorMemCell(p, x, y, c)
  case c
   1:
    prevGrid[(p * _pageSize) + (y * 16) + x] := 0
   2:
    prevGrid[(p * _pageSize) + (y * 16) + x + 8] := 0

PUB CA_LoadTestPatternLayer(xColor) | x1,y1
   repeat x1 from 3 to 4
    repeat y1 from 1 to 30
     if ?RandomNum < 5000
      SetMemCellLayer0(x1, y1, 1)
     else
      SetMemCellLayer0(x1, y1, 0)
      
PUB CA_ClearMem(Type)
  bytefill(@prevMemGrid,0,_memCellsTotal) ' clear memory
  bytefill(@nextMemGrid,0,_memCellsTotal) ' clear memory  

PUB CA_Clear(Type)
  bytefill(@prevGrid,0,_gridCellsTotal) ' clear memory
  bytefill(@nextGrid,0,_gridCellsTotal) ' clear memory


DAT
  ControlWord
    byte 0,1,1,1,0,1,1,1

DAT
  ControlWordBits
    byte 00000000  ' 
    byte 00000001  ' SHL
    byte 00000010  ' SHR
    byte 00000011  ' ADD
    byte 00000100  ' LD
    byte 00000101  ' ST
    byte 00000110  '
    byte 00000111  '

DAT
  ExampleCA_PAC1
    byte 00000000 ' initialize     
    byte 00000000 '      
    byte 00000000 '     
    byte 00000000 '     
    byte 00000000 '     
    byte 00000000 '     
    byte 00000000 '     
    byte 00000000 '     
    byte 00000000 '     
    byte 00000000 '     
    byte 00000000 '     
    byte 00000000 '     
    byte 00000000 '     
    byte 00000000 '     
    byte 00000000 '     
    byte 00000000 '     
    byte 00000000 '     
    byte 00000000 '     
    byte 00000000 '     


  
                                              