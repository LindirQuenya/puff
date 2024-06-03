{$R-}    {Range checking}
{$S-}    {Stack checking}
{$B-}    {Boolean complete evaluation or short circuit}
{$I+}    {I/O checking on}


Unit pfmsc;


(*******************************************************************

	Overlayed Unit PFMSC;

	PUFF MISCELLANEOUS CODE

        This code is now licenced under GPLv3.

	Copyright (C) 1991, S.W. Wedge, R.C. Compton, D.B. Rutledge.
        Copyright (C) 1997,1998, A. Gerstlauer.

        Modifications for Linux compilation 2000-2007 Pieter-Tjerk de Boer.

	Code cleanup for Linux only build 2009 Leland C. Scott.

	Original code released under GPLv3, 2010, Dave Rutledge.


	Contains code for:
		VGA/EGA Smith Charts,
		Help Commands,
		Device file s-parameter reading.

********************************************************************)

Interface

Uses 
Dos,   {Unit found in Free Pascal RTL's}
xgraph, {Custom replacement unit for TUBO's "Crt" and "Graph" units}
pfun1, {Add other puff units}
pfun2;


Procedure Draw_EGA_Smith(imped_chart : boolean);
Procedure Write_Commands;
Procedure Board_HELP_window;
Procedure Device_Read(tcompt : compt; indef : boolean);

(*
   Device_Read uses and includes the routines:
   procedure Get_Device_Params(tcompt : compt; var fname : file_string;
    				var len : double);
   procedure pars_tplate(tp:file_string;var n_c,n_s:integer;var f_p:boolean);
   procedure read_number(var s : double);
*)


Implementation



Procedure Draw_EGA_Smith(imped_chart : boolean);

{*
	Draw the smith chart with radius rho_fac.
	If imped_chart = true then draw impedance chart
			      else draw admittance chart.
*}

Var 
  I: INTEGER;

  RG_reye,reye{,Angle_2}                : integer;
  theta_start_high,theta_start_low,
  theta_in{,a,b},beta{,arc_length}  : double;

     {*****************************************************}
Procedure Get_thetas(a,b,cir_rad : double; delta_x : integer);

{*
        Find maximum angle allowed before an arc circle
        goes outside the Smith chart.
        Must have a<>0, b<>0.
     *}

Var 
  x : double;
Begin
  If ((a+b)<=cir_rad) Then
    Begin
   {if entire circle inside radius}
      theta_start_high := 0;
      theta_start_low := 0;
      theta_in := 180;
    End
  Else
    Begin
      x := 0.5*(a/b + b/a - sqr(1.0*cir_rad)/(a*b));
    { Cos(theta_in) = x }
      theta_in := 90 - 180*arctan(x/sqrt(1.0 - sqr(x)))/Pi;
   {this ArcCos function valid for -1 < x < 1}
      If imped_chart Or (delta_x > 0) Then
        Begin
          theta_start_high := 270 - beta - theta_in;
          theta_start_low := 450 + beta - theta_in;
        End
      Else
        Begin  {admittance chart}
          theta_start_high := 270 + beta - theta_in;
          theta_start_low := 450 - beta - theta_in;
        End;
      If imped_chart And (delta_x<0) Then
        theta_start_high := 360 - theta_in;
      If Not(imped_chart) And (delta_x>0) Then
        theta_start_high := 180 - theta_in;
    End;
End;

     {*********************************************************}
Procedure Make_Dot_Arcs(Arc_Rad,RG_delta_x,clip_rad : integer);
     {*
     		Make dotted arcs inside the smith chart
     *}

Var 
  a,b : double;
  i,j: INTEGER;
{     	k : integer; }

Begin

{       Angle_2:= Round( 180* Arc_length / (Pi * Arc_Rad) );
       if Angle_2 = 0 then Angle_2 := 1; }
  a := Arc_rad;
  If RG_delta_x=0 Then
    Begin  {b is the distance between circle centers}
      b := sqrt(sqr(1.0*reye)+sqr(a));  {right triangle for XB circles}
      beta := 180*arctan(1.0*reye/a)/Pi;
      If b<(a+clip_rad) Then
        Begin
          Get_thetas(a,b,clip_rad,0);

(*	     for k:= 1 to Trunc(2*theta_in) div Angle_2 do begin
                ths:= Round(theta_start_high) + (k-1)*Angle_2;
	        Arc(centerx+RG_reye,centery-Round(yf*Arc_Rad),
	     		ths,ths+1,Arc_Rad);
	        {plotting one degree makes a single arc point}
                ths:= Round(theta_start_low) + (k-1)*Angle_2;
	        Arc(centerx+RG_reye,centery+Round(yf*Arc_Rad),
	     		ths,ths+1,Arc_Rad);
             end; {for k}
*)
          i := rad + RG_reye;

          j := Round(theta_start_high + (2*theta_in) + 0.5);
             { BUG fix: Arc doesn't like coordinates outside of screen!! }
          While (Trunc(cos(Pi * j / 180) * Arc_rad) >= rad-RG_reye) Do
            Dec(j);
          Arc(i, rad - Round(yf * Arc_rad),
          Trunc(theta_start_high), j, Arc_Rad);

          j := Trunc(theta_start_low);
          While (Trunc(cos(Pi * j / 180) * Arc_rad) >= rad-RG_reye) Do
            Inc(j);
          Arc(i, rad + Round(yf * Arc_Rad),
          j, Round(theta_start_low + (2*theta_in) + 0.5),
          Arc_Rad);
        End; {if b<}
    End
  Else
    Begin
      b := 1.0*abs(RG_delta_x);  {mag of delta_x for RG circles}
      beta := 90;
      If (a<b+clip_rad) And (b<a+clip_rad) Then
        Begin
          Get_thetas(a,b,clip_rad,RG_delta_x);

(*	     for k:=1 to Trunc(2*theta_in) div Angle_2 do begin
                ths:= Round(theta_start_high) + (k-1)*Angle_2;
	        Arc(centerx+RG_delta_x,centery,ths,ths+1,Arc_rad);
	        {plotting one degree makes a single arc point}
	        {plot continuously for the circle}
             end; {for k}
*)
          Arc(rad + RG_delta_x, rad, Trunc(theta_start_high),
          Round(theta_start_high + (2 * theta_in) + 0.5), Arc_rad);
        End; {if a< and b<}
    End;
End;
     {*********************************************************}

Begin  {*Draw_EGA_Smith*}
  SetViewPort(centerx-rad, centery-rad, centerx+rad, centery+rad, TRUE);
  SetFillStyle(SolidFill, black);

  SetCol(Green);

  reye := Round (rad / rho_fac);
  If imped_chart Then RG_reye := reye
  Else RG_reye := -reye;
  If rho_fac > 0.29 Then
    Begin  {ignore lines for tiny smith chart}

        { If very large raw just outer circle }

      If (rho_fac <= 15) Then
        Begin


(*	  if Large_Smith then
	  	{* Set arc length to 10 degrees (0.2618 radians)x .25 reye *}
		Arc_length:= 0.036*reye*rho_fac
	  else
	  	{* Set arc length to 15 degrees (0.2618 radians)x .25 reye *}
		Arc_length:= 0.055*reye*rho_fac;
*)
          { r circles, except smallest one }
          For I:= 2 To 5 Do
            Begin
              Make_Dot_Arcs ((I * reye) DIV 6, ((6 - I) * RG_reye) DIV 6, rad);
            End;

          { If large chart then draw r circles outside eye }
          If rho_fac > 1.5 Then
            Begin
              Make_Dot_Arcs (reye,      2 * RG_reye,  rad);
              Make_Dot_Arcs (3 * reye, -2 * RG_reye,  rad);
              Make_Dot_Arcs (3 * reye,  4 * RG_reye,  rad);
            End;

(*             Make_Dot_Arcs(reye div 2,0,rad);  {center 0 calls xb circles}
{	     Make_Dot_Arcs(reye,0,rad); }
	     Make_Dot_Arcs(2*reye,0,rad);
          end
          else begin
{             IF (rho_fac > 1.0) THEN BEGIN
               FOR I:= 1 TO 3 DO BEGIN
                 Make_Dot_Arcs ((I * reye) DIV 3, 0, reye);
               END;
               FOR I:= 1 TO 2 DO BEGIN
                 Make_Dot_Arcs ((3 * reye) DIV I, 0, reye);
               END;
             END ELSE BEGIN *)

          { draw xb circles }
          Make_Dot_arcs (reye * 5, 0, rad);
          Make_Dot_arcs (reye * 2, 0, rad);
          Make_Dot_arcs (reye Div 2, 0, rad);


{ Draw smallest r circle and clear area inside (if visible)
            This makes the xb circles stop at the inner r circle }
          If (rho_fac > 0.66) Then
            FillEllipse((5 * RG_reye) DIV 6 + rad, rad, reye DIV 6, reye DIV 6);
          { if necessary also left side }
          If (rho_fac > 1.0) Then
            FillEllipse((7 * RG_reye) DIV 6 + rad, rad, reye DIV 6, reye DIV 6);

          { Now draw xb circles that cut smallest r circle }
          Make_Dot_Arcs (reye Div 5, 0, rad);
          Make_Dot_Arcs (reye, 0, rad);
        End; {if not(rho_fac>15)}
    End      {rho > 0.3}
  Else If rho_fac > 0.18 Then
         Begin   {if .18<rho_fac<.3 then tick and cir}
{        Arc_length:= 0.05*reye*2*rho_fac; }
           Make_Dot_Arcs(reye Div 2, RG_reye Div 2, rad);
           Line(rad, rad-3, rad, rad+3);
         End      {rho > 0.18}
  Else
    Begin   {if rho_fac < .18 then just draw a tick mark}
      Line(rad, rad-3, rad, rad+3);
    End;
  { real axis }
  Line(0, rad , 2*rad, rad);

  { outer circles }
  SetCol(lightgreen);
  If rho_fac > 1.0 Then
    Begin
      Circle(rad, rad, reye);
    End;
  If (blackwhite) Then SetColor(lightgreen);
  Circle(rad, rad, rad); {draw outer circle}

  { overpaint overetched arc parts }
  reye := 2 * rad;
  FloodFill(0, 0, lightgreen);
  FloodFill(0, reye, lightgreen);
  FloodFill(reye, 0, lightgreen);
  FloodFill(reye, reye, lightgreen);

  If (blackwhite) Then
    Begin
      SetColor(white);
      Circle(rad,rad,rad);
    End;


(*  { mark at (1 0) }
  SetCol(green);
  IF (blackwhite) THEN SetFillStyle(solidFill, white) ELSE SetFillStyle(solidFill, green);
  FillEllipse(rad, rad, 2, 2);
{  Circle(rad, rad, 2); }
*)

  SetViewPort(xmin[12], ymin[12], xmax[12], ymax[12], False)
End; {*Draw_EGA_Smith*}


Procedure Write_Commands;
{*
	Write commands in help box.
*}

Const    {* Commands for help window *}
  command: array[1..3,1..9,1..4] Of string[17] = (
                                                  (( #27' '#26' '#24' '#25,' draw part','',''),
                                                 ('=','  ground '#132'      ','',''),
                                                 ('1..4',' connect path','',''),
                                                 ('a..r','  select part','',''),
                                                 ('Ctrl-e',' erase crct','',''),
                                                 ('Ctrl-n',' go to node','',''),
                                                 ('Shift',' move/erase','',''),
                                                 ('F10','  toggle help','',''),
                                                 ('Esc','  exit        ','','')),
                                                 (( #27' '#26' '#24' '#25,'   cursor ','',''),
                                                 ('p,Ctrl-p','  plot   ','',''),
                                                 ('PgUp,PgDn',' marker ','',''),
                                                 ('Ctrl-s','  save file','',''),
                                                 ('Ctrl-a','  artwork  ','',''),
                                                 ('i,s',' impulse, step','',''),
                                                 ('Tab',' toggle Smith','',''),
                                                 ('Alt-s',' large Smith','',''),
                                                 ('F10, Esc',' help, exit   ','','')),
                                                 (( #27' '#26' '#24' '#25,'   cursor ','',''),
                                                 ('Del,Backspace,Ins','','',''),
                                                 ('Alt-o ',Omega,'   Alt-m ', Mu),
                                                 ('Alt-d ',Degree,'   Alt-p ',Parallel),
                                                 ('Ctrl-e',' erase crct','',''),
                                                 ('Ctrl-r',' read file ','',''),
                                                 ('Tab','  extra parts','',''),
                                                 ('F10','  toggle help','',''),
                                                 ('Esc','  exit        ','','')));

Var 
  i,imax    : integer;

Begin
  imax := ymax[4]-ymin[4]+1;
  If (imax>9) Then imax := 9;
  If Not((window_number=3) And read_kbd
     And circuit_changed) Then erase_message;
  Make_Text_Border(xmin[4]-1,ymin[4]-1,xmax[4]+1,ymax[4]+1,
                   col_window[window_number],true);
  For i:=1 To imax Do
    Begin   {write help window elements}
      GotoXY(xmin[4],ymin[4]-1+i); {position of command window}
      TextCol(white);
      write(command[window_number,i,1]);
      TextCol(lightgray);
      write(command[window_number,i,2]);
      TextCol(white);
      write(command[window_number,i,3]);
      TextCol(lightgray);
      write(command[window_number,i,4]);
    End;
  write_compt(col_window[window_number],command_f[window_number]);
   {Write header for help window}
End; {* Write_Commands *}


Procedure Board_HELP_window;

{*
	Erase parts list area, write zd and fd,
	draw window box, list parts.
	Called only by Read_Net.
*}
Begin
  Make_Text_Border(xmin[3]-1,ymin[3]-1,xmax[3]+1,ymax[3]+1,
                   col_window[4],true);   {clear and write border }
  write_compt(col_window[4],command_f[4]);    {write BOARD Header}
  Window(xmin[3],ymin[3],xmax[3],ymax[3]);
  TextCol(lightgray);
  WriteLn('zd : norm. impedance');
  WriteLn('fd : design freq.');
  WriteLn('er : diel. constant');
  WriteLn('h  : sub. thickness');
  WriteLn('s  : board size');
  WriteLn('c  : conn. separation');
  WriteLn('Tab : toggle type');
  Window(1,1,Max_Text_X,Max_Text_Y);  {Default}
End; {* Board_HELP_window *}


Procedure Get_Device_Params(tcompt:compt;Var fname:file_string;Var len:double);

{*
	Read device description from parts window (tcompt^.descript)
	and extract filename and length information.
*}

Const 
  potential_numbers: set Of char = ['+','-','.',',','0'..'9'];

Var 
  p1,p2,code,i,j,long   : integer;
  c_string,s_value : line_string;
  found_value  : boolean;

Begin
  len := 0.0;        { default length was Manh_length}
  fname := tcompt^.descript; {* fname = e.g. 'e device fsc10 2mm' *}
  For j:=1 To 2 Do
    Begin
      p1 := Pos(' ',fname); {find index for blanks in descript}
      Delete(fname,1,p1); {delete through blanks in descript}
    End;
  p2 := Length(fname); {get string length} {now fname = 'fsc10 2mm  ' }
  While fname[p2]=' ' Do
    Begin  {remove any blanks at end}
      Delete(fname,p2,1);
      Dec(p2);
    End;
  p1 := Pos(' ',fname); {here fname = 'fsc10 2mm' or 'fsc10' }
  c_string := fname; {now c_string = 'fsc10 2mm' }
  If p2 = 0 Then
    Begin
      ccompt := tcompt;
      bad_compt := true;
      message[1] := 'Invalid device';
      message[2] := 'specification';
      exit;
    End
  Else If (p1 > 0) Then
         Delete(fname,p1,p2); {now fname = 'fsc10'}
  If Not(Manhattan(tcompt) Or (p1=0) ) Then
    Begin
      Delete(c_string,1,p1);      {now c_string = '2mm'}
      long := length(c_string);
      While c_string[long]=' ' Do
        Dec(long);  {remove blanks at end}
      found_value := false;
      s_value := '';
      j := 1;
      While (c_string[j] = ' ') And (j < long+1) Do
        Inc(j);   {Skip spaces}
      Repeat
        If c_string[j] In potential_numbers Then
          Begin
            If Not(c_string[j]='+') Then
              Begin   {ignore + }
                If c_string[j]=',' Then s_value := s_value+'.'  {. for ,}
                Else s_value := s_value+c_string[j];
              End; {+ check }
            Inc(j);
          End
        Else
          found_value := true;
      Until (found_value Or (j=long+1));
      Val(s_value,len,code);  {convert string to double number}
      If (code<>0) Or (Pos('m',c_string) = 0) Or (long=0) Then
        Begin
          ccompt := tcompt;
          bad_compt := true;
          message[1] := 'Invalid length';
          message[2] := 'or filename';
          exit;
        End;  {Here j is right of the number}
      While (c_string[j] = ' ') And (j < long+1) Do
        Inc(j);   {Skip spaces}
     {* if j=long then j must point to an 'm' *}
      If (c_string[j] In Eng_Dec_Mux) And (j<long) Then
        Begin
          If c_string[j]='m' Then
            Begin   {is 'm' a unit or prefix?}
              i := j+1;
              While (c_string[i] = ' ') And (i < long+1) Do
                Inc(i);
   {* Skip spaces to check for some unit *}
              If (c_string[i]='m') Then
                Begin
      {it's the prefix milli 'm' next to an 'm'}
                  len := Eng_Prefix('m')*len;
                  j := i; {make j point past the prefix, to the unit}
                End;
            End  {if 'm' is a unit do nothing}
          Else
            Begin  {if other than 'm' factor in prefix}
              len := Eng_Prefix(c_string[j])*len;
              Inc(j);  {advance from prefix toward unit}
            End;
        End;  {if in Eng_Dec_Mux}
      len := 1000*len; {return length in millimeters, not meters}
      While (c_string[j] = ' ') And (j < long+1) Do
        Inc(j);
      If (len<0) Or (c_string[j]<>'m') Then
        Begin
          ccompt := tcompt;
          bad_compt := true;
          message[1] := 'Negative length';
          message[2] := 'or invalid unit';
          exit;
        End;
    End; {if not Manhattan}
End; {* Get_Device_Params *}


{************************************************************************}

Procedure Device_Read(tcompt : compt; indef : boolean);

{*
	Device equivalent of tline.
	Included within are Pars_tplate and Read_Number.

	Only to be used when action= true  
		get device parameters (filename,draw length)
		check that file exists.
		Check for .puf or .dev files.

	Indef specifies whether or not to enable the generation
	of indefinite scattering parameters (extra port).

	type compt has the following s_param records:
		tcompt^.s_begin,
		tcompt^.s_file,
		tcompt^.s_ifile,
		tcompt^.f_file
*}

Label 
  read_finish;

Var 
  fname           : file_string;
  c_ss,c_f   : s_param;
{  s1,s2        			: array[1..10,1..10] of Tcomplex; }
  template        : string[128];
  ext_string   : string[3];
  first_char   : string[1];
  char1,char2   : char;
  freq_present,
  Eesof_format        : boolean;
  i,j,number_of_s,code1,
  number_of_ports,Eesof_ports : integer;
  f1,mag,ph                     : double;


   {**************************************************************}

Procedure Pars_tplate(tp:file_string;Var n_c,n_s:integer;Var f_p:boolean);

{*
	Partition template. Extract number of connectors and frequencies. 
	template (tp:file_string) is in the form ' f  s11  s21  s12  s22 '
*}

Var 
  i,j,i1,i2,x,code  : integer;
  ijc    : array[1..16] Of string[2];

Begin
  If (Pos('f',tp) > 0) Or (Pos('F',tp) > 0) Then
    f_p := true
  Else
    f_p := false;
  n_s := 0;
  Repeat
    i1 := Pos('s',tp);
    i := i1;
    i2 := Pos('S',tp);
    If i1 < i2 Then
      Begin
        If i1 > 0 Then i := i1
        Else i := i2;
      End
    Else
      Begin
        If i2 > 0 Then i := i2
        Else i := i1;
      End;
    If i>0 Then
      Begin
        Delete(tp,1,i);
        n_s := n_s+1;
        If length(tp) >= 2 Then
          Begin
            ijc[n_s] := tp;
            Delete(tp,1,2);
          End;
      End;
  Until (length(tp)=0) Or (i=0);
  n_c := 1;
  For i:=1 To n_s Do
    Begin
      Val(ijc[i],x,code);
      If code <> 0 Then
        Begin
          bad_compt := true;
          message[1] := 'Bad port number';
          message[2] := 'in device';
          message[3] := 'file template';
          exit;
        End;
      iji[i,1] := x Div 10;
      iji[i,2] := x-iji[i,1]*10;
      If (iji[i,1] < 1) Or (iji[i,2] < 1) Then
        Begin
          bad_compt := true;
          message[1] := '0 port number';
          message[2] := 'in device';
          message[3] := 'file template';
          exit;
        End;
      If iji[i,1] > n_c Then n_c := iji[i,1];
      If iji[i,2] > n_c Then n_c := iji[i,2];
      For j:=1 To i-1 Do
        If (iji[i,1]=iji[j,1]) And (iji[i,2]=iji[j,2]) Then
          Begin
            bad_compt := true;
            message[1] := 'Repeated sij';
            message[2] := 'in device';
            message[3] := 'file template';
            exit;
          End;
    End; {for i := 1 to n_s}
  If n_s=0 Then
    Begin
      bad_compt := true;
      message[1] := 'No port numbers';
      message[2] := 'in device';
      message[3] := 'file template';
    End;
End; {Pars_tplate}

  {********************************************************}

Procedure Read_Number(Var s: double);
{*
	Read s-parameter values from files.
*}

Var 
  ss  : string[128];
  char1  : char;
  code  : integer;
  found  : boolean;

Begin
  ss := first_char;  {first_char is the very first valid file character}
  found := false;
  If (ss='') Then  {search for first valid character if not in first_char}
    If Not(EOF(dev_file)) Then
      Begin  {goto next number}
        Repeat  {keep reading characters until a valid one is found}
          If SeekEoln(dev_file) Then ReadLn(dev_file);
      {if blank line then advance to next line}
          Read(dev_file,char1);  {read single character}
          If char1 In [lbrack,'#','!'] Then ReadLn(dev_file);
      {skip potential comment lines}
          If char1 In ['+','-','.',',','0'..'9','e','E','\'] Then
            Begin
              ss := char1;
              found := true;
            End;
        Until found Or EOF(dev_file);
      End;
  found := false;
  If Not EOF(dev_file) Then
    Repeat {continue reading characters and add to string ss until invalid}
      Read(dev_file,char1);
      If char1 In ['+','-','.',',','0'..'9','e','E'] Then
        ss := ss+char1
      Else
        found := true;
    Until found Or Eoln(dev_file) Or EOF(dev_file);
  Val(ss,s,code); { turn string ss into double number }
  If (code<>0) Or (length(ss)=0) Then
    Begin
      bad_compt := true;
      message[1] := 'Extra or missing';
      message[2] := 'number in';
      message[3] := 'device file';
    End; {if code <> 0}
End; {read_number}

  {********************************************************}

Procedure Seek_File_Start(temp_exists : boolean);

{*
	Look for the start of useable data in a file
	    including a template or numbers.
	Do so via a character search for:
	     'f', 'F', 's' or 'S' for templates,
	      or any numeric character for Eesof files.
*}

Var 
  char1  : char;
  found  : boolean;

Begin
  found := false;
  first_char := '';
  Repeat   {keep reading characters until a valid one is found}
    While SeekEoln(dev_file) Do
      ReadLn(dev_file);
      {Advance past any blank lines}
    Repeat
      Read(dev_file,char1);  {find single character}
    Until (char1<>' ') Or Eof(dev_file);
    If char1 In [lbrack,'#','!'] Then ReadLn(dev_file);
      {Skip lines with comments }
    If temp_exists Then
      Begin
        If char1 In ['f','F','s','S'] Then
          Begin
            first_char := char1;
            found := true;
          End;
      End
    Else
      Begin
        If char1 In ['+','-','.',',','0'..'9'] Then
          Begin
            first_char := char1;
            found := true;
          End;
      End;
  Until found Or EOF(dev_file);
End;
  {********************************************************}


Begin  {* Device_Read *}
  Get_Device_Params(tcompt,fname,tcompt^.lngth); {get filename and length}
  If bad_compt Then exit;
    {! length check moved from this location}
  Eesof_format := false;
  i := Pos('.',fname);
  If (i=0) Then
    fname := fname+'.dev' {add .dev extension}
  Else
    Begin   {Check for Eesof type extension}
      ext_string := Copy(fname,i+1,3);  {copy 3 character extension}
      If (Length(ext_string)=3) Then
        Begin
          If (ext_string[1] In ['s','S'])
             And (ext_string[2] In ['1'..'4'])
             And (ext_string[3] In ['p','P'])
            Then
            Begin
              Val(ext_string[2],Eesof_ports,code1);
              If code1=0 Then Eesof_format := true;
            End; {eesof check}
        End; {length check}
    End; {ext check}
  If (tcompt^.f_file = Nil) Or tcompt^.changed Then
    If fileexists(true,dev_file,fname) Then
      Begin
        With tcompt^ Do
          Begin
            If Eesof_format Then
              Begin
                Seek_File_Start(false);
      {Skip lines looking for start of data}
      {! WARNING Seek_File_Start stores the first
	        data character in first_char!}
                number_of_ports := Eesof_ports;
                number_of_s := Sqr(number_of_ports);
                freq_present := true;
      {* set up iji[] array *}
                For i:=1 To number_of_ports Do
                  For j:=1 To number_of_ports Do
                    Begin
                      iji[number_of_ports*(i-1)+j,1] := i;
                      iji[number_of_ports*(i-1)+j,2] := j;
                    End;
      {* Must correct for 2-ports since their order is goofy *}
                If (number_of_ports=2) Then
                  Begin
                    iji[2,1] := 2;
                    iji[2,2] := 1;
                    iji[3,1] := 1;
                    iji[3,2] := 2;
                  End;
              End
            Else
              Begin
                While SeekEoln(dev_file) Do
                  ReadLn(dev_file);
      {Advance past any blank lines}
                ReadLn(dev_file,template); { read first line string }
                If Pos('\b',template) > 0 Then
                  Begin  {* if a .PUF file *}
                    Repeat    {* then move to \s section *}
                      ReadLn(dev_file,char1,char2);
                    Until ((char1='\') And (char2 In ['s','S'])) Or Eof(dev_file);
                    If EOF(dev_file) Then
                      Begin
                        bad_compt := true;
                        message[1] := 's-parameters';
                        message[2] := 'not found in';
                        message[3] := 'device file';
                        goto read_finish;
                      End;
                  End; {if Pos('\b')}
     { now check for valid template = e.g. ' f   s11  s21  s12  s22 '}
                While (template[1]=' ') Do
                  Delete(template,1,1);
        {delete leading blanks}
                If (template[1] In ['f','F','s','S']) Then
                  Pars_tplate(template,number_of_ports,number_of_s,freq_present)
               {have a potentially valid template, get info}
                Else
                  Begin
                    Seek_File_Start(true);
   {Skip lines looking for template}
                    If EOF(dev_file) Then
                      Begin
                        bad_compt := true;
                        message[1] := 'template';
                        message[2] := 'not found in';
                        message[3] := 'device file';
                        goto read_finish;
                      End;
                    ReadLn(dev_file,template);
                    Insert(first_char,template,1);
          {Put back character removed by Seek_File_Start}
                    first_char := ''; {This to initialize Read_Number}
                    Pars_tplate(template,number_of_ports,number_of_s,freq_present);
     {get info from template}
                  End; { end template search}
     {* Number_of_ports is how many are in the file *}
     {* Number_of_con is how many will result *}
              End;  { else Eesof_format }
            If indef Then number_of_con := number_of_ports+1
            Else number_of_con := number_of_ports;
   {* Initialize sdevice elements to zero *}
            For j:= 1 To number_of_con Do
              For i:= 1 To number_of_con Do
                Begin
                  sdevice[i,j].r := 0;
                  sdevice[i,j].i := 0;
                End;
(*	  width:=0;   *)
   {! This section moved from 4th line--get_device returns 0 for Manh }
            If Manhattan(tcompt) Or (tcompt^.lngth=0) Then
              Begin
                If (number_of_con > 1) Then
                  tcompt^.lngth := Manh_length*(number_of_con-1)
                Else
                  tcompt^.lngth := Manh_length;
              End;
            tcompt^.width := tcompt^.lngth;  {symmetrical}
            If tcompt^.lngth<=resln Then
              Begin
                bad_compt := true;
                message[1] := 'Device length';
                message[2] := 'must be';
                message[3] := '>'+sresln;
                goto read_finish;
              End;
            con_space := 0.0;
            c_ss := Nil;
            c_f := Nil;
            f1 := -1.0;  {use f1 to detect start of noise parameters}
   {* LOOP to read in s-parameters from file *}
            Repeat
              If freq_present Then
                Begin
                  If c_f=Nil Then
                    Begin
                      New_s(tcompt^.f_file);
                      c_f := tcompt^.f_file;
                    End
                  Else
                    Begin
                      New_s(c_f^.next_s);
                      c_f := c_f^.next_s;
                    End; {c_f=nil}
                  c_f^.next_s := Nil;
                  New_c (c_f^.z);
                  Read_Number(c_f^.z^.c.r);
    {Must set up next call to Read_Number in case}
    {on the first pass first_char was set. This}
    {only occurs with Eesof files, effecting only}
    {the first frequency data point}
                  first_char := '';
  {* Compare with last freq. for start of noise parameters *}
                  If (f1 > c_f^.z^.c.r)   {if last frequency was larger}
                     Or bad_compt Then
                    Begin {have reached EOF}
                      erase_message;
                      bad_compt := false;
                      goto read_finish;
                    End; {if bad_compt}
                  f1 := c_f^.z^.c.r;  {Save last freq point}
                End {if freq_present=true}
              Else
                tcompt^.f_file := Nil; {end else}
              For i:=1 To number_of_s Do
                Begin
                  Read_Number(mag);
                  If bad_compt Then
                    Begin
                      If (i=1) And Not(freq_present) Then
                        Begin
         {reached EOF}
                          erase_message;
                          bad_compt := false;
                        End; {if i=1}
                      goto read_finish;
                    End; {if bad_compt=true}
                  Read_Number(ph);
                  If bad_compt Then goto read_finish;
                  sdevice[iji[i,1],iji[i,2]].r := one*mag*cos(ph*pi/180);
                  sdevice[iji[i,1],iji[i,2]].i := one*mag*sin(ph*pi/180);
                End; {for i:=1 to number_of_s}

{* Here sdevice[] is filled with s-parameters
	        for a single frequency. Indef_Matrix will
	        generate additional scattering parameters
	        to fill an additional port number.	   *}
              If indef Then Indef_Matrix(sdevice,number_of_ports);
              For j:= 1 To number_of_con Do
                For i:= 1 To number_of_con Do
                  Begin
                    If c_ss=Nil Then
                      Begin
                        New_s(tcompt^.s_file);
                        c_ss := tcompt^.s_file;
                      End
                    Else
                      Begin
                        New_s(c_ss^.next_s);
                        c_ss := c_ss^.next_s;
                      End;
                    c_ss^.next_s := Nil;
                    New_c (c_ss^.z);
                    c_ss^.z^.c.r := sdevice[i,j].r; {fill parameters}
                    c_ss^.z^.c.i := sdevice[i,j].i;
                  End; {for j,i:= 1 to number_of_con}
            Until EOF(dev_file); {end repeat}
          End; {with}
        read_finish:
                     close(dev_file);
      End  {if (tcompt^.f_file = nil) and fileexists=true }
  Else    {if fileexists = false}
    bad_compt := true;
End; {* Device_Read *}

{*********************************************************************}




End.
{Unit implementation}
