{$R-}    {Range checking}
{$S-}    {Stack checking}
{$B-}    {Boolean complete evaluation or short circuit}
{$I+}    {I/O checking on}


Unit pfun3;


(*******************************************************************

	Unit PFUN3;

        This code is now licenced under GPLv3.

	Copyright (C) 1991, S.W. Wedge, R.C. Compton, D.B. Rutledge.
        Copyright (C) 1997,1998, A. Gerstlauer.

        Modifications for Linux compilation 2000-2007 Pieter-Tjerk de Boer.

	Code cleanup for Linux only build 2009 Leland C. Scott.

	Original code released under GPLv3, 2010, Dave Rutledge.


	Potentially hazardous code is denoted by {!xxx} comments

	Contains code for:
		writing text info to screen,
		saving and moving markers,
		basic editing commands,
		basic circuit cursor motion,
		basic circuit drawing.

********************************************************************)

Interface

Uses 
Dos,   {Units found in the Free Pascal's RTL's}
Printer,  {Unit found in TURBO.TPL}
xgraph, {Custom replacement unit for TUBO's "Crt" and "Graph" units}
pfun1, {Add other puff units}
pfun2;


Procedure write_freqO;
Procedure write_sO(ij : integer);
Procedure HighLight_Window;
Procedure Toggle_Circuit_Type;
Procedure Write_Board_Parameters;
Procedure Write_Expanded_Parts;
Procedure Write_Parts_ListO;
Procedure Write_Plot_Prefix(time2 : boolean);
Procedure Write_Coordinates(time : boolean);
Procedure Write_BigSmith_Coordinates;
Procedure restore_boxO(ij : integer);
Procedure move_boxO(xn,yn,nb : integer);
Procedure draw_ticksO(x1,y1,x2,y2 : integer; incx,incy : double);
Procedure Write_File_Name(fname : file_string);
Procedure calc_posO(x,y,theta,scf: double;sfreq: integer;dash: boolean);
Procedure Smith_and_Magplot(lighten,dash,boxes : boolean);

(* Included in Smith and Magplot are:
 	procedure splineO(ij : integer);
	procedure smith_plotO(x1,y1,col : integer; Var linex : boolean);
	procedure rect_plotO(x1,y1,col : integer;Var linex : boolean);	*)
Procedure Draw_Graph(x1,y1,x2,y2 : integer; time : boolean);
(* Component Editing *)
Procedure del_char(tcompt : compt);
Procedure back_char(tcompt : compt);
Procedure add_char(tcompt : compt);
Procedure choose_part(ky : char);
Procedure draw_net(tnet : net);
Function con_found : boolean;
Function new_net(ports : integer; choice : boolean) : net;
Procedure dispose_net(vnet : net);
Function new_con(tnet : net; dirt : integer) : conn;
Procedure dispose_con(vcon : conn);
Procedure draw_port(mnet : net; col : integer);
Procedure draw_to_port(tnet : net; port_number : integer);
Procedure draw_ports(tnet : net);
Procedure node_look;
Procedure goto_port(port_number : integer);
Procedure new_port(x,y : double; port_number : integer);
Procedure Draw_Circuit;
Function off_boardO(step_size : double) : boolean;
Procedure Get_Key;

(*	Get_Key includes:
	procedure draw_cursorO;
	procedure erase_cursorO; 
	procedure ggotoxy(var cursor_displayed : boolean);   *)
Procedure ground_node;
Procedure unground;
Procedure join_port(port_number,ivt : integer);

{*******************************************************************}

Implementation

Procedure write_freqO;

{* 
	Write frequency in the plot window box 
		as the marker is moved.
	Makes it's own calculation to determine freq.
*}
Begin
  TextCol(lightgray);
  If Alt_Sweep Then
    x_sweep.Label_Plot_Box
      { if alt_sweep put in x_sweep part label and unit label }
  Else
    Begin  {else put in 'f' and 'Hz'}
      GotoXY(xmin[2]+4,ymin[2]+2);
      Write('f');
      GotoXY(xmin[2]+16,ymin[2]+2);
      Write(freq_prefix,'Hz');
      { Frequency prefix (k,M,G,etc.) is freq_prefix }
    End;
  {Now write the number}
  freq := fmin+xpt*finc;   {These parameters are all normalized}
  TextCol(green);
  GotoXY(xmin[2]+6,ymin[2]+2);   {was 40,20}
  Write(freq:8:4);
End; {write_freqO}


Procedure write_sO(ij : integer);
{*	
	Write s-parameters in plot window box as marker is moved.
*}

Var 
  rho,lnrho,deg : double;

Begin
  GotoXY(xmin[2]+5,ymin[2]+2+ij);   {was mgotoxy, was 43,20}
  rho := sqr(c_plot[ij]^.x)+sqr(c_plot[ij]^.y);
  deg := atan2(c_plot[ij]^.x,c_plot[ij]^.y);
  If rho>1.0e-10 Then
    Begin
      If rho<1.0e+10 Then
        Begin
          lnrho := 10*ln(rho)/ln10;
          If s_param_table[ij]^.descript[2]In['f','F'] Then
            lnrho := lnrho/2.0;
          Write(lnrho:7:2,'dB',deg:6:1,degree);
        End
      Else
        Begin
          Write('   ',infin,ity,'           ');
        End;
    End
  Else
    Begin
      Write('   0            ');
    End;
End; {* Write_sO *}


Procedure HighLight_Window;
{*
	Causes F# key to be highlighted on the screen
	when that window has been selected.
*}
Begin
  GotoXY(window_f[window_number]^.xp+1,window_f[window_number]^.yp);
  TextCol(white);
  Write('F',window_number);   {highlight selected window}
End; {* Highlight_Window *}


Procedure Toggle_Circuit_Type;
{*
	Toggle between stripline and microstrip.
	Called by Board4 in PUFF20.
*}
Begin
  Board_Changed := true;
  TextCol(lightgray);
  GotoXY(xmin[4],ymin[4]+6);
  Write('Tab  ');
  If Manhattan_Board Then
    Begin
      stripline := true;
      Manhattan_Board := false;
      Write('stripline ');
    End
  Else If stripline Then
         Begin
           stripline := false;
           Write('microstrip');
         End
  Else
    Begin
      Manhattan_Board := true;
      stripline := true; {make calculations easier}
      Write('Manhattan ');
    End;
End;



Procedure Write_Board_Parameters;
{*
	Write board parameter in screen area.
*}

Var 
  tcompt     : compt;



Begin
  Make_Text_Border(xmin[4]-1,ymin[4]-1,xmax[4]+1,ymax[4]+1,
                   col_window[4],true);
  {erase and write border in board color}
  write_compt(col_window[4],window_f[4]);    {write BOARD Header}
  If board_start <> Nil Then
    Begin
      tcompt := Nil;
      Repeat
        If tcompt=Nil Then tcompt := board_start
        Else tcompt := tcompt^.next_compt;
        write_compt(lightgray,tcompt);
      Until tcompt^.next_compt=Nil;
      TextCol(lightgray);
      GotoXY(xmin[4],ymin[4]+6);
      Write('Tab  ');
      If Manhattan_Board Then Write('Manhattan ')
      Else If stripline Then Write('stripline ')
      Else Write('microstrip');
    End;
End; {* Write_Board_Parameters *}


Procedure Write_Expanded_Parts;

{*
	Erase parts list area, write zd and fd,
	draw window box, list parts.
	Called only by Read_Net.
*}

Var 
  tcompt     : compt;

Begin
  Make_Text_Border(xmin[3]-1,ymin[3]-1,xmax[5]+1,ymax[5]+1,
                   col_window[3],true);
  write_compt(col_window[3],window_f[3]);
  If (window_number=3) Then Highlight_Window;
  If part_start <> Nil Then
    Begin
      tcompt := Nil;
      Repeat
        If tcompt=Nil Then tcompt := part_start
        Else tcompt := tcompt^.next_compt;
        write_compt(lightgray,tcompt);
      Until tcompt^.next_compt=Nil;
    End;
End; {* Write_Expanded_Parts *}


Procedure Write_Parts_ListO;

{*
	Erase parts list area, write zd and fd,
	draw window box, list parts.
	Called only by Read_Net.
*}

Var 
  tcompt     : compt;
  y          : integer;



Begin
  Make_Text_Border(xmin[3]-1,ymin[3]-1,xmax[3]+1,ymax[3]+1,
                   col_window[3],true);
  write_compt(col_window[3],window_f[3]);
  If part_start <> Nil Then
    Begin
      tcompt := Nil;
      y := ymin[3];
      Repeat
        If tcompt=Nil Then tcompt := part_start
        Else tcompt := tcompt^.next_compt;
        write_compt(lightgray,tcompt);
        y := y+1;
      Until y=ymax[3]+1;
    End;
End; {* Write_Parts_ListO *}


Procedure Write_Plot_Prefix(time2 : boolean);
{* 
	Find the frequency or time unit prefix and write
	it in the plot window.
*}

Const 
  Freq_Prefix : string = 'EPTGMk m'+Mu+'npfa';
  Time_Prefix : string = 'afpn'+Mu+'m kMGTPE';

Var 
  i : integer;

Begin
  GotoXY(x_y_plot_text[5,1]+2,x_y_plot_text[5,2]);
  TextCol(lightgray);
  If time2 Then
    Begin
      i := 0;
      Repeat
        i := i+1
      Until (Freq_Prefix[i]=s_board[2,2]);
    {find index for frequency prefix}
      Write(Time_Prefix[i]); {write time prefix}
    End
  Else
    Write(s_board[2,2]); {write frequency prefix}
End; {* Write_Plot_Prefix *}


Procedure Write_Coordinates(time : boolean);
{*
	Write parameters in the plot window
*}

Var 
  i      : integer;
  tcompt : compt;
  temp   : line_string;

Begin
  Inc(WindMax); {to prevent scrolling}
  If time Then
    Begin
      TextCol(lightgray);
      temp := rho_fac_compt^.descript;
      Delete(temp,1,13);
      gotoxy(x_y_plot_text[1,1]-Length(temp),x_y_plot_text[1,2]);{was 56-}
      write(temp);
      temp := '-'+temp;
      gotoxy(x_y_plot_text[3,1]-Length(temp),x_y_plot_text[3,2]);
      write(temp);    {was 56-}
      gotoxy(x_y_plot_text[4,1],x_y_plot_text[4,2]);
      write(sxmin:6:3); {was 56,13}
      gotoxy(x_y_plot_text[6,1]-6,x_y_plot_text[6,2]);
      write(sxmax:6:3);
      Gotoxy(x_y_plot_text[2,1],x_y_plot_text[2,2]);
      write(' S');     {was 53,6}
      gotoxy(x_y_plot_text[5,1],x_y_plot_text[5,2]);
      write('t  sec'); {was 66,13}
    End
  Else
    Begin
      For i:=1 To 10 Do
        Begin
          If i=1 Then tcompt := coord_start
          Else tcompt := tcompt^.next_compt;
          With tcompt^ Do
            Begin
              If right Then xp := xorig-Length(descript);
              If (length(descript) > x_block) Or (i < 7) Then
                Begin
                  write_compt(lightgray,tcompt);
                  If i In [7..10] Then
                    pattern(xmin[2]*charx-1,(ymin[2]+2+i-6)*chary-8,i-6,0);
     {write the marker patterns box, X, diamond, and +}
                End;
            End; {with}
        End; {for}
      TextCol(lightgray);
      Gotoxy(x_y_plot_text[2,1],x_y_plot_text[2,2]);
      write(the_bar,'S',the_bar);  {was 53,6}
      gotoxy(x_y_plot_text[2,1],x_y_plot_text[2,2]+1);
      write(' dB');  {was 53,7}
      If Not(Alt_Sweep) Then
        Begin
          gotoxy(x_y_plot_text[5,1],x_y_plot_text[5,2]);
          write('f  Hz');
        End
      Else
        x_sweep.Label_Axis;  {use alternate sweep data}
    End; {do_time}
  If Not(Alt_Sweep) Then Write_Plot_Prefix(time);  {write x-coordinate prefix}
  Dec(WindMax);  {Restore to normal scrolling}
End; {* Write_Coordinates *}


Procedure Write_BigSmith_Coordinates;

{*
	Write coordinates for the VGA Big Smith window

	Linked list for coordinates has been reduced to
	8 elements (no dBmax, dBmin).
*}

Var 
  i      : integer;
  tcompt : compt;


Begin
  {Erase key area}
  clear_window(xmin[2],ymin[2],xmax[2],ymax[2]); {clear key area}
  TextCol(lightgray);
  Inc(WindMax); {to prevent scrolling}
  For i:=3 To 10 Do
    Begin
      If i=3 Then tcompt := coord_start
      Else tcompt := tcompt^.next_compt;
      With tcompt^ Do
        Begin
          If right Then xp := xorig-Length(descript);
          If (length(descript) > x_block) Or (i < 7) Then
            Begin
              write_compt(lightgray,tcompt);
              If i In [7..10] Then
                pattern(xmin[2]*charx-1,(ymin[2]+2+i-6)*chary-8,i-6,0);
     {write the marker patterns box, X, diamond, and +}
            End;
        End; {with}
    End; {for}
  TextCol(lightgray);
  Gotoxy(x_y_plot_text[4,1],x_y_plot_text[4,2]-1);
  Write('Start');
  Gotoxy(x_y_plot_text[6,1]-4,x_y_plot_text[6,2]-1);
  Write('Stop');
  If Not(Alt_Sweep) Then
    Begin
      Gotoxy(x_y_plot_text[5,1],x_y_plot_text[5,2]);
      Write('f  Hz');
      Write_Plot_Prefix(false);  {write x-coordinate prefix}
    End
  Else
    x_sweep.Label_Axis;  {use alternate sweep data}
  Dec(WindMax);  {Restore to normal scrolling}
End; {* Write_BigSmith_Coordinates *}


Procedure restore_boxO(ij : integer);
{*
	Restore pixels that were covered by marker.
*}

Var 
  nb,k,xn,yn  : integer;

Begin
  For k:=0 To 1 Do
    Begin
      nb := ij+k*max_params;
      If box_filled[nb] Then
        Begin
          xn := box_dot[1,nb];
          yn := box_dot[2,nb];
          PutBox(nb, xn-4, yn-4, 9, 9);
        End; {if box_filled}
    End; {for k}
End; {restore_boxO}


Procedure move_boxO(xn,yn,nb : integer);
{*
	Move marker by first storing the dots that will be covered.
	EGA routine saves in an array.
*}



Begin
  box_filled[nb] := true;
  box_dot[1,nb] := xn;
  box_dot[2,nb] := yn;
  GetBox(nb, xn-4, yn-4, 9, 9);
End; {move_boxO}


Procedure draw_ticksO(x1,y1,x2,y2 : integer; incx,incy : double);
{*
	Draw ticks on rectangular plot.
*}

Var 
  i,xinc,yinc : integer;

Begin
  SetLineStyle(UserBitLn,$8888,NormWidth); {was 8080}
  SetCol(Green);
  For i:=1 To 9 Do
    Begin
      xinc := Round(i*(x2-x1)/10.0);
      yinc := Round(i*(y2-y1)/5.0);
      Line(x1+xinc,y1-1,x1+xinc,y2);
      If (i<5) Then Line(x1,y1+yinc,x2-1,y1+yinc);
    End; {for}
  SetLineStyle(SolidLn,0,NormWidth);
End; {draw_ticksO}


Procedure Write_File_Name(fname : file_string);
{*
	Write file name above Parts.
	Remove any subdirectory information and .puf
*}

Var 
  i          : integer;
  temp_str   : string[19];

Begin
  {Erase old file name}
  GotoXY(filename_position[1],filename_position[2]);
  For i:=filename_position[1] To filename_position[3] Do
    write(' ');
  {Remove dir from filename}
  Repeat
    i := Pos('\',fname);
    If i > 0 Then Delete(fname,1,i);
  Until i=0;
  {Write filename on screen}
  temp_str := 'file : '+fname;
  TextCol(col_window[1]);
  GotoXY(filename_position[1]+(filename_position[3]-filename_position[1]-Length(temp_str)) div 2,
  filename_position[2]);
  Write(temp_str);
End; {* Write_File_Name *}


Procedure calc_posO(x,y,theta,scf: double; sfreq: integer; dash: boolean);

{*
	Given the complex s-parameter co(x,y):=rho find where the dot 
	should be plotted on screen. Plotting parameters which are 
	returned are (spx,spy) for the Smith plot and (spp) for the
	rectangular plot. Clipping is also performed here by checking
	the values of the returned parameters to see if they lie within
	the limits of symin,symax and xmin[8],xmax[8]. If not they are
	put at ymax[8] and ymin[8].

	Screen magnification set by:
	if its_EGA then scf:=1 else scf:=hir;
	in Smith_and_Magplot
*}

Var 
  p2,p3,p4 : double;

Begin
  p2 := sqr(x)+sqr(y);
  If sqrt(p2)<1.02*rho_fac Then
    Begin
      spline_in_smith := true;
      If abs(theta) > 0 Then
        Begin

(**disabled*** 
	  thet:=theta*freq/design_freq;
	  sint:=sin(thet);  
	  cost:=cos(thet);
	  spx:=Round(centerx+(x*cost-y*sint)*rad/rho_fac);
	  spy:=Round((centery-(x*sint+y*cost)*rad*yf/rho_fac))*scf); 
	  **disabled***)
        End
      Else
        Begin
          spx := Round(centerx+(x*rad/rho_fac));
          spy := Round((centery-(y*rad*yf/rho_fac))*scf);
        End;
    End
  Else
    spline_in_smith := false;  {* end if sqrt(p2)<1.02*rho_fac *}
  If p2 > 1.0/infty Then
    Begin
      p4 := Ln(p2);
{!*	was Ln_Asm
				When compiled in the $N+ mode this
				Ln function worked only intermitently. 
				The Ln function has therefore been 
				rewritten in assembler. *!}

      p3 := 10.0 * p4 / ln10 ; {10*log(p2)}
      p2 := p3;
    End
  Else
    p2 := -1.0*infty;
  If betweenr(symin,p2,symax,sigma) Then
    Begin {check to see if it fits }
      If Not(Large_Smith) Then spline_in_rect := true;
      spp := Round((ymax[8]-(p2-symin)*sfy1)*scf);
    End
  Else
    Begin
      spline_in_rect := false;
      If p2 > symax Then
        spp := Round((ymin[8]-5)*scf)  {Put just at the top of the graph}
      Else         { was ymin[8]-5 and ymax[8]+5 }
        spp := Round((ymax[8]+5)*scf); {Put at the bottom of the graph}
    End; {else}
  If dash And Not(betweeni(xmin[8],sfreq,xmax[8])) Then
    Begin
      spline_in_rect := false;
      spline_in_smith := false;
    End;
End; {calc_posO}


{***********************************************************************}

Procedure Smith_and_Magplot(lighten,dash,boxes : boolean);

{* 
	Plot s-parameter curves.  This is done after all
	the data points have been calculated
	from the Analysis procedure.

	Now includes Smith_PlotO, Rect_PlotO, SplineO
*}

Var 
  jxsdif,scf,cx1,cx2,cx3,cx4,cy1,
  cy2,cy3,cy4,sqfmfj,sqfjmf,fmfj,
  fjmf,spar1,spar2    : double;
  sfreq,jfreq,j,nopts,ij,col,txpt  : integer;
  line_s,line_r    : boolean;
  cplt             : plot_param;
  cspc             : spline_param;

   {****************************************************************}

Procedure splineO(ij : integer);
 {*
	Calculate spline coefficients. 
	Johnson and Riess Numerical Analysis p41,241.
	*}

Var 
  zx,zy,u : array[0..1000] Of double;
  m,i     : integer;
  li      : double;
  cplt    : plot_param;
  cspc    : spline_param;

Begin {SplineO}
  m := npts-1;
  For i:=0 To m Do
    Begin
      If i=0 Then
        Begin
          cplt := plot_start[ij];
          cspc := spline_start;
        End
      Else
        Begin
          cplt := cplt^.next_p;
          cspc := cspc^.next_c;
        End;
      With cspc^ Do
        With cplt^ Do
          Begin
            h := sqrt(sqr(yf*(next_p^.y-y))+sqr(next_p^.x-x));
            If h<0.000001 Then h := 0.000001;
          End;
    End; {for i:=0 to m}
  spline_end := cspc^.next_c;
  cplt := plot_start[ij];
  cspc := spline_start;
  u[1] := 2*(cspc^.next_c^.h+cspc^.h);                   {u_11=a_11}
  zx[1] := 6*((cplt^.next_p^.next_p^.x-cplt^.next_p^.x)/cspc^.next_c^.h
           -(cplt^.next_p^.x-cplt^.x)/cspc^.h);   {y_1=b_1}
  zy[1] := 6*((cplt^.next_p^.next_p^.y-cplt^.next_p^.y)/cspc^.next_c^.h
           -(cplt^.next_p^.y-cplt^.y)/cspc^.h);   {y_1=b_1}
  For i:= 2 To m Do
    Begin
      cplt := cplt^.next_p;
      cspc := cspc^.next_c;
      With cspc^ Do
        With cplt^ Do
          Begin
            li := h/u[i-1];      {a_i-1i=a_ii-1=h_i-1,a_ii=2(h_i+h_i-1)}
            u[i] := 2*(next_c^.h+h)-h*li;   {u_ii=a_ii-L_i.i-1a_i-1,i}
            zx[i] := 6*((next_p^.next_p^.x-next_p^.x)/next_c^.h-
                     (next_p^.x-x)/h)-li*zx[i-1];                 {2.33}
            zy[i] := 6*((next_p^.next_p^.y-next_p^.y)/next_c^.h-
                     (next_p^.y-y)/h)-li*zy[i-1];
          End; {with}
    End; {for i}
  cspc := spline_end;
  cspc^.sx := 0;
  cspc^.sy := 0;
  cspc := cspc^.prev_c;
  cspc^.sx := zx[m]/u[m];
  cspc^.sy := zy[m]/u[m];
  For i:=1 To m-1 Do
    Begin
      cspc := cspc^.prev_c;
      With cspc^ Do
        Begin
          sx := (zx[m-i]-h*next_c^.sx)/u[m-i];
          sy := (zy[m-i]-h*next_c^.sy)/u[m-i];
        End;
    End;
  cspc := cspc^.prev_c;
  cspc^.sx := 0;
  cspc^.sy := 0;
End; {splineO}

 {**************************************************************}

Procedure smith_plotO(x1,y1,col : integer; Var linex : boolean);
 {*
	     Plot curve on Smith plot
	*}
Begin {Smith_PlotO}
  If spline_in_smith Then
    Begin
      If linex Then
        Begin
          SetCol(col);
          Line(xvalo[1],yvalo[1],x1,y1);
        End; {if linex}
      linex := true;
    End {if spline_}
  Else
    linex := false;
  xvalo[1] := x1;
  yvalo[1] := y1;
End; {smith_plotO}

 {************************************************************}

Procedure rect_plotO(x1,y1,col : integer;Var linex : boolean);

{*
	Line plotting routine for making curves in
	the rectangular plot. y1 is usually equal to spp.
	*}

Begin {Rect_PlotO}
  SetViewPort(xmin[8],ymin[8]-1,xmax[8],ymax[8],true);
     { clip rectangular plot, plot with relative positioning, }
     { and reset the graphics pointer }
  If linex Then
    Begin
      SetCol(col);
      Line(xvalo[2]-xmin[8],yvalo[2]-ymin[8]+1,x1-xmin[8],y1-ymin[8]+1);
    End;
  linex := true;
  SetViewPort(xmin[12],ymin[12],xmax[12],ymax[12],false); {Remove clipping}
  xvalo[2] := x1;
  yvalo[2] := y1;
End; {rect_plotO}

 {**********************************************************}

Begin  {* Smith_and_Magplot *}
  jxsdif := sfx1*finc; {difference in x between plot points}
  scf := 1;
  If npts > 1 Then
    For ij:=1 To max_params Do
      If s_param_table[ij]^.calc Then
        Begin
          splineO(ij);
          col := s_color[ij];
          If lighten Then col := col-8;
          line_s := false;
          line_r := false;
          For txpt:=0 To npts Do
            Begin

(*	   if keypressed then begin
		key := ReadKey;
		if key in['h','H'] then begin
		   message[2]:='      HALT       ';
		   write_message;
		   exit;
		end; {if key in}
		beep;
	   end;{if key_pressed}  *)
              If txpt=0 Then
                Begin
                  cplt := plot_start[ij];
                  cspc := spline_start;
                End
              Else
                Begin
                  cplt := cplt^.next_p;
                  cspc := cspc^.next_c;
                End;
              freq := fmin+txpt*finc;
              sfreq := xmin[8]+Round((freq-sxmin)*sfx1);
              If cplt^.filled Then
                Begin
                  calc_posO(cplt^.x,cplt^.y,0,scf,sfreq,dash);
                  If Not(Large_Smith) Then
                    Begin
                      rect_plotO(sfreq,spp,col,line_r);
                      If spline_in_rect And boxes Then
                        box(sfreq,Round(spp/scf),ij);
                    End;
                  smith_plotO(spx,spy,col,line_s);
                  If spline_in_smith And boxes Then box(spx,Round(spy/scf),ij);
                  If txpt < npts Then
                    With cspc^ Do
                      With cplt^ Do
                        Begin
                          cx1 := sx/(6*h);
                          cx2 := next_c^.sx/(6*h);
                          cy1 := sy/(6*h);
                          cy2 := next_c^.sy/(6*h);
                          cx3 := next_p^.x/h-next_c^.sx*h/6;
                          cx4 := x/h-sx*h/6;
                          cy3 := next_p^.y/h-next_c^.sy*h/6;
                          cy4 := y/h-sy*h/6;
                          If h*rad/rho_fac>40 Then nopts := 10
                          Else nopts := Round(h*rad/(rho_fac*4))+1;
                          For j:=1 To nopts-1 Do
                            Begin
                              fmfj := j*h/nopts;
                              fjmf := h-fmfj;
                              sqfmfj := sqr(fmfj);
                              sqfjmf := sqr(fjmf);
                              spar1 := (cx1*sqfjmf+cx4)*fjmf
                                       +(cx2*sqfmfj+cx3)*fmfj;
                              spar2 := (cy1*sqfjmf+cy4)*fjmf
                                       +(cy2*sqfmfj+cy3)*fmfj;
                              jfreq := Round(j*jxsdif/nopts);
                              calc_posO(spar1,spar2,0,scf,sfreq+jfreq,dash);
                              If Not(Large_Smith) Then
                                rect_plotO(sfreq+jfreq,spp,col,line_r);
                              smith_plotO(spx,spy,col,line_s);
                            End; {j:=1 to nopts-1}
                        End;{if txpt}
                End;{if cpt^ filled}
            End;{for txpt}
        End; {ij}
End; {*Smith_and_Magplot*}

{***************************************************************************}


Procedure Draw_Graph(x1,y1,x2,y2 : integer; time : boolean);
{*
	Draw rectangular graph.
*}
Begin
  clear_window_gfx(xmin[11],ymin[11],xmax[11],ymax[11]);
   {erase previous graph}

  If Not(time) Then
    clear_window(xmin[2],ymin[2],xmax[2],ymax[2]); {clear key area}
  TextCol(lightgray);
  Write_Coordinates(time);
  draw_box(x1,y1,x2,y2,lightgreen);
  draw_ticksO(x1,y1,x2,y2,(x2-x1)/4.0,(y2-y1)/4.0);
End; {* Draw_Graph *}


{******************  START COMPONENT MANIPULATION   ****************}


Procedure del_char(tcompt : compt);
{*
	Delete character -- Del.
*}
Begin
  If (window_number=2) Then Inc(WindMax); {prevent scrolling}
  tcompt^.changed := true;
  delete(tcompt^.descript,cx+1,1);
  write_compt(lightgray,ccompt);
  write(' ');
  gotoxy(tcompt^.xp+cx,tcompt^.yp);
  If (window_number=2) Then Dec(WindMax); {allow scrolling}
End; {del_char}


Procedure back_char(tcompt : compt);
{*
	Backspace and delete character.
*}
Begin
  If cx > tcompt^.x_block Then
    Begin
      gotoxy(tcompt^.xp+cx,tcompt^.yp);
      cx := cx-1;
      del_char(tcompt);
    End;
End; {back_char}


Procedure add_char(tcompt : compt);
{*
	Add character to parameter or part.
	Allows only 1..4 to be added to s-parameters
*}

Var 
  i,lendes  : integer;
  an_s  : boolean;

Begin
  TextCol(white);
  an_s := false;
  For i:= 1 To 4 Do
    Begin
      If (s_param_table[i]=tcompt) Then an_s := true;
    End;
  If an_s And Not(key In [' ','1'..'4']) Then beep
   {ignore if not 1..4 for S's}
  Else With tcompt^ Do
         Begin
           If Not(insert_key) Then delete(descript,cx+1,1);
           insert(key,descript,cx+1);
           lendes := length(descript) ;
           If lendes > xmaxl Then
             Begin
               erase_message;
               message[2] := 'Line too long';
               delete(descript,lendes,1);
               write_message;
             End;
           cx := cx+1;
           If cx > xmaxl Then cx := cx-1;
           If (window_number=2) Then Inc(WindMax); {prevent scrolling}
           If right Then
             If (xp+length(descript)-1 >= xorig) Or (xp+cx >= xorig) Then
               Begin
                 gotoxy(xorig-1,yp);
                 write(' ');
                 xp := xp-1;
               End;
           write_compt(lightgray,tcompt);
           changed := true;
           gotoxy(xp+cx,yp);
           If (window_number=2) Then Dec(WindMax); {allow scrolling}
         End; {else with tcompt}
End; {add_char}


Procedure Choose_Part(ky : char);
{*
	Select one of the parts [a..r].
*}

Var 
  tcompt : compt;
  found  : boolean;

Begin
  If ky In ['A'..'R'] Then ky := char(ord(ky)+32);
  tcompt := Nil;
  found := false;
  missing_part := false;
  Repeat
    If tcompt=Nil Then tcompt := part_start
    Else tcompt := tcompt^.next_compt;
    If (tcompt^.descript[1]=ky) And tcompt^.parsed Then found := true
  Until (tcompt^.next_compt=Nil) Or found;
  If found And Not((ky In ['j'..'r']) And Not(Large_Parts)) Then
    Begin
      write_compt(lightgray,compt1);
      compt1 := tcompt;
      write_compt(white,compt1);
    End
  Else
    Begin
      message[1] := ky+' is not a';
      message[2] := 'valid part';
      update_key := false;
      missing_part := true;
    End;
End; {* Choose_Part *}

{*******************  CIRCUIT DRAWING Functions ******************}

Procedure Draw_Net(tnet : net);
{*
	Calls routine to draw net on circuit board.
	Drawing routines are in PFUN2
*}
Begin
  lengthxy(tnet);
  If read_kbd Or demo_mode Then
    Case tnet^.com^.typ Of 
      't'  : Draw_tline(tnet,true,false);
      'q'  : Draw_tline(tnet,true,false);
      'l'  : Draw_tline(tnet,false,false);
      'x'  : Draw_xformer(tnet); {transformer}
      'a'  : Draw_tline(tnet,false,false); {attenuator}
      'd','i'  : Draw_device(tnet);
      'c'  :
             Begin
               Draw_tline(tnet^.other_net,true,false);
               Draw_tline(tnet,true,true);
             End;
    End; {case}
End; {* Draw_Net *}


Function con_found : boolean;

{*
	Looks for ccon on cnet in direction of arrow. 
	On exit cnet=network to remove or step over. 
	If ccon is connected to an external port then
	cnet is unchanged.
*}

Var 
  found : boolean;

Begin
  ccon := Nil;
  found := false;
  port_dirn_used := false;
  If cnet <> Nil Then
    Begin
      Repeat
        If ccon = Nil Then ccon := cnet^.con_start
        Else ccon := ccon^.next_con;
        If (dirn And ccon^.dir) > 0 Then found := true;
      Until found Or (ccon^.next_con=Nil);
      If found Then
        Begin
          If ext_port(ccon) Then
            Begin
              message[1] := 'Cannot go over';
              message[2] := 'path to port';
              port_dirn_used := true;
              update_key := false;
            End
          Else     {* Delete to disallow "Paths over ports" *}
            cnet := ccon^.mate^.net;
        End; {if found}
    End; {if cnet}
  con_found := found;
End; {con_found}


Function new_net(ports : integer; choice : boolean) : net;

{*
	Makes a new network on the end of the linked list.
	If choice then network is node else network is part.
*}

Var 
  tnet : net;

Begin
  If net_start = Nil Then
    Begin
      New_n(net_start);
      tnet := net_start;
    End
  Else
    Begin
      tnet := net_start;
      While tnet^.next_net <> Nil Do
        tnet := tnet^.next_net;
      New_n(tnet^.next_net);
      tnet := tnet^.next_net;
    End;
  With tnet^ Do
    Begin
      next_net := Nil;
      node := choice;
      con_start := Nil;
      ports_connected := 0;
      number_of_con := ports;
      xr := xm;
      yr := ym;
      If node Then
        Begin
          grounded := false;
          com := Nil;
        End
      Else
        com := compt1;
    End;{with}
  new_net := tnet;
  If Not(tnet^.node)Then
    If compt1^.typ = 'c' Then
      Begin
        New_n(tnet^.other_net);
        tnet := tnet^.other_net;
        With tnet^ Do
          Begin
            com := compt1;
            dirn_xy;
            xr := xm+yii*compt1^.con_space;
            yr := ym+xii*compt1^.con_space;
          End; {with}
      End; {if ccompt1}
End; {new_net}

Procedure dispose_net(vnet : net);
{*
	Remove a network form the linked list.
*}

Var 
  found : boolean;
  tnet  : net;

Begin
  tnet := Nil;
  found := false;
  Repeat
    If tnet = Nil Then
      Begin
        tnet := net_start;
        If tnet=vnet Then
          Begin
            net_start := net_start^.next_net;
            tnet := net_start;
            found := true;
          End {if tnet=vnet}
      End
    Else
      Begin {if tnet <> nil}
        If tnet^.next_net=vnet Then
          Begin
            found := true;
            tnet^.next_net := tnet^.next_net^.next_net
          End
        Else
          tnet := tnet^.next_net
      End {if tnet <> nil}
  Until found Or (tnet^.next_net=Nil);
  If Not(found) Then
    Begin
      message[2] := 'dispose_net';
      shutdown;
    End;
End; {dispose_net}


Function new_con(tnet : net; dirt : integer) : conn;
{*
	Make a new connector.
*}

Var 
  tcon : conn;

Begin
  If tnet^.con_start=Nil Then
    Begin
      New_conn(tnet^.con_start);
      tcon := tnet^.con_start;
    End
  Else
    Begin
      tcon := tnet^.con_start;
      While tcon^.next_con <> Nil Do
        tcon := tcon^.next_con;
      New_conn(tcon^.next_con);
      tcon := tcon^.next_con;
    End;
  With tcon^ Do
    Begin
      port_type := 0;
      next_con := Nil;
      net := tnet;
      cxr := xm;
      dir := dirt;
      cyr := ym;
    End; {with tcon^}
  With tnet^ Do
    If node And (number_of_con > 1) Then
      Begin
        xr := (xr*(number_of_con-1)+xm)/number_of_con;
        yr := (yr*(number_of_con-1)+ym)/number_of_con;
      End;
  new_con := tcon;
End; {new_con}


Procedure dispose_con(vcon : conn);
{*
	Dispose a connector.
*}

Var 
  found : boolean;
  tcon  : conn;
  vnet  : net;
  i     : integer;

Begin
  tcon := Nil;
  found := false;
  vnet := vcon^.net;
  vnet^.number_of_con := vnet^.number_of_con-1;
  If vnet^.number_of_con=0 Then
    dispose_net(vnet)
  Else
    Begin
      Repeat
        If tcon = Nil Then
          Begin
            tcon := vnet^.con_start;
            If tcon=vcon Then
              Begin
                vnet^.con_start := vcon^.next_con;
                found := true
              End
          End
        Else
          Begin
            If tcon^.next_con=vcon Then
              Begin
                found := true;
                tcon^.next_con := tcon^.next_con^.next_con
              End
            Else
              tcon := tcon^.next_con
          End;
      Until found Or (tcon^.next_con=Nil);
      If Not(found) Then
        Begin
          message[2] := 'dispose_con';
          shutdown;
        End;
    End; {if vcon}
  With vnet^ Do
    If node And (number_of_con > 0) Then
      For i:=1 To number_of_con Do
        Begin
          If i=1 Then
            Begin
              tcon := vnet^.con_start;
              xr := 0;
              yr := 0;
            End
          Else
            tcon := tcon^.next_con;
          xr := xr+tcon^.cxr/number_of_con;
          yr := yr+tcon^.cyr/number_of_con;
        End; {for i}
End; {dispose_con}


Procedure Draw_Port(mnet : net; col : integer);
{*
	Draws a small box and number for an external port.
*}

Var 
  x,y,i,yj : integer;

Begin
  SetCol(col);
  x := xmin[1]+Round(mnet^.xr/csx);
  y := ymin[1]+Round(mnet^.yr/csy);
  i := 0;
  yj := 0;
  Case mnet^.ports_connected Of 
    1,3 :
          Begin
            SetTextJustify(RightText,CenterText);  {i:= 0;}
            i := -3;
          End;
    2,4 :
          Begin
            SetTextJustify(LeftText,CenterText);  {i:= 2;}
            i := 5;
          End;
  End; {case}
  yj := y;
  OutTextXY(x+i,yj,Chr(48+mnet^.ports_connected)); {write number}
  fill_box(x-2,y-2,x+2,y+2,col);
End; {draw_port}


Procedure draw_to_port(tnet : net; port_number : integer);
{*
	Draws a connectinon to an external port.
*}

Var 
  xp,yp,offset,xli,yli,xsn,ysn : integer;

Begin
  portnet[port_number]^.node := true;
  xsn := cwidthxZ02;
  ysn := cwidthyZ02;
  Case port_number Of 
    1,3 : offset := 2;
    2,4 :
          Begin
            offset := -2;
            xsn := -xsn
          End;
  End;{case}
  xli := Round(tnet^.xr/csx)+xmin[1];
  yli := Round(tnet^.yr/csy)+ymin[1];
  xp := Round(portnet[port_number]^.xr/csx)+offset+xmin[1];
  yp := Round(portnet[port_number]^.yr/csy)+ymin[1];
  If yli < yp Then ysn := -ysn;
  If abs(tnet^.yr - portnet[port_number]^.yr) < widthz0/2.0 Then
    Begin
      puff_draw(xp,yp+ysn,xli,yp+ysn,lightgray);
      puff_draw(xli,yp-ysn,xli,yp+ysn,lightgray);
      puff_draw(xp,yp-ysn,xli,yp-ysn,lightgray);
    End
  Else
    Begin
      puff_draw(xli-xsn,yli,xli+xsn,yli,lightgray);
      puff_draw(xli+xsn,yli,xli+xsn,yp,lightgray);
      puff_draw(xli+xsn,yp,xli,yp-ysn,lightgray);
      puff_draw(xli,yp-ysn,xp,yp-ysn,lightgray);
      puff_draw(xp,yp+ysn,xli-xsn,yp+ysn,lightgray);
      puff_draw(xli-xsn,yp+ysn,xli-xsn,yli,lightgray);
    End;
  Draw_port(portnet[port_number],LightRed)
End; {draw_to_port}


Procedure draw_ports(tnet : net);
{*
	Loops over tnet's connections to external ports.
*}

Var 
  tcon : conn;

Begin
  tcon := Nil;
  Repeat
    If tcon=Nil Then tcon := tnet^.con_start
    Else tcon := tcon^.next_con;
    If ext_port(tcon) Then draw_to_port(tnet,tcon^.port_type);
  Until tcon^.next_con=Nil;
End; {draw_ports}


Procedure node_look;
{*
	Looks for a node at current cursor postion.
*}

Var 
  tnet : net;

Begin
  cnet := Nil;
  tnet := Nil;
  If net_start <> Nil Then
    Repeat
      If tnet = Nil Then tnet := net_start
      Else tnet := tnet^.next_net;
      With tnet^ Do
        If (con_start <> Nil) Then
          Begin
            If (abs(con_start^.cxr-xm)< resln) And node And
               (abs(con_start^.cyr-ym)< resln) Then
              Begin
                cnet := tnet;
                exit;
              End;
          End;
    Until tnet^.next_net=Nil;
End; {node_look}


Procedure goto_port(port_number : integer);
{*
	Go to an external port.
*}
Begin
  xm := portnet[port_number]^.xr;
  ym := portnet[port_number]^.yr;
  If port_number=0 Then
    Begin
      xrold := xm;
      yrold := ym;
    End;
  xi := Round(xm/csx);
  yi := Round(ym/csy);
  node_look;
End; {goto_port}


Procedure new_port(x,y : double; port_number : integer);
{*
	Make a new external port.
*}
Begin
  New_n(portnet[port_number]);
  With portnet[port_number]^ Do
    Begin
      next_net := Nil;
      number_of_con := 0;
      con_start := Nil;
      xr := x;
      yr := y;
      ports_connected := port_number;
      node := false; {not_connected yet}
    End; {with}
End; {new port}


Procedure Draw_Circuit;
{* 
	Draw the entire circuit.
*}

Var 
  tnet   : net;
  port_number,
  xb,yb,xo,yo   : integer;

Begin
  xo := xmin[1];
  xb := Round(bmax/csx)+xo;
  yo := ymin[1];
  yb := Round(bmax/csy)+yo;

  {* Clear Layout screen *}
  clear_window_gfx(xmin[9],ymin[9],xmax[9],ymax[9]);
  Draw_Box(xo,yo-7,xb,yb+2,col_window[1]);
  Draw_Box(xo,yo-5,xb,yb,col_window[1]);
  {* Draw double box to look like text border *}
  Write_Compt(col_window[1],window_f[1]);
  {* write "LAYOUT" header *}
  If net_start= Nil Then
    Begin
      new_port(bmax/2.0,bmax/2.0,0);
      new_port(0.0,(bmax-con_sep)/2.0,1);
      new_port(bmax,(bmax-con_sep)/2.0,2);
      min_ports := 2;
      If con_sep <> 0 Then
        Begin
          new_port(0.0,(bmax+con_sep)/2.0,3);
          new_port(bmax,(bmax+con_sep)/2.0,4);
          min_ports := 4;
        End;
    End; {if net_start}
  For port_number:=1 To min_ports Do
    draw_port(portnet[port_number],Brown);
  If net_start <> Nil Then
    Begin
      tnet := Nil;
      iv := 1;
      Repeat
        If tnet=Nil Then tnet := net_start
        Else tnet := tnet^.next_net;
        dirn := tnet^.con_start^.dir;
        If tnet^.node Then
          Begin
            If tnet^.grounded Then draw_groundO(tnet^.xr,tnet^.yr)
          End
        Else
          Draw_Net(tnet);
      Until tnet^.next_net = Nil;
      tnet := Nil;
      Repeat
        If tnet=Nil Then tnet := net_start
        Else tnet := tnet^.next_net;
        If tnet^.ports_connected > 0 Then draw_ports(tnet);
      Until tnet^.next_net = Nil;
      xi := Round(xm/csx);
      yi := Round(ym/csy);
    End
  Else {if net_start=nil}
    goto_port(0);
End; {draw_circuit}


Function off_boardO(step_size : double) : boolean;
{*
	Check to see if part will fit on circuit board.
*}

Var 
  xrep,yrep,xrem,yrem : double;
  off_boardt   : boolean;

Begin
  dirn_xy;
  With compt1^ Do
    If step_size=1 Then
      Begin
        xrep := xm+lngth*xii+yii*(width/2.0+con_space);
        yrep := ym+lngth*yii+xii*(width/2.0+con_space);
        xrem := xm+lngth*xii-yii*width/2.0;
        yrem := ym+lngth*yii-xii*width/2.0;
        If betweenr(0,xrep,bmax,0) And betweenr(0,yrep,bmax,0)
           And betweenr(0,xrem,bmax,0) And betweenr(0,yrem,bmax,0)
          Then off_boardt := false
        Else off_boardt := true;
      End
    Else
      Begin {if step_size<>1}
        xrep := xm+(lngth*xii+yii*con_space)/2.0;
        yrep := ym+(lngth*yii+xii*con_space)/2.0;
        If  betweenr(0,xrep,bmax,0) And betweenr(0,yrep,bmax,0)
          Then off_boardt := false
        Else off_boardt := true;
      End; {else,with}
  If off_boardt Then
    Begin
      If Not(read_kbd) Then
        Begin
          key := F3;
          read_kbd := true;
          compt3 := compt1;
          cx3 := compt3^.x_block;
          draw_circuit;
        End;
      erase_message;
      message[1] := 'The part lies';
      message[2] := 'outside the board';
      update_key := false;
    End; {if off_}
  off_boardO := off_boardt;
End; {off_boardO}

{*********************************************************************}

Procedure Get_Key;

{*
	Get key from keyboard. See Turbo manual Appendix K.

	Includes Draw_Cursor, Erase_Cursor, and Ggotoxy
*}

Label 
  end_blink;

Var 
  cursor_displayed  : boolean;
  key_ord  : integer;




    {***************************************************}

Procedure Draw_Cursor;
{*
	Draw circuit cursor X by first storing
	the dots that will be covered.
*}

Var 
  i,j,x_ii,y_ii,xo,yo : integer;

Begin
  cross_dot[1] := xi+xmin[1];
  cross_dot[2] := yi+ymin[1];
  j := 4;
  xo := cross_dot[1];
  yo := cross_dot[2];
  GetBox(0, xo-5, yo-4, 11, 9);
  PutPixel(xo,yo,white);
  x_ii := 1;
  y_ii := 1;
  For i:=1 To 8 Do
    Begin
      PutPixel(xo+x_ii,yo+y_ii,white);
      PutPixel(xo+x_ii,yo-y_ii,white);
      PutPixel(xo-x_ii,yo+y_ii,white);
      PutPixel(xo-x_ii,yo-y_ii,white);
      If odd(i) Then x_ii := x_ii+1
      Else y_ii := y_ii+1;
      j := j+4;
    End;
End; {Draw_Cursor}

  {*****************************************************}

Procedure Erase_Cursor;
{*
	Erase cursor and restore covered pixels.
*}

Var 
  xo,yo  : integer;

Begin
  xo := cross_dot[1];
  yo := cross_dot[2];
  PutBox(0, xo-5, yo-4, 11, 9);
End; {Erase_Cursor}

  {******************************************************}

Procedure ggotoxy(Var cursor_displayed : boolean);
{*
	Activate flashing cursor.
*}

Var 
  x,y,i,imax : integer;

Begin
  If ccompt <> Nil Then
    Begin
      x := ccompt^.xp+cx;
      If (x > Max_Text_X) Then x := Max_Text_X;
      y := ccompt^.yp;
      If cursor_displayed Then
        Begin
          Inc(WindMax); {prevent scrolling}
          TextCol(lightgray);
          If (cx >= length(ccompt^.descript)) Then
            Write(' ')
          Else
            Write(ccompt^.descript[cx+1]);
          GotoXY(x,y);
          Dec(WindMax); {allow scrolling}
        End
      Else
        Begin
          GotoXY(x,y);
          If insert_key Then imax := 6
          Else imax := 2;
          SetCol(white);
          For i:=imin To imax Do
            Line(charx*(x-1),chary*y-i-2,charx*x-2,chary*y-i-2);
        End; {if cursor_displayed}
      cursor_displayed := Not(cursor_displayed);
    End; {if ccompt <> nil}
End; {ggotoxy}

  {********************************************************}

Begin  {* Get_Key *}
  If read_kbd Then
    Begin
      If demo_mode Then
        Begin
          readln(key_ord);
          key := char(key_ord)
        End
      Else
        Begin
          cursor_displayed := false;
          If window_number=1 Then Draw_Cursor
          Else ggotoxy(cursor_displayed);
          If Not(keypressed) Then   {blink cursor}
            If window_number <> 1 Then
              Repeat
                Delay (200);
                If  keypressed Then goto end_blink;
                ggotoxy(cursor_displayed);
              Until false;
          end_blink:
                     key := ReadKey;
          If key=Alt_o Then key := Omega;  {Ohms symbol}
          If key=Alt_d Then key := Degree;
          If (window_number=2) Then
            Begin
              If key=Alt_s Then key := Mu;
            End
          Else
            If key=Alt_m Then key := Mu;  {! conflict with sh_down}
          If key=Alt_p Then key := Parallel;
          If window_number=1 Then
            Erase_Cursor
          Else
            If cursor_displayed Then ggotoxy(cursor_displayed);
        End; {if demo}
    End   {if read_kbd}
  Else
    Begin    {redraw_circuit}
      If key_i > 0 Then
        If key_list[key_i].noden <> node_number Then
          Begin
            key := F3;
            read_kbd := true;
            compt3 := compt1;
            cx3 := compt3^.x_block;
            draw_circuit;
            message[1] := 'Circuit changed';
            message[2] := 'Edit part or';
            message[3] := 'erase circuit';
            exit;
          End;
      key_i := key_i+1;
      If key_i > key_end Then
        Begin {end of redraw}
          read_kbd := true;
          key := key_o;
          circuit_changed := false;
          board_changed := false;
          draw_circuit;
        End
      Else
        key := key_list[key_i].keyl;
  {Apply appropriate draw function from keylist}
    End; {read_kbd}
End; {* Get_Key *}

{*****************************************************************}

Procedure ground_node;
{*
	Ground a node.
*}
Begin
  If cnet <> Nil Then With cnet^ Do
                        If Not(grounded) Then
                          Begin
                            grounded := true;
                            draw_groundO(xr,yr);
                          End;
End; {ground_node}


Procedure unground;
{*
	Remove a ground.
*}
Begin
  If cnet <> Nil Then With cnet^ Do
                        If grounded Then
                          Begin
                            grounded := false;
                            If read_kbd Then draw_circuit;
                          End;
End; {unground}


Procedure join_port(port_number,ivt : integer);
{*
	Join cnet to an external port.
*}

Var 
  found : boolean;
  tcon  : conn;
  dirt  : integer;

Begin
  If port_number <= min_ports Then
    If ivt=1 Then
      Begin {connect}
        If ym > portnet[port_number]^.yr Then dirt := 1
        Else dirt := 8;
        If abs(ym - portnet[port_number]^.yr) < widthz0/2.0 Then
          Case port_number Of 
            1,3 : dirt := 4;
            2,4 : dirt := 2;
          End; {case}
        If Not(portnet[port_number]^.node) Then
          Begin
            If cnet = Nil Then cnet := new_net(0,true);
            portnet[port_number]^.node := true;
            If read_kbd Or demo_mode Then draw_to_port(cnet,port_number);
            tcon := new_con(cnet,dirt);
            cnet^.ports_connected := cnet^.ports_connected+1;
            tcon^.port_type := port_number;
            tcon^.mate := Nil;
            cnet^.number_of_con := cnet^.number_of_con+1;
          End
        Else
          Begin
            message[1] := 'Port '+char(port_number+ord('0'))+' is';
            message[2] := 'already joined';
          End;
      End
  Else
    Begin     {erase}
      iv := 0;     {added for dx_dy}
      tcon := Nil;
      found := false;
      If cnet <> Nil Then
        Repeat
          If tcon = Nil Then tcon := cnet^.con_start
          Else tcon := tcon^.next_con;
          If tcon^.port_type=port_number Then found := true;
        Until found Or (tcon^.next_con=Nil);
      If found Then
        Begin
          cnet^.ports_connected := cnet^.ports_connected-1;
          dispose_con(tcon);
          Node_Look;
          portnet[port_number]^.node := false;
          If read_kbd Then Draw_Circuit;
        End
      Else
        Goto_Port(port_number);
    End; {else ivt}
End; {join_port}

End.
