
{-----------------------------------------------------------------------

This unit declares a unit containing procedures etc. that are normally
(i.e., in Turbo Pascal) provided by the units 'graph' and 'crt'. The actual
implementation of most of these is not contained in this unit, but in
puff_c.c, which is written in C, and uses the X11 window system (hence
this unit's name).

The implementations here and in puff_c.c are not complete: they are limited
to what is needed for compiling and using the PUFF software. As such, they
may or may not be useful for compiling other graphical Turbo Pascal
applications under Linux, depending on the requirements of such applications.

This unit and puff_c.c also contain a few other routines that were used in
the Linux port of PUFF but do not exist in Turbo Pascal: these were needed
because some things must (for efficiency or other reasons) be implemented
differently on Linux than on MS-DOS.

Parts (support for readln and writeln) are copyright (c) 1999-2000 by Michael
Van Canneyt and Peter Vreman, members of the Free Pascal development team.
Rest is copyright (c) 2000, by Pieter-Tjerk de Boer, pa3fwm@amsat.org.
This software is distributed under the conditions of version 3 of the GNU
General Public License from the Free Software Foundation.

-----------------------------------------------------------------------}

{$T-}    {No output sections}

Unit xgraph;


Interface


Type 
  ViewPortType = Record
    X1,Y1,X2,Y2 : Integer;
    Clip : Boolean
  End;


Procedure InitGraph (Var GraphDriver,GraphModus : integer; Const PathToDriver : String);
cdecl;
external;
Procedure CloseGraph ;
cdecl;
external;

Procedure SetColor (Color : Longint);
cdecl;
external;
Procedure SetFillStyle (Pattern,Color : Longint);
cdecl;
external;
Procedure SetLineStyle (LineStyle,Pattern,Width : Longint);
cdecl;
external;

Procedure Line (X1,Y1,X2,Y2 : Longint);
cdecl;
external;
Procedure PutPixel (X,Y : Longint; Color : Longint);
cdecl;
external;
Procedure Bar (X1,Y1,X2,Y2 : Longint);
cdecl;
external;
Procedure Rectangle (X1,Y1,X2,Y2 : Longint);
cdecl;
external;
Procedure Arc (X,Y : Longint; start,stop, radius : Longint);
cdecl;
external;
Procedure FillEllipse (X,Y : Longint; Xradius,YRadius: Longint);
cdecl;
external;
Procedure Circle (X,Y : Longint; Radius : Longint);
cdecl;
external;
Procedure FloodFill (X,Y : Longint; BorderColor : Longint);
cdecl;
external;

Procedure SetTextJustify (Horizontal,Vertical : Longint);
cdecl;
external;
Procedure OutTextXY (X,Y : Integer; Const TextString : String);

Procedure SetViewPort (X1,Y1,X2,Y2 : Longint; Clip : Boolean);
cdecl;
external;

Function GetBkColor : Longint;
cdecl;
external;
Procedure SetBkColor (Color : Longint);
cdecl;
external;

Function GraphErrorMsg (ErrorCode : Longint) : String;
cdecl;
external;
Function GraphResult : Longint;
cdecl;
external;


Procedure GetBox(bn, x, y, width, height: Longint);
cdecl;
external;
Procedure PutBox(bn, x, y, width, height: Longint);
cdecl;
external;


Var 
  ScreenHeight: integer;
  external name 'ScreenHeight';
  ScreenWidth: integer;
  external name 'ScreenWidth';


Const 
  SOLIDFILL = 0;
  lefttext = 0;
  centertext = 1;
  righttext = 2;
  userbitln = 4;
  normwidth = 1;
  solidln = 0;
  VGA = 0;
  EGA = 1;
  GROK = 0;





Const 
  Black = 0;
  Blue = 1;
  Green = 2;
  Cyan = 3;
  Red = 4;
  Magenta = 5;
  Brown = 6;
  LightGray = 7;
  DarkGray = 8;
  LightBlue = 9;
  LightGreen = 10;
  LightCyan = 11;
  LightRed = 12;
  LightMagenta = 13;
  Yellow = 14;
  White = 15;
  co80 = 3;
  WindMax: Word = $184f;
  LastMode: Word = 3;
  DirectVideo: Boolean = False;




Procedure Window (X1, Y1, X2, Y2: Longint);
cdecl;
external name 'crtWindow';
Procedure GotoXY (X: Longint; Y: Longint);
cdecl;
external;
Procedure Sound (hz : Longint);
cdecl;
external;
Procedure Delay (DTime: Longint);
cdecl;
external;
Procedure NoSound ;
cdecl;
external;
Function KeyPressed : Boolean;
cdecl;
external;
Function ReadKey : Char;
cdecl;
external;
Procedure TextMode(Mode: Longint);
cdecl;
external;
Procedure TextColor (CL: Longint);
cdecl;
external;
Procedure TextBackground (CL: Longint);
cdecl;
external;
Procedure ClrScr ;
cdecl;
external;


Function GetTimerTicks : Integer;
cdecl;
external;




Implementation


Uses dos,linux;




Procedure C_OutTextXY (X,Y : Longint; Var TextString : String);
cdecl;
external;

Procedure OutTextXY (X,Y : Integer; Const TextString : String);

Var s: string;
Begin
  s := TextString;
  C_OutTextXY(X,Y,s);
End;




{ write(ln) and readln support code based on rtl/linux/crt.pp from the fpc source tree }

Procedure DoWrite(Var s: String);
cdecl;
external;
Procedure DoWriteEnd;
cdecl;
external;


Function xgraphWrite(Var F: TextRec): Integer;

Var 
  Temp : String;
  idx,i : Longint;
Begin
  idx := 0;
  While (F.BufPos>0) Do
    Begin
      i := F.BufPos;
      If i>255 Then
        i := 255;
      Move(F.BufPTR^[idx],Temp[1],i);
      SetLength(Temp,i);
      DoWrite(Temp);
      dec(F.BufPos,i);
      inc(idx,i);
    End;

  DoWriteEnd;
  xgraphWrite := 0;
End;



Function xgraphRead(Var F: TextRec): Integer;
{
  Read from CRT associated file.
}

Var 
  c : char;
  i : longint;
Begin
  F.BufPos := 0;
  i := 0;
  Repeat
    c := readkey;
    Case c Of 
          { ignore special keys }
      #0:
          c := readkey;
          { Backspace }
      #8:
          If i > 0 Then
            Begin
              write(#8#32#8);
              dec(i);
            End;
          { Unhandled extended key }
      #27:;
          { CR }
      #13:
           Begin
             F.BufPtr^[i] := #10;
             write(#10);
             inc(i);
           End;
      Else
        Begin
          write(c);
          F.BufPtr^[i] := c;
          inc(i);
        End;
    End;
  Until (c In [#10,#13]) Or (i >= F.BufSize);
  F.BufEnd := i;
  xgraphRead := 0;
  exit;
End;


Function xgraphReturn(Var F:TextRec): Integer;
Begin
  xgraphReturn := 0;
End;




Function xgraphOpen(Var F: TextRec): Integer;
Begin
  If F.Mode=fmOutput Then
    Begin
      TextRec(F).InOutFunc := @xgraphWrite;
      TextRec(F).FlushFunc := @xgraphWrite;
    End;
  If F.Mode=fmInput Then
    Begin
      TextRec(F).InOutFunc := @xgraphRead;
      TextRec(F).FlushFunc := @xgraphReturn;
    End;
  xgraphOpen := 0;
End;



Procedure init_x;
cdecl;
external;


Initialization

Assign(Output,'');
TextRec(Output).OpenFunc := @xgraphOpen;
Rewrite(Output);
TextRec(Output).Handle := StdOutputHandle;
Assign(Input,'');
TextRec(Input).OpenFunc := @xgraphOpen;
Reset(Input);
TextRec(Input).Handle := StdInputHandle;

init_x();
{
  ScreenHeight:=500;
  ScreenWidth:=1000;
}

End.
