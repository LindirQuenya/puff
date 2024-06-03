{$R-}    {Range checking}
{$S-}    {Stack checking}
{$B-}    {Boolean complete evaluation or short circuit}
{$I+}    {I/O checking on}


Unit pfart;


(*******************************************************************

        Unit PFART;

        This code is now licenced under GPLv3.

        Copyright (C) 1991, S.W. Wedge, R.C. Compton, D.B. Rutledge.
        Copyright (C) 1997,1998, A. Gerstlauer

        Modifications for Linux compilation 2000-2007 Pieter-Tjerk de Boer.

	Code cleanup for Linux only build 2009 Leland C. Scott.

	Original code released under GPLv3, 2010, Dave Rutledge.


        Contains code for creating dot-matrix, LaserJet,
        and HPGL artwork.

********************************************************************)

Interface

Uses 

xgraph,
Dos,          {Unit found in Free Pascal RTL's}
Printer,
pfun1,     {Add other puff units}
pfun2;


{* Internals: 
  procedure get_widthxyO(tnet : net; var widthx,widthy : double);
  procedure init_chamferO(tnet : net; widthx,widthy : double);
  procedure init_lineO(tnet : net);
  procedure fill_shape(tnet : net; corner : boolean);
  procedure fill_port(tNt : net);
  procedure net_loop;
  function printer_offline : boolean;
  procedure reset_printer;
  *}

Procedure Make_HPGL_File;
Procedure Printer_Artwork;

Implementation

{**** Artwork variables ****}

Var 
  bita                  : array[0..1200] Of byte;    {Bit map for artwork}
  dot_step,ydot,mb,
  rowl,xdot_max         : integer;


Procedure get_widthxyO(tnet : net; Var widthx,widthy : double);

{*
        Given node tnet, find out the width in the 
        x and y direction of connecting parts for chamfer.
*}

Var 
  direction : integer;
  width     : double;
  tcon      : conn;

Begin
  widthx := 0;
  widthy := 0;
  tnet^.nodet := 0;
  tcon := Nil;
  Repeat
    If tcon=Nil Then tcon := tnet^.con_start
    Else tcon := tcon^.next_con;
    direction := tcon^.dir;
    If tcon^.mate=Nil Then width := widthZ0
    Else width := tcon^.mate^.net^.com^.width;
    If width <> 0 Then
      Begin
        tnet^.nodet := tnet^.nodet+direction;
        Case direction Of 
          1,8 : widthx := width;
          2,4 : widthy := width;
        End; {case}
      End;
  Until tcon^.next_con=Nil;
End; {get_widthxyO}


Procedure init_chamferO(tnet : net; widthx,widthy : double);

{*
        Calculate corners of white triangle for chamfer.
        Returns different values of nx2,ny2 than init_line. 
        Right-triangle coordinates returned are:
          (nx1,ny1) (90 degree corner), (nx1,yend) and (xend,ny1)
          where xend=nx1+nx2, yend=ny1+ny2
          xend and yend are computed and used in fill_shape.

*}

Var 
  hwidthx,hwidthy      : integer;


Begin
  With tnet^ Do
    Begin
      If (widthx*widthy=0) Or (number_of_con<>2) Then chamfer := false
      Else chamfer := true;
      hwidthx := Round(widthx*0.5/psx);
      hwidthy := Round(widthy*0.5/psy);
      If chamfer Then Case nodet Of 
                        10:
                            Begin
                              nx1 := Round(xr/psx) - hwidthx;
                              ny1 := Round(yr/psy) - hwidthy;
                              nx2 := Round((miter_fraction*2.0)*widthx/psx);
                              ny2 := Round((miter_fraction*2.0)*widthy/psy);
                            End;
                        12:
                            Begin
                              nx1 := Round(xr/psx) + hwidthx;
                              ny1 := Round(yr/psy) - hwidthy;
                              nx2 := -Round((miter_fraction*2.0)*widthx/psx);
                              ny2 := Round((miter_fraction*2.0)*widthy/psy);
                            End;
                        5:
                           Begin
                             nx1 := Round(xr/psx) + hwidthx;
                             ny1 := Round(yr/psy) + hwidthy;
                             nx2 := -Round((miter_fraction*2.0)*widthx/psx);
                             ny2 := -Round((miter_fraction*2.0)*widthy/psy);
                           End;
                        3:
                           Begin
                             nx1 := Round(xr/psx) - hwidthx;
                             ny1 := Round(yr/psy) + hwidthy;
                             nx2 := Round((miter_fraction*2.0)*widthx/psx);
                             ny2 := -Round((miter_fraction*2.0)*widthy/psy);
                           End;
                        Else
                          chamfer := false;
        End; {case}
    End; {with tnet}
End; {init_chamferO}


Procedure init_lineO(tnet : net);
{*
        Calculate dot positons of line tnet for artwork.
*}

Var 
  xt : integer;

Begin
  lengthxy(tnet);
  With tnet^ Do
    Begin
      nx1 := Round((xr-yii*lengthxm/2.0)/psx);
      ny1 := Round((yr-xii*lengthym/2.0)/psy);
      nx2 := nx1+Round(lengthxm*(xii+yii)/psx);
      ny2 := ny1+Round(lengthym*(yii+xii)/psy);
      If nx1 > nx2 Then
        Begin
          xt := nx1;
          nx1 := nx2;
          nx2 := xt;
        End;
      If ny1 > ny2 Then
        Begin
          xt := ny1;
          ny1 := ny2;
          ny2 := xt;
        End;
    End; {with tnet}
End; {init_lineO}


Procedure fill_shape(tnet : net; corner : boolean);

{*
        Updated to function for LaserJet and Dot matrix data.
        Fills array bita[1..xdot_max] that will be sent to printer.
        For Dot matrix, bita[] is up to 960 dot columns (8").
        For LaserJet, bita[] is 8 rows of up to 150 dot rows
                connected end to end, causing the maximum
                size of bita to be 1200 bytes.
        Toggle between dot matrix and Laserjet routines is
                accomplished by examining boolean variable Laser_Art.
        Called by Net_Loop.
*}

Var 
  yval,xbeg,xend,ybeg,yend,
  ix,i,left,right,
  in_right,in_left,
  right_byte,left_byte          : integer;
  dot_skip                      : shortint;
  slope                         : double;
  temp                          : byte;

        {**************************************************}
Procedure white_out(i,ix : integer);
        {* 
                Used to white out a single pixel for chamfers.
        *}

Var 
  mask : byte;

Begin
  If Laser_Art Then
    Begin {if LaserJet}
      left := ix Div 8;
      in_right := ix Mod 8;
      mask := 128 shr in_right;
      bita[left+150*i] := bita[left+150*i] And Not(mask);
    End
  Else {if Dot matrix}
    bita[ix] := bita[ix] And Not(temp);
End;

        {**************************************************}
Procedure black_out(i : integer);

{*   
                Use for filling array for the Laserjet Printer. 
                Fills pixels (bita[] bytes) from nx1 to nx2.
        *}

Var 
  ix: integer;

Begin
  With tnet^ Do
    Begin
      left := nx1 Div 8;
      in_right := nx1 Mod 8;
      right := nx2 Div 8;
      in_left := 7 - nx2 Mod 8;
      left_byte := 255 shr in_right; { use shr and shl to form }
      right_byte := (255 shl in_left) And 255; { bytes not full of pixels }
      If (left = right) Then
        bita[left+150*i] := bita[left+150*i] Or (left_byte And right_byte)
      Else
        Begin   {for right > left fill partial pixel bytes}
          bita[left+150*i] := bita[left+150*i] Or left_byte;
          bita[right+150*i] := bita[right+150*i] Or right_byte;
        End;
      If (right > left + 1) Then
        For ix := left+1 To right-1 Do
          bita[ix+150*i] := 255;
    End; {with}
End;
        {***************************************************}


Begin
  If Laser_Art Then dot_skip := 1  {Laserjet has true 150 dpi}
  Else dot_skip := 2; {Skip dot matrix dots to produce 2*72 dpi}
  With tnet^ Do
    If corner Then
      Begin {chamfer corner}
        ybeg := ny1;
        If ny2 < 0 Then ybeg := ybeg+ny2;
        yend := ybeg+abs(ny2);
        If yend +10 > ydot Then remain := true;
        xbeg := nx1;
        If nx2 < 0 Then xbeg := xbeg+nx2;
        xend := xbeg+abs(nx2);
        If xbeg < 0 Then xbeg := 0;
        If xbeg > xdot_max Then xbeg := xdot_max;
        If xend < 0 Then xend := 0;
        If xend > xdot_max Then xend := xdot_max;
        If xbeg=xend Then slope := 1
        Else slope := (yend-ybeg)/(xend-xbeg);
        temp := 128;
        For i:=0 To 7 Do
          Begin
            yval := ydot+dot_skip*i;
            If i <> 0 Then temp := temp shr 1;
            If (ybeg <= yval) And (yval <= yend) Then
              Begin
                If xend > rowl Then rowl := xend;
                For ix:=xbeg To xend Do
                  Begin
                    Case nodet Of 
                      10: If yval < (yend-Round((ix-xbeg)*slope)) Then
                            white_out(i,ix);
                      12: If yval < (ybeg+Round((ix-xbeg)*slope)) Then
                            white_out(i,ix);
                      5: If yval > (yend-Round((ix-xbeg)*slope)) Then
                           white_out(i,ix);
                      3: If yval > (ybeg+Round((ix-xbeg)*slope)) Then
                           white_out(i,ix);
                    End; {case}
                  End; {for ix}
              End; { if ybeg<= yval }
          End; {for i=0 to 7}
      End
    Else
      Begin  {if not corner fill in shape}
        If ny2+10  > ydot Then remain := true;
        temp := 0;
        For i:=0 To 7 Do
          Begin
            temp := temp shl 1;
            If (ny1 <= ydot+dot_skip*i) And (ydot+dot_skip*i <= ny2) Then
              Begin
                temp := (temp + 1);
                If nx2 > rowl Then rowl := nx2;
              End; {if y1}
          End; {for i}
        If nx1 < 0 Then nx1 := 0;   {* Clip corners *}
        If nx1 > xdot_max Then nx1 := xdot_max;
        If nx2 < 0 Then nx2 := 0;
        If nx2 > xdot_max Then nx2 := xdot_max;
        If temp>0 Then
          If Laser_Art Then
            Begin
              For i:=7 Downto 0 Do
                Begin
                  If (temp And 1) = 1 Then black_out(i);
                  temp := temp shr 1;
                End; {for i}
            End
        Else
          Begin
            For ix:=nx1 To nx2 Do
              bita[ix] := bita[ix] Or temp;
          End; {if temp and/or Laser_Art}
      End; {if not corner}
End; {fill_shape}


Procedure fill_port(tNt : net);
{*
        Perform artwork connections to external ports.
*}

Var 
  tptyr,tptxr           : double;
  tport,tpt             : net;
  tcon                  : conn;
  nodet1,x1,y1,x2,y2    : integer;

Begin
  tcon := Nil;
  Repeat
    If tcon=Nil Then tcon := tNt^.con_start
    Else tcon := tcon^.next_con;
    If ext_port(tcon) Then
      Begin
        tport := portnet[tcon^.port_type];
        y1 := Round(tNt^.yr/psy);
        y2 := Round(tport^.yr/psy);
        If ydot=0 Then
          Begin
            tpt := tport;
            x1 := Round(tNt^.xr/psx);
            x2 := Round(tpt^.xr/psx);
            tptxr := tpt^.xr;
            tptyr := tpt^.yr;
            New_n(tpt^.other_net);
            tpt := tpt^.other_net;
            tpt^.ny1 := y2-pwidthyZ02;
            tpt^.ny2 := y2+pwidthyZ02;
            If x1 < x2 Then
              Begin
                tpt^.nx1 := x1;
                tpt^.nx2 := x2
              End
            Else
              Begin
                tpt^.nx1 := x2;
                tpt^.nx2 := x1
              End;
            New_n(tpt^.other_net);
            tpt := tpt^.other_net;
            tpt^.nx1 := x1-pwidthxZ02;
            tpt^.nx2 := x1+pwidthxZ02;
            If y1 < y2 Then
              Begin
                tpt^.ny1 := y1;
                tpt^.ny2 := y2
              End
            Else
              Begin
                tpt^.ny1 := y2;
                tpt^.ny2 := y1
              End;
            If tNt^.yr > tptyr Then
              Begin
                If tNt^.xr > tptxr Then nodet1 := 12
                Else nodet1 := 10;
              End
            Else
              Begin
                If tNt^.xr > tptxr Then nodet1 := 5
                Else nodet1 := 3;
              End;
            New_n(tpt^.other_net);
            tpt := tpt^.other_net; {chamfers}
            tpt^.xr := tNt^.xr;
            tpt^.yr := tptyr;
            tpt^.nodet := nodet1;
            tpt^.number_of_con := 2;
            init_chamferO(tpt,widthZ0,widthZ0);
          End;
        tport := tport^.other_net;
        fill_shape(tport,false);  {horiz line}
        If abs(y2-y1) > pwidthyZ02 Then
          Begin
            tport := tport^.other_net;
            fill_shape(tport,false);{vert. line}
            tport := tport^.other_net;
            fill_shape(tport,true);  {do chamfer}
          End;
      End;{if tcon}
  Until tcon^.next_con=Nil;
End; {fill_port}


Procedure net_loop;
{*
        Loop over parts for artwork mask.
*}

Var 
  tnet : net;
  widthx,widthy : double;

Begin
  remain := false;
  ydot := ydot+dot_step;
  tnet := Nil ;
  Repeat
    If tnet=Nil Then tnet := net_start
    Else tnet := tnet^.next_net;
    If ydot=0 Then
      Begin
        If tnet^.node Then
          Begin
            get_widthxyO(tnet,widthx,widthy);
            init_chamferO(tnet,widthx,widthy)
          End
        Else
          Begin
            dirn := tnet^.con_start^.dir;
            init_lineO(tnet);
            If tnet^.com^.typ='c' Then init_lineO(tnet^.other_net);
          End; {if tnet^.node}
      End; {if ydot}
    If Not(tnet^.node) Then
      Begin
        If tnet^.com^.typ In ['q','t','c'] Then fill_shape(tnet,false);
        If tnet^.com^.typ In ['c'] Then fill_shape(tnet^.other_net,false);
      End;
  Until tnet^.next_net=Nil;
  tnet := Nil ;
  Repeat
    If tnet=Nil Then tnet := net_start
    Else tnet := tnet^.next_net;
    If tnet^.node Then
      Begin
        If tnet^.ports_connected > 0 Then fill_port(tnet);
        If tnet^.chamfer Then fill_shape(tnet,true);  {fill chamfer}
      End;
  Until tnet^.next_net=Nil;
End; {* net_loop *}


Procedure Make_HPGL_File;

{*
        Used to generate HPGL files.
        Called in Plot via Ctrl-a when enabled in .puf file 

        Code here is tricky! X and Y coordinates 
        must be swapped for compatibility between printer
        coordinate systems and the plotter coordinate system. 
        Units in millimeters must be changed to plotter units
        with conversion factor of 40 plu/mm.
*}

Var 
  tport,tpt,tnet                : net;
  tcon                          : conn;
  nodet1,drive,plu_size,
  xoffset,yoffset,
  lx,ly,x2,y2,
  max_x_plu,max_y_plu           : integer;
  fname,pap_size                : file_string;
  widthx,widthy,sf              : double;
  pap_char                      : char;

        {*****************************************************}
Procedure HPGL_chamfer(tnet:net; widthx,widthy,sf:double);

{*
                Calculate corners of white triangle for chamfer.
                Parameter units used are millimeters.   
        *}

Var 
  rx1,ry1,rx2,ry2 : double;

Begin
  With tnet^ Do
    Begin
      If (widthx*widthy=0) Or (number_of_con<>2)
        Then chamfer := false
      Else chamfer := true;
      If chamfer Then
        Case nodet Of 
          10:
              Begin
                rx1 := (xr-widthx/2.0);
                rx2 := +(miter_fraction*2.0)*widthx;
                ry1 := (yr-widthy/2.0);
                ry2 := +(miter_fraction*2.0)*widthy;
              End;
          12:
              Begin
                rx1 := (xr+widthx/2.0);
                rx2 := -(miter_fraction*2.0)*widthx;
                ry1 := (yr-widthy/2.0);
                ry2 := +(miter_fraction*2.0)*widthy;
              End;
          5:
             Begin
               rx1 := (xr+widthx/2.0);
               rx2 := -(miter_fraction*2.0)*widthx;
               ry1 := (yr+widthy/2.0);
               ry2 := -(miter_fraction*2.0)*widthy;
             End;
          3:
             Begin
               rx1 := (xr-widthx/2.0);
               rx2 := +(miter_fraction*2.0)*widthx;
               ry1 := (yr+widthy/2.0);
               ry2 := -(miter_fraction*2.0)*widthy;
             End;
          Else
            chamfer := false;
        End; {if chamfer, case}
      If chamfer Then
        WriteLn(net_file,'PUPA',xoffset+Round(sf*ry1),
        ',',yoffset+Round(sf*(rx1+rx2)),
        ';PDPA',xoffset+Round(sf*(ry1+ry2)),
        ',',yoffset+Round(sf*(rx1)),';PU;');
    End; {with tnet}
End; {HPGL_chamfer}
        {********************************************************}

Begin   {* Make_HPGL_File *}
  If net_start=Nil Then
    Begin
      message[1] := 'No circuit';
      message[2] := 'to do HPGL file';
      write_message;
    End
  Else
    Begin
      fname := input_string('HP-GL file name:', '     (*.HPG)');
      If fname='' Then exit;
      If Pos(':',fname)=2 Then drive := ord(fname[1])-ord('a')+1
      Else drive := -1;
      If enough_space(drive) Then
        Begin
          If pos('.',fname)=0 Then fname := fname+'.HPG';
          Assign(net_file,fname);
      {$I-}
          Rewrite(net_file); {$I+}
          If IOresult=0 Then
            Begin
              sf := 40*reduction;  {red* 40 plotter units per mm (plu/mm)}
              plu_size := Round(bmax*sf); {board size in plu's}
              pap_size := input_string('Select Paper Size',' A,B,A4,A3: (A)');
              If pap_size='' Then pap_char := 'A'
              Else pap_char := pap_size[1];
              Case pap_char Of  {determine maximum plotter unit}
                'a','A'   :
                            Begin
                              If pap_size[2]='3' Then
                                Begin   {A3 size}
                                  max_x_plu := 16158;
                                  max_y_plu := 11040;
                                End
                              Else If pap_size[2]='4' Then
                                     Begin  {A4 size}
                                       max_x_plu := 11040;
                                       max_y_plu := 7721;
                                     End
                              Else
                                Begin   {A size}
                                  max_x_plu := 10365;
                                  max_y_plu := 7962;
                                End;
                            End;
                'b','B'   :
                            Begin  {B size}
                              max_x_plu := 16640;
                              max_y_plu := 10365;
                            End;
                Else
                  Begin {default to A}
                    max_x_plu := 10365;
                    max_y_plu := 7962;
                  End;
              End; {case}
              If (plu_size > max_x_plu)
                 Or (plu_size > max_y_plu) Then
                Begin
                  message[1] := 'Reduction ratio';
                  message[2] := 'too large';
                  message[3] := 'Edit .puf file';
                  write_message;
                  Close(net_file);
                End
              Else
                Begin
                  xoffset := (max_x_plu - plu_size) Div 2;  {use to page center}
                  yoffset := (max_y_plu - plu_size) Div 2;
                  tnet := Nil;
                {* Initialize and select pen 1 *}
                {* Place paper size selection in file *}
                  Write(net_file,'IN;SP1;');
                  If max_x_plu > 16000 Then WriteLn(net_file,'PS0;')
                  Else WriteLn(net_file,'PS4;');
                  Repeat
                    If tnet=Nil Then tnet := net_start
                    Else tnet := tnet^.next_net;
                    If tnet^.node Then
                      Begin
                        get_widthxyO(tnet,widthx,widthy);
                        HPGL_chamfer(tnet,widthx,widthy,sf);
                        With tnet^ Do
                          If ports_connected > 0 Then
                            Begin
                              tcon := Nil;
                              Repeat
                                If tcon = Nil Then tcon := tnet^.con_start
                                Else tcon := tcon^.next_con;
                                If ext_port(tcon) Then
                                  Begin
                        {* Draw horizontal connection to port *}
                                    tport := portnet[tcon^.port_type];
                                    lx := Round(sf*(tport^.yr - widthZ0/2.0)); {y-start}
                                    ly := Round(sf*(tport^.xr)); {x-start}
                          {goto corner,  X and Y swapped}
                                    WriteLn(net_file,'PUPA',xoffset+lx,',',
                                            yoffset+ly,';PD;');
                                    x2 := Round(sf*widthZ0);         {delta-y}
                                    y2 := Round(sf*(xr-tport^.xr));  {delta-x}
                          {Edge rectangle relative}
                                    WriteLn(net_file,'ER',x2,',',y2,';PU;');
                                    If abs(tnet^.yr - tport^.yr) > widthz0/2.0 Then
                                      Begin
                          {* Draw vertical connection to port *}
                                        ly := Round(sf*(xr - widthZ0/2.0)); {x-start}
                                        lx := Round(sf*(tport^.yr));  {y-start}
                            {goto corner,  X and Y swapped}
                                        WriteLn(net_file,'PUPA',xoffset+lx,',',
                                                yoffset+ly,';PD;');
                                        y2 := Round(sf*widthZ0);        {delta-x}
                                        x2 := Round(sf*(yr-tport^.yr)); {delta-y}
                            {Edge rectangle relative}
                                        WriteLn(net_file,'ER',x2,',',y2,';PU;');
                                        If yr > tport^.yr Then
                                          Begin
                                            If xr > tport^.xr Then nodet1 := 12
                                            Else nodet1 := 10;
                                          End
                                        Else
                                          Begin
                                            If xr > tport^.xr Then nodet1 := 5
                                            Else nodet1 := 3;
                                          End;
                                        New_n(tpt);
                                        tpt^.xr := xr;
                                        tpt^.yr := tport^.yr;
                                        tpt^.nodet := nodet1;
                                        tpt^.number_of_con := 2;
                                        HPGL_chamfer(tpt,widthZ0,widthZ0,sf);
                                      End; {if abs(tnet..}
                                  End; {if ext_port}
                              Until tcon^.next_con=Nil;
                            End; {with tnet^ do, if tnet^.ports_connected }
                      End {if tnet^.node}
                    Else If (tnet^.com^.typ In ['q','t','c']) Then
                           Begin
                 {* Draw tlines, qlines, and clines *}
                             dirn := tnet^.con_start^.dir;
                             lengthxy(tnet);
                             With tnet^ Do
                               Begin
                                 lx := Round(sf*(yr - abs(xii)*lengthym/2.0));
                                 ly := Round(sf*(xr - abs(yii)*lengthxm/2.0));
                                 If yii=0 Then x2 := Round(sf*lengthym)
                                 Else x2 := Round(sf*yii*lengthym);
                                 If xii=0 Then y2 := Round(sf*lengthxm)
                                 Else y2 := Round(sf*xii*lengthxm);
                                 WriteLn(net_file,'PUPA',xoffset+lx,
                                         ',',yoffset+ly,';PD;');
                   {* Edge rectangle relative *}
                                 WriteLn(net_file,'ER',x2,',',y2,';PU;');
                               End; {with tnet}
                             If tnet^.com^.typ='c' Then
                               With tnet^.other_net^ Do
                                 Begin
                                   lx := Round(sf*(yr - abs(xii)*lengthym/2.0));
                                   ly := Round(sf*(xr - abs(yii)*lengthxm/2.0));
                                   WriteLn(net_file,'PUPA',xoffset+lx,',',
                                           yoffset+ly,';PD;');
                          {* Edge rectangle relative *}
                                   WriteLn(net_file,'ER',x2,',',y2,';PU;');
                                 End; {if tnet^ = c, with tnet}
                           End; {if not tnet^.node};
                  Until tnet^.next_net=Nil;
                {* Present paper and put pen away *}
                  WriteLn(net_file,'IP;PA0,',max_y_plu,';SP0;');
                  Close(net_file);
                  message[1] := 'HP-GL data';
                  message[2] := 'written to file';
                  message[3] := fname;
                  write_message;
                End;  {if reduction too small}
            End; {if IOResult=0}
        End; {if enoughspace}
    End; {if not net_start= nil}
End; {*Make_HPGL_File*}


Procedure Printer_Artwork;
{*
        Revised Procedure for directing artwork to dot-matrix
        or LaserJet printers.

*}

Label 
  exit_artwork;

Var 
  ix            : integer;
  lpt_label     : string;
  lst           : text;   { local printer file; hides the global variable of the same name }

        {***************************************************}
Function top_labels : boolean;
        {*
                Prompt user for labels to on the top of artwork mask.
        *}
Begin
  top_labels := false;
  top_labels := true;
  name := input_string(lpt_label,' Enter label #1');
  network_name := input_string(lpt_label,' Enter label #2');
End; {top_labels}
        {***************************************************}
Procedure Matrix_labels;
        {*
                Print labels on the top of artwork mask.
        *}
Begin
  write(lst,#27'E',#27'G'); {switch on  emphasised, double strike}
  writeln(lst,name:26    + length(name) div 2);
  writeln(lst,network_name:26 + length(network_name) div 2);
  write(lst,#27'F',#27'H'); {switch off emphasised, double strike}
  p_labels := false;
End; {print_labelsO}
        {***************************************************}
Procedure Laser_labels;

{*
                Initialize laser printer and put labels 
                on the top of artwork mask.
        *}

Var 
  xpos, ypos    : integer;

Begin
  write(lst,#27,'E'); {Reset Printer}
  write(lst,#27,'&l0O',#27,'&l2A',#27,'(0U',#27,
        '(s0p10h12v0s3b3T');

{Put in landscape mode, 8 1/2 x 11 
                page size, ASCII symbol set, fixed spacing,
                10cpi, 12pt, upright, courier bold font}
  xpos := 1200 - 30 * length(name) Div 2;
  ypos := 1450-xdot_max;
  write(lst,#27,'*p',xpos,'x',ypos,'Y'); {position cursor for text}
  write(lst,name);
  xpos := 1200 - 30 * length(network_name) Div 2;
  ypos := 1500 - xdot_max; {move down 70 dots}
  write(lst,#27,'*p',xpos,'x',ypos,'Y'); {position cursor for text}
  write(lst,network_name);
  write(lst,#13); {add carriage return}
  write(lst,#27,'(s0B'); {turn off bold font}
  xpos := 1200-xdot_max;
  ypos := 1600-xdot_max;
  write(lst,#27,'*p',xpos,'x',ypos,'Y'); {center artwork}
  write(lst,#27,'*t150R'); {Put in raster graphics 150 dpi mode}
  write(lst,#27,'*r1A'); {start graphics at current cursor position }
  p_labels := false;
End; {Laser_labels}
        {***************************************************}
Procedure Send_Matrix_Data;
        {*
        *}

Var 
  ix    : integer;

Begin
  If Not(p_labels) Then
    Begin
      If rowl > xdot_max Then rowl := xdot_max;
      write(lst,#27'L', chr((rowl+1) mod 256), chr((rowl+1) div 256));

{* Put printer in dual-density bit-image
                   graphics mode (half-speed) and specify
                   total number of bit image bytes
                   to be n=n1+(n2*256)   *}
      For ix := 0 To rowl Do
        write(lst,chr(bita[ix]));
                {* Write row of dot-columns *}
      write(lst,#13);
                {* Carriage return of given spacing *}
      If odd(mb) Then write(lst,#27'J',#13)   {* 13/216" spacing *}
      Else write(lst,#27'J',#11);  {* 11/216" spacing *}
    End; {if not(p_labels)}
  If odd(mb) Then dot_step := 9  {* Alternate dot steps for *}
  Else dot_step := 7; {* different spacings *}
End; {Send_Matrix_Data}
        {***************************************************}
Procedure Send_Laser_Data;
        {*
        *}

Var 
  ix,iy,byte_total      : integer;

Begin
  If Not(p_labels) Then
    Begin
      If rowl > xdot_max Then rowl := xdot_max;
      byte_total := rowl Div 8 + 1;
      If (rowl Mod 8) > 0 Then byte_total := byte_total+1;
      For iy:=0 To 7 Do
        Begin  {* loop for 8 rows *}
          write(lst,#27,'*b',byte_total,'W');
                  {* prepare to send data bytes *}
          For ix:=0 To (byte_total-1) Do
            write(lst,chr(bita[ix+150*iy]));
                  {* send data *}
        End; {for iy}
    End; {if not(p_labels)}
  dot_step := 8  {* 8 rows of data *}
End; {Send_Laser_Data}
        {***************************************************}


Begin   {* Printer_Artwork *}
  If net_start=Nil Then
    Begin
      message[1] := 'No circuit';
      message[2] := 'to do artwork';
      write_message;
    End
  Else
    Begin
      If reduction*bmax > 8*25.4 Then
        Begin
          message[1] := 'Reduction ratio';
          message[2] := 'too large';
          message[3] := 'Edit .puf file';
          write_message;
        End
      Else
        Begin


{*-------------------------------------------------------------------
			<Linux Printer Options>

     The following lines determine where printer-data will be sent.
     You should uncomment (and possibly change) the option that suits
     your system.
     The first option just sends it to /dev/null, i.e., the data will be
     ignored:
  *}
          assignlst(lst, '/dev/null|');


{* If you have a suitable printer, you can simply send the data to the
     printer, through the /usr/bin/lpr program. Note that the data contains
     all kind of control sequences, so it should not be interpreted by any
     printer filters. In this example, we assume that on your system a
     printer called 'raw' is defined for this purpose:
  *}
     { assignlst(lst, '|/usr/bin/lpr -Praw'); }


{* You may also want to send the data to a simple file, and send it to
     the printer by hand. This is e.g. useful if the printer is not
     directly reachable from this machine. As an example, we send the
     data to a file named 'puff.lst':
  *}
     { assignlst(lst, '/tmp/puff.lst|'); }


{* Note the '|' at the end of the filename. If you remove it, the file
     will also be sent to the printer using the 'lpr' program, and deleted
     afterwards.
     See the documentation of the free pascal compiler for more information
     on printing.
  ------------------------------------------------------------------------*}
          rewrite(lst);
          ydot := 0;      {* These initial values activate *}
          dot_step := 0;  {* chamfer routines in net_loop  *}
          remain := true;
          If Laser_Art Then
            Begin  {maximum number of dots at 150 dpi}
              xdot_max := Round(reduction*bmax*150/25.4);
              If xdot_max > 1200 Then xdot_max := 1200;
              lpt_label := '  LaserJet Art';
            End
          Else
            Begin    {maximum number of dots at 120 dpi}
              xdot_max := Round(reduction*bmax*120/25.4);
              If xdot_max > 960 Then xdot_max := 960;
              lpt_label := ' Dot-Matrix Art';
            End;
          mb := -1;
          p_labels := top_labels;
          If p_labels Then
            Begin
              message[2] := 'Press h to halt';
              write_message;
              While remain Do
                Begin
                  If keypressed Then
                    Begin
                      chs := ReadKey;
                      If chs In ['h','H'] Then
                        Begin
                          message[2] := '      HALT       ';
                          write_message;
                          goto exit_artwork;
                        End; {if key}
                      beep;
                    End; {if keypressed}
                  rowl := 0;
                  For ix:=0 To 1200 Do
                    bita[ix] := 0; {Initialize data}
                  Inc(mb);
                  Net_Loop;
                  If (rowl > 0) And p_labels Then
                    If Laser_Art Then Laser_labels
                  Else Matrix_labels;
                  If Laser_Art Then Send_Laser_Data
                  Else Send_Matrix_Data;
                End; {while remain}
              message[2] := 'Artwork completed';
              write_message;
              If Laser_Art Then write(lst,#27,'E'); {reset LaserJet, eject page}
            End; {if p_labels}
          exit_artwork:
                        close(lst);
        End;
    End;
End; {* Printer_Artwork *}

End.
