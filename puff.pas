{$R-}    {Range checking}
{$S-}    {Stack checking}
{$B-}    {Boolean complete evaluation or short circuit}
{$I+}    {I/O checking on}



{**********************************************************************

Puff

        This code is now licenced under GPLv3.

	Copyright (C) 1991, S.W. Wedge, R.C. Compton, D.B. Rutledge.
        Copyright (C) 1997,1998, A. Gerstlauer.

	Last Modifications made by Andreas Gerstlauer, 10/98
	Last compiled with Borland Turbo Pascal 7.01

        Modifications for Linux compilation 2000-2007 Pieter-Tjerk de Boer.

	Code cleanup for Linux only build 2009 Leland C. Scott.
 
	Original code released under GPLv3, 2010, Dave Rutledge.


	NOTES:

	Code now in external units:
	* Artwork routines
	* Puff initialization
	* Puff FFT routines
	* Smith Chart code
	* Disk I/O

        PUFF.PAS Main program unit contains:
	* Main analysis routines
 	* Main circuit drawing functions
	* Main flow of control

************************************************************************}

Program PUFF;

Uses 
dos,
xgraph, {Custom replacement for TUBO's "Crt" and "Graphics" units}
initc,
pfun1,
pfun2,
pfun3,
pfart,  {artwork code}
pfrw,   {puff file read/write code}
pfst,   {puff start code}
pfmsc,  {Smith chart, help, and device file reading}
pffft;  {puff FFT code}

Procedure Pick_Smith(smith_type : boolean);

{*
	Pick which Smith chart to draw.
	When smith_type is true then admittance chart selected.
	Both Smith chart routines are in PFST.PAS
*}
Begin
  clear_window_gfx(xmin[10],ymin[10],xmax[10],ymax[10]);
   {Erase Smith Chart region}
  Draw_EGA_Smith(Not(smith_type));
  If Large_Smith Then Write_BigSmith_Coordinates;
End; {*Pick_Smith *}


Procedure Change_Bk_Color;

{*
	Used to toggle background color.
	if next_color true then change to next color.
	if next_color false then change to last color.
*}

Var 
  color_var : word;
(*    Last_Palette : PaletteType; *)

Begin
  color_var := GetBkColor;
  If color_var=Black Then SetBkColor(Blue)
  Else SetBkColor(Black);
End; {* Change_Bk_Color *}


{************* Main Circuit Drawing Functions *****************}

Function port_or_node_found : boolean;
{*
	 Calls node_look to look for a node then
	 looks for a port at current cursor postion.
*}

Var 
  i : integer;

Begin
  node_look;
  If cnet <> Nil Then
    port_or_node_found := true
  Else
    Begin
      port_or_node_found := false;
      For i:=1 To min_ports Do
        If (abs(portnet[i]^.xr-xm)< resln) And Not(portnet[i]^.node) And
           (abs(portnet[i]^.yr-ym)< resln) Then
          Begin
            port_or_node_found := true;
            join_port(i,1);
            exit
          End;
    End; {if cnet}
End; {port_or_node_found}


Function Coupler_Jump(cur_dir : integer) : boolean;

{*
	Check for drawing direction across the 
	ends of a clines part. 

	cur_dir returns 1:up, 2:right, 4:left, 8:down

	Called by Move_Net(dirnt,ivt : integer);
*}

Var 
  tcon  : conn;

  port,d2 : integer;
  coupler_skip  : boolean;

Begin
  coupler_jump := false;
  coupler_skip := false;
  If cnet <> Nil Then
    Begin
     {see if a cline is at this connection}
      tcon := Nil;
      Repeat
        If tcon=Nil Then tcon := cnet^.con_start
        Else tcon := tcon^.next_con;
        If tcon^.mate <> Nil Then
          If tcon^.mate^.net^.com^.typ='c' Then
            Begin   {found cline}
              d2 := tcon^.dir;
              port := tcon^.mate^.conn_no;
              Case d2 Of     {* check conditions for jumping over ends *}
                1 : If ( (port=1)And(cur_dir=4) Or (port=3)And(cur_dir=2)
                       Or (port=2)And(cur_dir=2) Or (port=4)And(cur_dir=4) )
                      Then coupler_skip := true;
                2 : If ( (port=1)And(cur_dir=8) Or (port=3)And(cur_dir=1)
                       Or (port=2)And(cur_dir=1) Or (port=4)And(cur_dir=8) )
                      Then coupler_skip := true;
                4 : If ( (port=1)And(cur_dir=1) Or (port=3)And(cur_dir=8)
                       Or (port=2)And(cur_dir=8) Or (port=4)And(cur_dir=1) )
                      Then coupler_skip := true;
                8 : If ( (port=1)And(cur_dir=2) Or (port=3)And(cur_dir=4)
                       Or (port=2)And(cur_dir=4) Or (port=4)And(cur_dir=2) )
                      Then coupler_skip := true;
              End; {case}
            End; {if found cline}
      Until (tcon^.next_con=Nil) Or (coupler_skip);
    End; {if cnet <> nil}
  If coupler_skip Then
    Begin   {move ports: 1->3, 2->4, 3->1, 4->2}
      Case port Of 
        1,2 : cnet := tcon^.mate^.next_con^.next_con^.mate^.net;
        3   : cnet := tcon^.mate^.net^.con_start^.mate^.net;
        4   : cnet := tcon^.mate^.net^.con_start^.next_con^.mate^.net;
      End; {case}
      increment_pos(0);
      coupler_jump := true;
      iv := 0; {! This is for dx_dy }
    End;
End; {* Coupler_Jump *}


Procedure Add_Net;
{*
	Connect up a new network to circuit.

	For the clines it must check for proper directions.
*}

Var 
  i       : integer;
  vcon    : conn;
  vnet    : net;
  special_coupler  : boolean;


   {************************************************************}
Function occupied_portO : boolean;
 {*
		Don't allow cursor to step over path to external port.
	*}

Var 
  i : integer;

Begin
  occupied_portO := false;
  For i:=1 To min_ports Do
    With portnet[i]^ Do
      Begin
        If (abs(xr-xm)<resln) And (abs(yr-ym)<resln) And node Then
          Begin
            occupied_portO := true;
            snapO;  {jump back to circuit from port}
          End;
      End; {for-with}
End; {occupied_portO}
 {****************************************************************}

Begin
  special_coupler := look_backO;
  If Not(off_boardO(1.0) Or occupied_portO) Then
    Begin
    {Set flag if part from extra list has been used}
      If (compt1^.descript[1] In ['j'..'r']) Then
        Extra_Parts_Used := True;
      compt1^.used := compt1^.used+1;
      vnet := new_net(compt1^.number_of_con,false);
      Draw_Net(vnet);
      For i:=1 To compt1^.number_of_con Do
        Begin
          If special_coupler And (i In [1,3]) Then
            Begin
              cnet := Mate_Node[i];
              cnet^.number_of_con := cnet^.number_of_con+1
            End
          Else
            Begin
              If port_or_node_found Then
                cnet^.number_of_con := cnet^.number_of_con+1 {advance count}
              Else
                cnet := new_net(1,true);  {or make new node}
            End;
          vcon := new_con(vnet,dirn);
          vcon^.conn_no := i;
          ccon := new_con(cnet,dirn);
          If (vnet^.com^.typ In ['i','d']) And (i<>1)
             And (i<>compt1^.number_of_con) Then
            Begin
              Case dirn Of 
                2,4 :
                      Begin
                        vcon^.dir := 6;
                        ccon^.dir := 6;
                      End;
                1,8 :
                      Begin
                        vcon^.dir := 9;
                        ccon^.dir := 9;
                      End;
              End; {case}
            End; {if}
          ccon^.mate := vcon;
          vcon^.mate := ccon;
          If i <> compt1^.number_of_con Then increment_pos(i);
        End; {for i}
    End; {if not off_boardO}
End; {* Add_Net *}


Procedure rem_net;
{*
	Remove a network from the circuit.
*}

Var 
  i,sdirn : integer;
  mnode,snet,onet : net;

Begin
  If Not(port_dirn_used) Then
    Begin
      snet := Nil;
      cnet^.com^.used := cnet^.com^.used-1;
      For i:=1 To cnet^.number_of_con Do
        Begin
          If i=1 Then ccon := cnet^.con_start
          Else ccon := ccon^.next_con;
          mnode := ccon^.mate^.net;
          dispose_con(ccon^.mate);
          With mnode^ Do
            If number_of_con=1 Then
              Begin
                onet := cnet;
                cnet := mnode;
                sdirn := dirn;
                If ext_port(con_start) Then join_port(con_start^.port_type,0);
                cnet := onet;
                dirn := sdirn;
              End;
          If mnode^.number_of_con > 0 Then snet := mnode;
        End; {for i}
      lengthxy(cnet);
      increment_pos(1);
      dispose_net(cnet);
      node_look;
      If cnet=Nil Then
        Begin
          cnet := snet;
          If cnet <> Nil Then increment_pos(0);
        End;
      If read_kbd Then draw_circuit;
    End; {if not port}
End; {rem_net}


Procedure step_line;
{*
	Step a distance = 1/2 part size,
	on exit cnet points to node if found.
*}
Begin
  If Not(port_dirn_used Or off_boardO(0.5)) Then
    Begin
      compt1^.step := true;
      increment_pos(-1);
      node_look;
    End; {if not port}
End; {step_line}


Procedure step_over_line;

{*
	Step over a line, on exit cnet points to node.
         Enter:cnet=network that you are stepping over. 
         Exit:cnet=node
*}

Var 
  tcon : conn;

  i,j  : integer;

Begin
  If Not(port_dirn_used) Then
    Begin
      iv := 0; {! This is for dx_dy }
      tcon := ccon^.mate;
      If cnet^.number_of_con=1 Then
        Begin
          message[1] := 'Cannot step';
          message[2] := 'over 1 port';
          update_key := false;
          cnet := cnet^.con_start^.mate^.net;
        End
      Else
        Begin
          If (cnet^.com^.typ In ['i','d']) Then
            Begin
              If dirn=cnet^.con_start^.dir Then
                cnet := tcon^.next_con^.mate^.net
              Else
                Begin
                  j := tcon^.conn_no-1;
                  tcon := cnet^.con_start;
                  For i:=2 To j Do
                    tcon := tcon^.next_con;
                  cnet := tcon^.mate^.net;
                End;
            End
          Else
            Begin {if not a device}
              Case tcon^.conn_no Of 
                1,3 : cnet := tcon^.next_con^.mate^.net;
                2   : cnet := cnet^.con_start^.mate^.net;
                4   : cnet := cnet^.con_start^.next_con^.next_con^.mate^.net;
              End; {case}
            End;
          increment_pos(0);
        End;
    End; {if not port}
End; {step_over_line}


Procedure Move_Net(dirnt,ivt:integer);

{*
	Procedure for calling either
		rem_net :  delete part from the circuit
		step_over_line : jump to opposite end of current part 
		step_line : move half the distance of current part
		add_net : add part (net) to circuit
		if coupler_jump() then jump across clines ends
*}
Begin
  If compt1^.parsed And Not(missing_part) Then
    Begin
      dirn := dirnt;
      iv := ivt;
      If con_found Then
        If iv=0 Then rem_net
      Else step_over_line
      Else
        If iv=0 Then step_line
      Else If Not(coupler_jump(dirnt)) Then add_net;
    End
  Else
    Begin
      erase_message;
      If Not(read_kbd) Then
        Begin      {if problem during circuit read}
          key := F3;
          read_kbd := true;
          compt3 := ccompt;
          cx3 := compt3^.x_block;
          message[1] := 'Part used in';
          message[2] := 'layout has been';
          message[3] := 'deleted';
          GotoXY(checking_position[1],checking_position[2]);
          Write('                  ');  {delete 'checking circuit'}
        End
      Else
        message[2] := 'Invalid part';
      update_key := false;
    End; {if parsed}
End; {* Move_Net *}


Procedure Pars_Compt_List;

{*
	Pars the component list.
	If action=true then find part dimensions 
		       else find s-parameters.

	Careful here on memory management!
*}

Var 
  pars,reload_all_devices  : boolean;
  tcompt    : compt;

Begin
  If action Then
    Begin   {Check for alt_sweep and device file changes}
      tcompt := Nil;
      reload_all_devices := false;
      Repeat   {step through and Reset if a sweep_compt was changed}
        If tcompt=Nil Then tcompt := part_start
        Else tcompt := tcompt^.next_compt;
        x_sweep.Check_Reset(tcompt);
        If tcompt^.changed
           And (get_lead_charO(tcompt) In ['i','d']) Then
          Begin
            If (Marked (dev_beg)) Then Release_Mem(dev_beg);      {Release Device}
            Mark_Mem(dev_beg);  {re-mark block}        {memory block}
            Init_Marker (net_beg);  {net memory sits above device memory}
            circuit_changed := true;  {force Redraw_circuit to reset net_beg}
            reload_all_devices := true; {forces all device files to be reloaded}
          End;
      Until (tcompt^.next_compt=Nil);
      If reload_all_devices Then
        Begin   {Check for unchanged devic files}
          tcompt := Nil;
          Repeat   {force all device files to be reloaded at marker dev_beg}
            If tcompt=Nil Then tcompt := part_start
            Else tcompt := tcompt^.next_compt;
            If (get_lead_charO(tcompt) In ['i','d']) Then
              tcompt^.changed := True;
          Until (tcompt^.next_compt=Nil);
        End;
    End;
  tcompt := Nil;
  bad_compt := false;
  Repeat
    If tcompt=Nil Then tcompt := part_start
    Else tcompt := tcompt^.next_compt;
    With tcompt^ Do
      Begin
        If changed And ((used > 0) Or step) Then circuit_changed := true;
        If action Then pars := changed
        Else pars := used > 0;
        If pars Then
          Begin
            parsed := true;
            If action Then
              Begin
                typ := get_lead_charO(tcompt);
                sweep_compt := false;  {init to check for alt_sweep-needed?}
              End;
            Case typ Of 
              't'  : tlineO(tcompt);
              'q'  : qline(tcompt);
              'c'  : clinesO(tcompt);
              'd',
              'i'  : If action Then Device_Read(tcompt,(typ='i'))
                     Else Device_S(tcompt,(typ='i'));
              'l'  : lumpedO(tcompt);
              'x'  : transformer(tcompt);
              'a'  : attenuator(tcompt);
              ' '  : parsed := false;
              Else
                Begin
                  parsed := false;
                  bad_compt := true;
                  message[1] := typ+' is an';
                  message[2] := 'unknown part';
                End;
            End; {case}
          End; {if pars}
        If Not(bad_compt) Then changed := false
        Else If window_number=3 Then ccompt := tcompt;
      End; {with}
  Until ((tcompt^.next_compt=Nil) Or bad_compt);
  If bad_compt Then write_message;
End; {* Pars_Compt_List *}


Procedure Pars_Single_Part(tcompt : compt);

{*
   Pressing the "=" sign will cause a tline or clines
   to be parsed, and the values of the computations
   to be displayed.  This only works with 
   tlines, qlines, and clines.
*}

Const 
  pos_prefix : string = 'EPTGMk m'+Mu+'npfa';

Var 
  i        : integer;
  d_s,avg_ere : double;

   {*****************************************************}
Procedure Big_Check(Var dt : double; Var i_in : integer);
Begin
  While (abs(dt)>1000.0) Do
    Begin
      dt := dt/1000;
      Dec(i_in);   {set-up prefix change}
    End;
End;
   {*****************************************************}
Procedure Small_Check(Var dt : double; Var i_in : integer);
Begin
  While (abs(dt)<0.01) Do
    Begin
      dt := dt*1000;
      Inc(i_in);   {set-up prefix change}
    End;
End;
 {*****************************************************}

Begin
  erase_message;
  action := true;
  bad_compt := false;
  With tcompt^ Do
    Begin
      changed := true;   {force future re-parsing and check reset}
      x_sweep.Check_Reset(tcompt);  {init x_sweep for later re-parsing}
      typ := get_lead_charO(tcompt);
      Case typ Of 
        't'  : tlineO(tcompt);
        'q'  : qline(tcompt);
        'c'  : clinesO(tcompt);
        Else beep;
      End; {case}
      If bad_compt Then
        Begin
          write_message;
        End
      Else If (typ In['t','q','c']) Then
             Begin
               If super Then
                 Begin
                   TextCol(lightgray);
                   GotoXY(xmin[6]+2,ymin[6]);
                   If (typ In ['t','q']) Then Write('Z : ',zed:7:3,Omega);
                   If (typ='c') Then
                     Begin
                       Write('Ze: ',zed:7:3,Omega);
                       GotoXY(xmin[6]+2,ymin[6]+1);
                       Write('Zo: ',zedo:7:3,Omega);
                       If stripline Then
                         avg_ere := er
                       Else
                         avg_ere := 4*e_eff_e0*e_eff_o0/sqr(sqrt(e_eff_e0)+sqrt(e_eff_o0));
                       GotoXY(xmin[6]+2,ymin[6]+2);
                       Write('l : ',(lngth0*sqrt(avg_ere)*360/lambda_fd): 7: 3,Degree);
                     End
                   Else
                     Begin
                       GotoXY(xmin[6]+2,ymin[6]+1);
                       Write('l : ',(wavelength*360): 7: 3,Degree);
                     End;
                 End {if super}
               Else
                 Begin
                   TextCol(lightgray);
                   i := 8;  {specify prefix for mm}
                   d_s := lngth;
  {Check for large or small values of d_s}
                   If (d_s<>0.0) Then
                     Begin
                       Big_Check(d_s,i);
                       Small_Check(d_s,i);
                     End;
                   GotoXY(xmin[6]+2,ymin[6]);
                   Write('l: ',d_s:7:3,pos_prefix[i],'m');
                   i := 8;  {specify prefix for mm}
                   d_s := width;
  {Check for large or small values of d_s}
                   If (d_s<>0.0) Then
                     Begin
                       Big_Check(d_s,i);
                       Small_Check(d_s,i);
                     End;
                   GotoXY(xmin[6]+2,ymin[6]+1);
                   Write('w: ',d_s:7:3,pos_prefix[i],'m');
                   If typ='c' Then
                     Begin
                       i := 8;  {specify prefix for mm}
                       d_s := con_space-width;
    {Check for large or small values of d_s}
                       If (d_s<>0.0) Then
                         Begin
                           Big_Check(d_s,i);
                           Small_Check(d_s,i);
                         End;
                       GotoXY(xmin[6]+2,ymin[6]+2);
                       Write('s: ',d_s:7:3,pos_prefix[i],'m');
                     End;
                 End;
             End;  {typ in}
    End; {with}
End; {* Pars_Single_Part *}


Procedure Board_Parser;
{*
	Parse the entries in the board parameter list.
*}

Var 
  tcompt   : compt;
  value    : double;
  unit_type,prefix  : char;
  value_str         : line_string;
  alt_param  : boolean;

Begin
  tcompt := Nil;
  bad_compt := false;
  Repeat
    If tcompt=Nil Then tcompt := board_start
    Else tcompt := tcompt^.next_compt;
    With tcompt^ Do
      Begin
        If changed Then
          Begin
            Board_Changed := true;
            parsed := true;
            typ := descript[1]; {first letter gives parameter}
            Get_Param(tcompt,1,value,value_str,unit_type,prefix,alt_param);
    {! if unit is 'm' then value is returned in mm}
    {Otherwise prefix is factored in}
            If Not(bad_compt) Then
              Begin
                Case typ Of 
                  'z'  : If (value > 0) And (unit_type=Omega) Then
                           Begin
                             z0 := value;
                             s_board[1,1] := value_str;
                             s_board[1,2] := prefix;
                           End
                         Else
                           Begin
                             Message[3] := 'in zd';
                             bad_compt := true;
                           End;
                  'f'  : If (value > 0) And (unit_type='H') Then
                           Begin
                             design_freq := value/Eng_prefix(prefix);
   {!normalize-take out the prefix}
                             s_board[2,1] := value_str;
                             s_board[2,2] := prefix;
                             freq_prefix := prefix;
                           End
                         Else
                           Begin
                             Message[3] := 'in fd';
                             bad_compt := true;
                           End;
                  'e'  : If (value > 0) And (unit_type='?') Then
                           Begin
                             er := value;
                             s_board[3,1] := value_str;
                             s_board[3,2] := prefix;
                           End
                         Else
                           Begin
                             Message[3] := 'in er';
                             bad_compt := true;
                           End;
                  'h'  : If (value > 0) And (unit_type='m') Then
                           Begin
                             substrate_h := value;
                             s_board[4,1] := value_str;
                             s_board[4,2] := prefix;
                           End
                         Else
                           Begin
                             Message[3] := 'in h';
                             bad_compt := true;
                           End;
                  's'  : If (value > 0) And (unit_type='m') Then
                           Begin
                             bmax := value;
                             s_board[5,1] := value_str;
                             s_board[5,2] := prefix;
   {Ensure con_sep re-calculation}
   {since it's effected by bmax}
                             tcompt^.next_compt^.changed := true;
                           End
                         Else
                           Begin
                             Message[3] := 'in s';
                             bad_compt := true;
                           End;
                  'c'  : If (value >= 0) And (unit_type='m') Then
                           Begin
                             con_sep := value;
                             s_board[6,1] := value_str;
                             s_board[6,2] := prefix;
                           End
                         Else
                           Begin
                             Message[3] := 'in c';
                             bad_compt := true;
                           End;
                End; {case}
                If bad_compt Then Message[2] := 'Bad value or unit';
              End; {if not(bad_unit)}
          End; {if changed}
        If Not(bad_compt) Then changed := false
        Else If window_number=4 Then ccompt := tcompt;
      End; {with}
  Until ((tcompt^.next_compt=Nil) Or bad_compt);
  If bad_compt Then write_message;
End; {* Board_Parser *}


Procedure Get_Coords;

{*
	Get values of coordintes in Plot window.
	symin and symax are used by other plotting
	routines.
*}

Var 
  tcoord : compt;

Begin
  bad_compt := false;
  tcoord := dBmax_ptr;        { point to dBmax value }
  symax := get_real(tcoord,1);
  If bad_compt Then exit;
  tcoord := tcoord^.next_compt; { point to dBmin value }
  symin := get_real(tcoord,1);
  If bad_compt Then exit;
  If symin >= symax Then
    Begin
      bad_compt := true;
      message[1] := 'Must have';
      message[2] := 'dB(max) > dB(min)';
      ccompt := tcoord;
      exit;
    End;
  tcoord := tcoord^.next_compt;  { point to fmin }
  sxmin := get_real(tcoord,1);
  If bad_compt Then exit;
  If (sxmin < 0) And Not(Alt_Sweep) Then
    Begin
      bad_compt := true;
      message[1] := 'Must have';
      message[2] := 'frequency >= 0';
      ccompt := tcoord;
      exit;
    End;
  tcoord := tcoord^.next_compt;  { point to fmax }
  sxmax := get_real(tcoord,1);
  If bad_compt Then exit;
  If (sxmax < 0) And Not(Alt_Sweep) Then
    Begin
      bad_compt := true;
      message[1] := 'Must have';
      message[2] := 'frequency >= 0';
      ccompt := tcoord;
      exit;
    End;
  If sxmin >= sxmax Then
    Begin
      bad_compt := true;
      message[1] := 'Plot must have';
      message[2] := 'x_max > x_min';
      ccompt := tcoord;
      exit;
    End;
  sfx1 := (xmax[8]-xmin[8])/(sxmax-sxmin);
  sfy1 := (ymax[8]-ymin[8])/(symax-symin);
  sigma := (symax-symin)/100.0;
  rho_fac := get_real(rho_fac_compt,1);
  If (rho_fac<=0.0) Or bad_compt Then
    Begin
      bad_compt := true;
      message[1] := 'The Smith chart';
      message[2] := 'radius must be >0';
      ccompt := rho_fac_compt;
    End;
End; {* Get_coords *}


Procedure Fill_Sa (out: BOOLEAN);

{*
	 Fill array sa with s-parameters and then load
	 into linked list of plot parameters ready for spline.
*}

Var 
  i,j,ij,sfreq  : integer;
  tcon,scon     : conn;
  s   : s_param;
  sa            : array[1..max_params,1..max_params] Of ^TComplex; {s-params array}

Begin
  cnet := net_start;
  FillChar (sa, SizeOf (sa), 0);
  If (Not bad_compt) Then
    Repeat
      tcon := cnet^.con_start;
      If (tcon <> Nil) Then
        Repeat
          j := tcon^.port_type;
          s   := tcon^.s_start;
          scon := cnet^.con_start;
          Repeat
            i := scon^.port_type;

            If (s <> Nil) Then
              Begin
                If ((i*j > 0) And (s^.z <> Nil)) Then
                  Begin
                    sa[i,j] := @(s^.z^.c);
                  End;
                s   := s^.next_s;
              End;

            scon := scon^.next_con;

          Until (scon = Nil);

          tcon := tcon^.next_con;

        Until (tcon = Nil);

      cnet := cnet^.next_net;

    Until (cnet = Nil);

  sfreq := xmin[8]+Round((freq-sxmin)*sfx1);
  For ij:=1 To max_params Do
    Begin
      If (out) Then Write_FreqO;  {re-calculates freq}
      If s_param_table[ij]^.calc Then
        Begin
          If xpt=0 Then
            Begin
              c_plot[ij] := plot_start[ij];
              plot_des[ij] := Nil;
            End
          Else
            c_plot[ij] := c_plot[ij]^.next_p;
          plot_end[ij] := c_plot[ij];
          If xpt=Round((design_freq-fmin)/finc) Then plot_des[ij] := c_plot[ij];
      {xpt is the point where the design freq. is located}
          c_plot[ij]^.filled := false;
          Case s_param_table[ij]^.descript[1] Of 
            's','S' :
                      Begin
                        i := si[ij];
                        j := sj[ij];
                        If sa[i,j] <> Nil Then
                          Begin
                            c_plot[ij]^.x := sa[i,j]^.r;
                            c_plot[ij]^.y := sa[i,j]^.i;
                          End
                        Else
                          Begin
                            c_plot[ij]^.x := 0;
                            c_plot[ij]^.y := 0;
                          End;
                        c_plot[ij]^.filled := true;
                      End;
          End; {case}
          If ((Not (bad_compt)) And (out)) Then
            Begin
              write_sO(ij);
              calc_posO(c_plot[ij]^.x,c_plot[ij]^.y,0,1,sfreq,false);
              If spline_in_smith Then box(spx,spy,ij);
              If Not(Large_Smith) And spline_in_rect Then box(sfreq,spp,ij);
            End;
        End; {if s_param}
    End; {for ij}
End; {* Fill_Sa *}


Function get_s_and_remove(index : integer; Var start : s_param): s_param;
{*
	Get an s-parameter from a linked list and remove it.
*}

Var 
  i : integer;
  s : s_param;

Begin
  If index=1 Then
    Begin
      get_s_and_remove := start;
      start := start^.next_s;
    End
  Else
    Begin
      For i:=1 To index-1 Do
        Begin
          If i=1 Then s := start
          Else s := s^.next_s;
          If s=Nil Then
            Begin
              message[2] := 'get_s_and_remove';
              shutdown;
            End;
        End; {For i}
      get_s_and_remove := s^.next_s;
      s^.next_s := s^.next_s^.next_s;
    End; {if index}
End; {get_c_con_and_remove}


Function get_c_and_remove(index : integer; Var start : conn) : conn;
{*
	Get a connector from a linked list and remove it.
*}

Var 
  i : integer;
  s : conn;

Begin
  If index=1 Then
    Begin
      get_c_and_remove := start;
      start := start^.next_con;
    End
  Else
    Begin
      For i:=1 To index-1 Do
        Begin
          If i=1 Then s := start
          Else s := s^.next_con;
          If s=Nil Then
            Begin
              message[2] := 'get_c_and_remove';
              shutdown;
            End;
        End; {For i}
      get_c_and_remove := s^.next_con;
      s^.next_con := s^.next_con^.next_con;
    End; {if index}
End; {get_c_con_and_remove}


Function get_kL_from_con(tnet : net;tcon : conn) : integer;
{*
	Find k given tnet and tcon.
*}

Var 
  kL    : integer;
  found : boolean;
  vcon  : conn;

Begin
  found := false;
  kL := 0;
  vcon := Nil;
  Repeat
    If vcon=Nil Then vcon := tnet^.con_start
    Else vcon := vcon^.next_con;
    kL := kL+1;
    If vcon=tcon Then found := true;
  Until ((vcon^.next_con=Nil) Or (found));
  If Not(found) Then
    Begin
      message[2] := 'get_kL_from_con';
      shutdown;
    End;
  get_kL_from_con := kL;
End; {get_kL_from_con}


Function internal_joint_remaining : boolean;

{*
	Look for next joint to make connection.
	If no joint found then internal_joint_remaining:=false.
*}

Var 
  csize,size  : integer;
  cNmate  : net;

Begin
  Conk := Nil;
  cnet := net_start;
  csize := 1000;
  Repeat
    ccon := cnet^.con_start;
    If (ccon <> Nil) Then
      Repeat
        If ccon^.port_type <=0 Then
          Begin
            cNmate := ccon^.mate^.net;
            If cNmate=cnet Then
              size := cnet^.number_of_con-2
            Else
              size := cnet^.number_of_con+cNmate^.number_of_con-2;
            If betweeni(1,size,csize) Then
              Begin
                csize := size-1;
                Conk := ccon;
              End; {if size - found simpler net to remove}
          End;{if ccon^.mate}

        ccon := ccon^.next_con;

      Until (ccon = Nil);

    cnet := cnet^.next_net;

  Until (cnet = Nil);

  If Conk <> Nil Then
    Begin
      netK := Conk^.net;
      netL := Conk^.mate^.net;
      internal_joint_remaining := true;
    End
  Else
    internal_joint_remaining := false;
  If No_mem_left Then internal_joint_remaining := false;
   { exit analysis if out of memory }
End; {internal_joint_remaining}


Function calc_con(Conj : conn) : boolean;
{*
	Does connector belong to set for which 
	s-parameters need to be calculated.
*}
Begin
  If ext_port(Conj) Then calc_con := inp[Conj^.port_type]
  Else calc_con := true;
End; {* calc_con *}


Procedure Join_Net;
{*
	Join connectors from different networks.
*}

Var 
  biL,bLL,akj,akk,aij,aik,start : s_param;
  sizea,sizeb,i,j,k,L   : integer;
  num1,num2,num3,num    : Tcomplex;
  ConL,Conj             : conn;

Begin
  k := get_kL_from_con(netK,ConK);
  L := get_kL_from_con(netL,Conk^.mate);
  Conk := get_c_and_remove(k,netK^.con_start);
  ConL := get_c_and_remove(L,netL^.con_start);
  akk := get_s_and_remove(k,Conk^.s_start);
  bLL := get_s_and_remove(L,ConL^.s_start);
  prp(num,akk^.z^.c,bLL^.z^.c);
  co (num3,1.0,0.0);
  di(num1,num3,num);
  rc(num2,num1);{rc}
  sizea := netK^.number_of_con-1;
  sizeb := netL^.number_of_con-1;
  prp(num1,bLL^.z^.c,num2);
  For j:=1 To sizea Do
    Begin
      If j=1 Then Conj := netK^.con_start
      Else Conj := Conj^.next_con;
      If calc_con(Conj) Then
        Begin
          akj := get_s_and_remove(k,Conj^.s_start);
          prp(num,num1,akj^.z^.c);
          prp(num3,num2,akj^.z^.c);

          aij := Conj^.s_start;
          aik := Conk^.s_start;
          If (aij^.z <> Nil) Then supr(aij^.z^.c,aik^.z^.c,num);
          For i:=2 To sizea Do
            Begin
              aij := aij^.next_s;
              aik := aik^.next_s;
              If (aij^.z <> Nil) Then supr(aij^.z^.c,aik^.z^.c,num);
            End;{ for i}

          For i:=1 To sizeb Do
            Begin
              If i=1 Then biL := ConL^.s_start
              Else biL := biL^.next_s;
              new_s (aij^.next_s);
              aij := aij^.next_s;
              If (biL^.z <> Nil) Then
                Begin
                  New_c (aij^.z);
                  prp(aij^.z^.c,biL^.z^.c,num3)
                End
              Else
                aij^.z := Nil;
            End;{ for i}
          aij^.next_s := Nil;
        End; {if calc conj}
    End; {end j}
  If sizea= 0 Then netK^.con_start := netL^.con_start
  Else Conj^.next_con := netL^.con_start;
  prp(num1,akk^.z^.c,num2);
  For j:=1 To sizeb Do
    Begin
      If j=1 Then Conj := netL^.con_start
      Else Conj := Conj^.next_con;
      If calc_con(Conj) Then
        Begin
          Conj^.net := netK;
          akj := get_s_and_remove(L,Conj^.s_start);
          prp(num,num1,akj^.z^.c);
          prp(num3,num2,akj^.z^.c);

          aij := Conj^.s_start;
          aik := ConL^.s_start;
          If (aij^.z <> Nil) Then supr(aij^.z^.c,aik^.z^.c,num);
          For i:=2 To sizeb Do
            Begin
              aij := aij^.next_s;
              aik := aik^.next_s;
              If (aij^.z <> Nil) Then supr(aij^.z^.c,aik^.z^.c,num);
            End; {for i}

          For i:=1 To sizea Do
            Begin
              If i=1 Then
                Begin
                  biL := Conk^.s_start;
                  new_s (start);
                  aij := start;
                End
              Else
                Begin
                  biL := biL^.next_s;
                  new_s (aij^.next_s);
                  aij := aij^.next_s;
                End;
              aij^.next_s := Conj^.s_start;
              If (biL^.z <> Nil) Then
                Begin
                  New_c (aij^.z);
                  prp(aij^.z^.c,biL^.z^.c,num3)
                End
              Else
                aij^.z := Nil;
            End; {for i}
          If sizea > 0 Then Conj^.s_start := start;
        End; {if conj}
    End; {for j}
  dispose_net(netL);
  netK^.number_of_con := sizea+sizeb;
End; {join_net}


Procedure Reduce_Net;
{*
	Join connectors from the same networks.
*}

Var 
  akj,akk,aij,aik,aLL,aiL,akL,aLk,aLj  : s_param;
  num1,num2,num3,num4    : TComplex;
  ConL,Conj     : conn;
  i,k,L         : integer;

Begin
  k := get_kL_from_con(netK,Conk);
  L := get_kL_from_con(netK,Conk^.mate);
  If k < L Then
    Begin
      i := k;
      k := L;
      L := i;
    End;
  Conk := get_c_and_remove(k,netK^.con_start);
  ConL := get_c_and_remove(L,netK^.con_start);
  akk  := get_s_and_remove(k,Conk^.s_start);
  aLk  := get_s_and_remove(L,Conk^.s_start);
  akL  := get_s_and_remove(k,ConL^.s_start);
  aLL  := get_s_and_remove(L,ConL^.s_start);
  di(num3,co1,akL^.z^.c);
  di(num4,co1,aLK^.z^.c);
  prp(num2,num3,num4);
  prp(num3,aLL^.z^.c,akk^.z^.c);
  di(num4,num2,num3);
  rc(num1,num4);
  Conj := netK^.con_start;
  While Conj <> Nil Do
    Begin
      If calc_con(Conj) Then
        Begin
          akj := get_s_and_remove(k,Conj^.s_start);
          aLj := get_s_and_remove(L,Conj^.s_start);
          num4.r := 0.0;
          num4.i := 0.0;
          di (num3,co1,aLK^.z^.c);
          supr(num4,akj^.z^.c,num3);
          supr(num4,aLj^.z^.c,akk^.z^.c);
          prp(num2,num1,num4);
          num4.r := 0.0;
          num4.i := 0.0;
          di (num3,co1,akL^.z^.c);
          supr(num4,aLj^.z^.c,num3);
          supr(num4,akj^.z^.c,aLL^.z^.c);
          prp (num3,num1,num4);

          aij := Conj^.s_start;
          aiL := ConL^.s_start;
          aik := Conk^.s_start;
          If aij^.z<>Nil Then
            Begin
              supr(aij^.z^.c,aiL^.z^.c,num2);
              supr(aij^.z^.c,aik^.z^.c,num3);
            End;
          While (aij^.next_s <> Nil) Do
            Begin
              aij := aij^.next_s;
              aiL := aiL^.next_s;
              aik := aik^.next_s;
              If aij^.z<>Nil Then
                Begin
                  supr(aij^.z^.c,aiL^.z^.c,num2);
                  supr(aij^.z^.c,aik^.z^.c,num3);
                End;
            End; {while aij}
        End; {if calc_con conj}
      Conj := Conj^.next_con;
    End;{Conj}
  netK^.number_of_con := netK^.number_of_con-2;
End; {reduce net}


Procedure rem_node(tnet : net);

{*
	Remove nodes in network with 2 ports.
	These require no connecting tee's or crosses
	for reduction. Makes connectors from one net
	mate up with the other.
*}

Var 
  tcon : conn;
  i,j  : integer;

Begin
  ccon := tnet^.con_start;

  {!* Dead code? tnet^.ports_connected=2 is not permitted by the call!}

  If tnet^.ports_connected =2 Then
    Begin {2 port node connect to two ports}
      For j:=1 To 2 Do
        Begin
          If j=1 Then ccon := tnet^.con_start
          Else ccon := ccon^.next_con;
          For i:=1 To 2 Do
            Begin
              If i=1 Then
                Begin
                  new_s(ccon^.s_start);
                  c_s := ccon^.s_start;
                End
              Else
                Begin
                  new_s(c_s^.next_s);
                  c_s := c_s^.next_s;
                End;
              new_c(c_s^.z);
              If i<>j Then c_s^.z^.c.r := -1.0
              Else c_s^.z^.c.r := 0.0;
              c_s^.z^.c.i := 0.0;
            End; {for i}
          c_s^.next_s := Nil;
        End; {j}
    End
  Else
    Begin
      If tnet^.ports_connected > 0 Then
        Begin {if node is connected to port}
          If ext_port(ccon) Then
            Begin
              tcon := ccon^.next_con^.mate;
              tcon^.port_type := ccon^.port_type
            End
          Else
            Begin
              tcon := ccon^.mate;
              tcon^.port_type := ccon^.next_con^.port_type;
            End;
          tcon^.mate := Nil;
          tcon^.net^.ports_connected := tnet^.ports_connected;
        End
      Else
        Begin
          ccon^.mate^.mate := ccon^.next_con^.mate;
          ccon^.next_con^.mate^.mate := ccon^.mate;
        End;
      dispose_net(tnet);
    End;
End; {* rem_node *}


Procedure Set_Up_Element(ports : integer);

{*
	Set up frequency independent s-parameters for each network.
	Does opens, shorts, tee's, and crosses.
*}

Var 
  i,j,jj   : integer;
  pta      : array[1..max_net_size] Of integer;
  onlyinp,onlyout  : array[1..max_net_size] Of boolean;

Begin
  If ports=1 Then
    Begin  {open or short}
      new_s(cnet^.con_start^.s_start);
      c_s := cnet^.con_start^.s_start;
      c_s^.next_s := Nil;
      New_c (c_s^.z);
      If cnet^.grounded Then co(c_s^.z^.c,-one,0.0)   { short }
      Else co(c_s^.z^.c, one,0.0);  { open  }
    End
  Else
    Begin
      jj := 1;
      For j:=1 To ports Do
        Begin {check to see if input or output port}
          If j=1 Then ccon := cnet^.con_start
          Else ccon := ccon^.next_con;
          If ext_port(ccon) Then
            Begin
              pta[jj] := ccon^.port_type;
              onlyout[jj] := out[pta[jj]] And Not(inp[pta[jj]]);
              onlyinp[jj] := inp[pta[jj]] And Not(out[pta[jj]]);
              If Not(out[pta[jj]] Or inp[pta[jj]]) Then
                Begin
                  ccon := get_c_and_remove(jj,cnet^.con_start);
                  Dec(cnet^.number_of_con);
                  Dec(jj);
                End; {if not(out..)}
            End
          Else
            Begin
              onlyout[jj] := false;
              onlyinp[jj] := false;
            End; {if ext}
          Inc(jj);
        End; {j}
      For j:=1 To cnet^.number_of_con Do
        Begin
          If j=1 Then ccon := cnet^.con_start
          Else ccon := ccon^.next_con;
          For i:=1 To cnet^.number_of_con Do
            Begin
              If i=1 Then
                Begin
                  new_s(ccon^.s_start);
                  c_s := ccon^.s_start;
                End
              Else
                Begin
                  new_s(c_s^.next_s);
                  c_s := c_s^.next_s;
                End;
              If onlyinp[i] Or onlyout[j] Then
                Begin
                  c_s^.z := Nil;
                End
              Else
                Begin
                  new_c (c_s^.z);
                  If cnet^.node Then
                    Begin
                      c_s^.z^.c.i := 0.0;
                      If cnet^.grounded Then
                        Begin {if grounded}
                          If i=j Then c_s^.z^.c.r := -one
                          Else c_s^.z^.c.r := 0.0;
                        End
                      Else
                        Begin    {Tee or Cross}
                          If i=j Then c_s^.z^.c.r := one*((2/ports)-1)
                          Else c_s^.z^.c.r := one*(2/ports);
                        End; {if grounded}
                    End;
                End; {if onlyinp}
            End; {i}
          c_s^.next_s := Nil;
        End; {j}
    End; {if 1 port}
End; {* set_up_element *}


Procedure Fill_Compts;
{*
	Transfer s-parameters from parts to networks.
*}

Var 
  i,j,ii,jj : integer;
  v_s       : s_param;
  coni,conj : conn;

Begin
  action := false;
  {Load s-param data into memory, at xpt=0 fill device s_ifile}
  Pars_Compt_List;
  cnet := net_start;
  If (Not (bad_compt)) Then
    Repeat
      If Not(cnet^.node) And (cnet^.number_of_con > 0) Then
        Begin
          coni := cnet^.con_start;
          Repeat
            ii := coni^.conn_no;
            conj := cnet^.con_start;
            c_s := coni^.s_start;
            Repeat
              jj := conj^.conn_no;
              v_s := Nil;
              If c_s^.z <> Nil Then
                Begin
                  For i:=1 To cnet^.com^.number_of_con Do
                    For j:=1 To cnet^.com^.number_of_con Do
                      Begin
                        If v_s=Nil Then v_s := cnet^.com^.s_begin
                        Else v_s := v_s^.next_s;
                        If (ii=i) And (jj=j) Then
                          Begin
                            c_s^.z^.c.r := v_s^.z^.c.r;
                            c_s^.z^.c.i := v_s^.z^.c.i;
                          End; {if ii}
                      End; {for j}
                End; {if c_s}

              conj := conj^.next_con;
              c_s := c_s^.next_s;

            Until ((conj = Nil) Or (c_s = Nil));

            coni := coni^.next_con;

          Until (coni = Nil);
        End;{if not(cnet^.node)};

      cnet := cnet^.next_net;

    Until (cnet = Nil);
End; {* Fill_Compts *}


Procedure set_up_net;
{*
	Procedure for setting up nets
*}

Var 
  i : integer;

Begin
  For i:=1 To 2 Do
    Begin {set_up_nets}
      cnet := Nil;
      Repeat    {Loop through network, setting up connections}
        If cnet=Nil Then cnet := net_start
        Else cnet := cnet^.next_net;
        With cnet^ Do
          If i=1 Then
            Begin
              If ((number_of_con=2) And node
                 And Not(grounded)
                 And (ports_connected <> 2))
                Then rem_node(cnet);
            End
          Else
            Set_Up_Element(number_of_con);
      Until cnet^.next_net=Nil;
    End; {set_up_nets and do freq indept stuff}
End; {* set_up_net *}


Procedure Get_s_and_f(do_time : boolean);

{*
	Find parameter in plot box, i.e. which s to calc at fd/df

	For do_time it is necessary to prompt for fd/df.
	Otherwise the number of Points are used.
*}

Var 
  pt_end,pt_start,ij,i,j,code1,code2 : integer;
  real_npts      : double;
  q_fac_string   : file_string;

Begin
  ccompt := Points_compt;
  cx := ccompt^.x_block;
  bad_compt := false;
  If do_time Then
    Begin    {* Use fd/df for time sweep *}
      q_fac_string := input_string('  Integer fd/df', '     <10>');
      If (q_fac_string='') Then
        q_fac := 10
      Else
        Begin
          Val(q_fac_string,q_fac,code1);  {fd/df}
          If (code1<>0) Then bad_compt := true;
        End;
      If bad_compt Then
        Begin
          message[2] := 'Invalid fd/df';
          exit;
        End;
      bad_compt := true;
      If q_fac < 1 Then
        Begin
          message[1] := 'fd/df too small';
          message[2] := 'or negative';
          exit;
        End;
      finc := design_freq/q_fac;   {normalized}
      If (sxmin/finc < 10000) And (sxmax/finc < 10000) Then
        Begin
          If abs(sxmin/finc-Round(sxmin/finc)) < 0.001
            Then pt_start := Round(sxmin/finc)
          Else pt_start := Trunc(sxmin/finc)+1;
          fmin := finc*pt_start;
          pt_end := Trunc(sxmax/finc);
        End
      Else
        Begin
          message[2] := 'fd/df too large';
          exit;
        End;
      npts := pt_end-pt_start;
      If npts < 0 Then
        Begin
          message[2] := 'fd/df too small';
          exit;
        End;
      If npts > ptmax Then
        Begin
          message[2] := 'fd/df too large';
          exit;
        End;
    End   {if do_time}
  Else
    Begin    {* Use Points for frequency or other sweep}
      real_npts := Get_Real(Points_compt,1);
      If (Trunc(real_npts)>ptmax) Then
        bad_compt := true
      Else
        npts := Trunc(real_npts) - 1;   {number of points}
      If bad_compt Or (npts < 0) Then
        Begin
          bad_compt := true;
          message[1] := 'Invalid number';
          message[2] := 'of points';
          exit;
        End;
      fmin := sxmin;  {if npts=0 then plot a point at fmin}
      If (npts<>0) Then finc := (sxmax-sxmin)/npts;
    {This to allow plotting of 1 point i.e. npts=0}
    End;  {if do_time}
  For ij:=1 To min_ports Do
    Begin
      inp[ij] := false;
      out[ij] := false;
    End;
  For ij:=1 To max_params Do
    With s_param_table[ij]^ Do
      Begin
        calc := false;
        If length(descript)>=3 Then
          Begin
            Val(descript[2],i,code1);
            Val(descript[3],j,code2);
            If (code1=0) And (code2=0) Then
              If betweeni(1,i,min_ports)
                 And betweeni(1,j,min_ports) Then
                Begin
                  si[ij] := i;
                  sj[ij] := j;
                  If portnet[i]^.node
                     And portnet[j]^.node Then
                    Begin
                      inp[j] := true;
                      out[i] := true;
                      calc := true;
                      bad_compt := false;
                    End;{if port}
                End;{if code and between}
          End; {if length}
      End; {for ij and with}
  If bad_compt Then
    Begin
      ccompt := rho_fac_compt;
      move_cursor( 0, 1);
      message[1] := 'No pair of Sij';
      message[2] := 'correspond to';
      message[3] := 'connected ports';
      exit;
    End;
End; {* Get_s_and_f *}


Procedure Analysis(do_time, out: boolean);

{*
	Main procedure for directing the analysis.
	Pass do_time on to get_s_and_f in order to
	return FFT parameters based on q_fac.
*}

Label 
  exit_analysis;

Var 

  old_net       : net;
  old_net_start : net;
  net_end_ptr1  : marker;
  net_end_ptr2  : marker;
  ptrall        : marker;
  ptrvar        : marker;
  ptranalysis   : marker;
{  netmem        : LONGINT; }
  MemError      : BOOLEAN;

Begin
  filled_OK := false;
  MemError := FALSE;
  If net_start = Nil Then
    Begin
      message[1] := 'No circuit';
      message[2] := 'to analyze';
      write_message;
    End
  Else
    Begin
      Get_s_and_f(do_time);
      If bad_compt Then
        Begin
          write_message;
          cx := ccompt^.x_block;
        End
      Else
        Begin
          filled_OK := true;
          TextCol(lightgray);
          GotoXY(xmin[6],ymin[6]+1);
          Write(' Press h to halt ');
          TextCol(white);
          GotoXY(xmin[6]+7,ymin[6]+1);
          Write('h');

      { Save initial Markers}
          old_net := cnet;
          old_net_start := net_start;

      { Mark original memory setting }
          Mark_Mem (ptrall);
{      netmem:= MemAvail; }

      { Copy original network }
          Init_Marker (net_end_ptr1);
          copy_networks (net_beg, ptrall, net_end_ptr1);

          If Not Marked (net_end_ptr1) Then
            Begin
              MemError := TRUE;
              GOTO exit_analysis;
            End;

      { set up nets for analysis }
          set_up_net;

(*
      IF (MemAvail < (netmem - MemAvail + npts * 256)) THEN
      BEGIN
        MemError:= TRUE;
        GOTO Exit_Analysis;
      END;
*)
      { Initialize markers for copy of new network }
          Init_Marker (net_end_ptr2);
          Mark_Mem (ptranalysis);

      { main analysis loop }
          For xpt:=0 To npts Do
            Begin
              If Alt_Sweep Then
                Begin
                  freq := design_freq;   {Force parts to use fd}
                  x_sweep.Load_Data(fmin+xpt*finc);
   {use freq data for alt parameter}
                End
              Else
                Begin
                  If (xpt=npts) And (npts<>0) Then freq := sxmax
                  Else freq := fmin+xpt*finc;
          {These are normalized to the window}
                End;
 {* For alternate sweep freq:=design_freq and finc=0 *}

        { make copy of network for analysis }
              copy_networks (net_beg, ptranalysis, net_end_ptr2);
              If (Not Marked (net_end_ptr2)) Then
                Begin
                  MemError := TRUE;
                  GOTO Exit_Analysis;
                End;

        { parts calculation and at xpt=0 fills device file s_ifile interpolation data }
              Fill_compts;

              If (No_mem_left) Then GOTO exit_analysis; { check for 16 bytes }

              If (bad_compt) Then
                Begin
                  filled_OK := FALSE;
                  GOTO Exit_Analysis;
                End
              Else
                Begin
                  While internal_joint_remaining Do  {loop over joints}
                    If netK=netL Then
                      reduce_net  {join connectors on same net}
                    Else
                      join_net;   {join two nets}
                End; {if bad_compt }

              If Alt_Sweep Then freq := fmin+xpt*finc;
 {Restore freq for use in linked lists}

              Fill_Sa (out);     { uses freq, calls write_freqO }

        { free memory used for analysis }
        { -> not for xpt = 0; keep device file's interpolation data }
              If (xpt <> 0) Then
                Release_Mem (ptrvar)
              Else
                Mark_Mem (ptrvar);

        { check for abort }
              If keypressed Then
                Begin
                  chs := ReadKey;
                  If chs In ['h','H'] Then
                    Begin
                      filled_OK := false;
                      erase_message;
                      message[2] := '      HALT       ';
                      write_message;
                      goto exit_analysis;
                    End;
                  beep;
                End; {if keypreseed}
            End; {for xpt:= 0 to npts }
          exit_analysis:
                         If (No_mem_left Or MemError) Then
                           Begin
                             filled_OK := false;
                             erase_message;
                             message[1] := ' Circuit is too  ';
                             message[2] := ' large for Puff  ';
                             message[3] := '   to analyze    ';
                             write_message
                           End;

      { Restore network }
          copy_networks (net_beg, ptrall, net_end_ptr1);

      { Release all network copies }
          Release_Mem (ptrall);

      {Restore initial markers}
          cnet     := old_net;
          net_start := old_net_start;
        End; {if bad_compt}
    End; {if cnet}
End; {* Analysis *}


Procedure move_marker(xi : integer);

{*
	Move marker on Smith chart and rectangular plot.

	Move_marker(+/- 1) is invoked from Plot2
		by Page-Up and Page-Down keys.

	Move_marker(0) is called by plot_manager.
*}

Var 
  i,ij,k,kk,nb,sfreq : integer;

Begin
  If marker_OK Then
    Begin
      For ij:=1 To max_params Do
        If s_param_table[ij]^.calc Then
          Case xi Of 
            0 :
                Begin
                  If plot_des[ij]=Nil Then xpt := 0
                  Else
                    Begin
                      c_plot[ij] := plot_des[ij];
                      xpt := Round((design_freq-fmin)/finc);
   {point for cursor placement}
                      If Not(betweeni(0,xpt,npts)) Then xpt := 0;
                    End;
                  If xpt=0 Then c_plot[ij] := plot_start[ij];
                End; { 0: }
            1 : If c_plot[ij]=plot_end[ij] Then
                  c_plot[ij] := plot_start[ij]
                Else
                  c_plot[ij] := c_plot[ij]^.next_p;
            -1 : If c_plot[ij]=plot_start[ij] Then
                   c_plot[ij] := plot_end[ij]
                 Else
                   c_plot[ij] := c_plot[ij]^.prev_p;
          End; {case xi}
      If xi = 0 Then For i:=1 To 2*max_params Do
                       box_filled[i] := false
                       Else xpt := xpt+xi;
      If xpt > npts Then xpt := 0;
      If xpt < 0    Then xpt := npts;
      If (xi <> 0) Then Erase_Message;
      Write_FreqO;
      sfreq := xmin[8]+Round((freq-sxmin)*sfx1);
      For k:=1 To 3 Do
        For ij:=1 To max_params Do
          If s_param_table[ij]^.calc Then
            Case k Of 
              1 : restore_boxO(ij);
              2 :
                  Begin
                    box_filled[ij] := false;
                    box_filled[ij+max_params] := false;
                    If c_plot[ij]^.filled Then
                      Begin
                        calc_posO(c_plot[ij]^.x,c_plot[ij]^.y,0,1,sfreq,false);
                        If spline_in_smith Then move_boxO(spx ,spy,ij);
                        If Not(Large_Smith) Then
                          If spline_in_rect Then move_boxO(sfreq,spp,ij+max_params);
                      End;
                  End; {2:}
              3 :
                  Begin
                    For kk:=0 To 1 Do
                      Begin
                        nb := ij+kk*max_params;
                        If box_filled[nb] Then pattern(box_dot[1,nb],box_dot[2,nb],ij,128)
                      End;{kk}
                    If c_plot[ij]^.filled Then write_sO(ij);
                  End; {3 :}
            End; {case}
    End; {if do time}
End; {move_marker}


Procedure show_real;

Var 
  ij: integer;
  d,r,i: double;
  u: char;

Begin
  If (marker_ok) Then
    Begin
      For ij:= 1 To max_params Do
        Begin
          If (s_param_table[ij] = ccompt) Then
            Begin
              If ((ccompt^.calc) And (c_plot[ij]^.filled) And
                 ((ccompt^.descript = 'S11') Or (ccompt^.descript = 'S22') Or
                 (ccompt^.descript = 'S33') Or (ccompt^.descript = 'S44'))) Then
                With c_plot[ij]^ Do
                  Begin
                    GotoXY (xmin[6]+2, ymin[6]);
                    If (admit_chart) Then
                      Begin
                        d := sqr (1 + x) + sqr (y);
                        r := (1 - sqr (x) - sqr (y));
                        If (r = 0.0) Then
                          Begin
                            Write ('Rp:');
                          End
                        Else
                          Begin
                            r := (d * z0 / r);
                            If (abs (r) <= 1e+9) Then
                              Write ('Rp:', r:10:3, ' ', Omega)
                            Else
                              Write ('Rp:         ', infin, ity);
                          End;
                        i := 2 * y;
                        GotoXY (xmin[6]+2,ymin[6]+1);
                        If (i = 0.0) Then
                          Begin
                            Write ('Xp:');
                          End
                        Else
                          Begin
                            i := (d * z0 / i);
                            If (abs (i) <= 1e+9) Then
                              Write ('Xp:', i:10:3, ' ', Omega)
                            Else
                              Write ('Xp:         ', infin, ity);
                          End;
                      End
                    Else
                      Begin
                        d := sqr(1 - x) + sqr(y);
                        If (d = 0.0) Then d := 5e-324;
                        r := ((1 - sqr(x) - sqr(y)) * z0 / d);
                        i := (2 * y * z0 / d);
                        If (abs (r) <= 1e+9) Then
                          Begin
                            If (abs (i) <= 1e+9) Then
                              Begin
                                Write ('Rs:', r:10:3, ' ', Omega);
                                GotoXY (xmin[6]+2, ymin[6]+1);
                                Write ('Xs:', i:10:3, ' ', Omega);
                              End
                            Else
                              Begin
                                Write ('Rs:');
                                GotoXY (xmin[6]+2, ymin[6]+1);
                                Write ('Xs:         ', infin, ity);
                              End;
                          End
                        Else
                          Begin
                            If (abs (i) <= 1e+9) Then
                              Begin
                                Write ('Rs:         ', infin, ity);
                                GotoXY (xmin[6]+2, ymin[6]+1);
                                Write ('Xs:');
                              End
                            Else
                              Begin
                                Write ('Rs:         ', infin, ity);
                                GotoXY (xmin[6]+2, ymin[6]+1);
                                Write ('Xs:         ', infin, ity);
                              End;
                          End;
                      End;
                    d := fmin+xpt*finc;
                    Case freq_prefix Of 
                      'G': d := d * 1000000000.0;
                      'M': d := d * 1000000.0;
                      'k': d := d * 1000.0;
                      Else RunError (0);
                    End;
                    GotoXY (xmin[6]+2,ymin[6]+2);
                    If (i <> 0.0) Then
                      Begin
                        If (i > 0) Then
                          Begin
                            Write ('L :');
                            d := (i / (2*pi*d));
                            u := 'H';
                          End
                        Else
                          Begin
                            Write ('C :');
                            d := (-1 / (2*pi*d*i));
                            u := 'F';
                          End;
                        GotoXY (xmin[6]+5,ymin[6]+2);
                        If (d > 1e+9) Then
                          Write ('        ', infin, ity)
                        Else If (d >= 1.0) Then
                               Write (d:10:3, ' ', u)
                        Else If (d >= 0.001) Then
                               Write (d*1000.0:10:3, ' m', u)
                        Else If (d >= 0.000001) Then
                               Write (d*1000000.0:10:3, ' æ', u)
                        Else If (d >= 0.000000001) Then
                               Write (d*1000000000.0:10:3, ' n', u)
                        Else
                          Write (d*1000000000000.0:10:3, ' p', u);
                      End;
                  End
                  Else { if .. then .. with }
                    beep;
            End; { if s_param... }
        End; { for ... }
    End
  Else { if marker_ok }
    beep;
End;


Procedure Plot_Manager(do_analysis, clear_plot, do_time, boxes, out: boolean);
{*
	Main procedure for directing anlaysis followed by plotting.

*}

Var 
  ticko: integer;
Begin
  ticko := GetTimerTicks;
  erase_message;
  move_cursor(0,0);    { used to erase any residual S's }
  Get_Coords;
  If bad_compt Then
    Begin
      write_message;
      cx := ccompt^.x_block;
      filled_OK := false;
    End
  Else
    Begin
      Pick_Smith(admit_chart);
      If Not(Large_Smith) Then
        Draw_Graph(xmin[8],ymin[8],xmax[8],ymax[8],false);
      cx := ccompt^.x_block;
      If Not(clear_plot) And filled_OK Then
        Begin
          Smith_and_Magplot(true,true,true);
          move_marker(0);
        End;
      If do_analysis Then Analysis(do_time, out); { Start Analysis }
      If filled_OK Then
        Begin
          marker_OK := true;
          Smith_and_Magplot(false,false,boxes);
       {plot spline points after analysis}
          ticko := GetTimerTicks-ticko;
          If ( do_analysis And Not(key In['h','H']) ) Then
            Begin
              erase_message;
              TextCol(lightgray); {center text in message box}
              Gotoxy((xmin[6]+xmax[6]-16) div 2,ymin[6]+1);
              Write('Time ',ticko/18.2:6:1,' secs');  {was ticko/18.2:8:1 }
              beep;
            End;
          move_marker(0);
          If demo_mode Then rcdelay(300);
        End
      Else
        marker_OK := false;
    End; {if bad_compt}
End; {* Plot_Manager}


Procedure Erase_Circuit;

{*
	Erase circuit board. Redraw if read_kbd=false.
	Check to see if device files need to be re-copied into memory.

	Very significant memory management control here
	involving the net_beg pointer.

	Called by:
		Redraw_Circuit,
		Read_Net (after or if not board_read),
		Lpayout1 (if Ctrl_e),
		Parts3 (if Ctrl_e)

*}


Begin
  erase_message;
  If compt1 <> Nil Then write_compt(lightgray,compt1);
  compt1 := part_start;

  If (Marked (net_beg)) Then Release_Mem(net_beg); {release networks memory}
  Mark_Mem(net_beg);
  key_i := 0; {set_up for redraw}
  If read_kbd Then
    Begin
      filled_OK := false;
      circuit_changed := false;
      Board_Changed := false;
      marker_OK := false;
      key_end := 0;  {erase key_list}
      Extra_Parts_Used := false;
    End;
  net_start := Nil;
  cnet := Nil;
  Draw_Circuit;
End; {Erase_Circuit}


Procedure Toggle_Smith_and_Plot;
{*
	Activated by the <Tab> key, this allows
	re-plotting for under a new smith chart.
*}
Begin
  admit_chart := Not(admit_chart); {Toggle Smith type}
  Erase_message;
  move_cursor(0,0);    { used to erase any residual S's }
  Get_Coords;
  If bad_compt Then
    Begin
      write_message;
      cx := ccompt^.x_block;
      filled_OK := false;
    End
  Else
    Begin
      Pick_Smith(admit_chart);
      If Not(Large_Smith) Then
        Draw_Graph(xmin[8],ymin[8],xmax[8],ymax[8],false);
      cx := ccompt^.x_block;
      If filled_OK Then
        Begin
          Smith_and_Magplot(false,true,true);
          move_marker(0);
        End;
    End;
End; {* Toggle_Smith_and_Plot *}


Procedure Redraw_Circuit;
{*
	Set up for circuit redraw.
*}
Begin
  read_kbd := false;
  Erase_Circuit;
  key_o := key;
  key := F1;
  GotoXY(checking_position[1],checking_position[2]);
  TextCol(lightred);
  If Not(demo_mode) Then write('Checking Circuit.');
End; {* Redraw_Circuit *}


Procedure Large_Smith_Coords;
{*
	Change linked list of coordinates to that required for
	Large Smith chart. 
*}
Begin
  {Advance coord_start pointer to fmin position}
  coord_start := fmin_ptr;
  {Change wrap-around point}
  fmin_ptr^.prev_compt := s_param_table[4];
  s_param_table[4]^.next_compt := fmin_ptr;
End; {* Large_Smith_Coords *}


Procedure Small_Smith_Coords;
{*
	Change linked list of coordinates to that required for
	small Smith chart.
*}
Begin
  {return coord_start pointer to dBmax}
  coord_start := dBmax_ptr;
  {Change wrap-around point}
  fmin_ptr^.prev_compt := dBmax_ptr^.next_compt;
  s_param_table[4]^.next_compt := dBmax_ptr;
End; {* Small_Smith_Coords *}


Procedure Toggle_Large_Smith(return_key : char);
{*
	Change parameters to enlarge/shrink Smith chart.

*}
Begin
  Large_Smith := Not(Large_Smith);
  If Not(Large_Smith) Then
    Begin  {make small Smith}
      Small_Smith_Coords;
      clear_window_gfx(xmin[10],ymin[10],xmax[10],ymax[10]); {Erase Large Smith region}
      Screen_Plan;
      Draw_Graph(xmin[8],ymin[8],xmax[8],ymax[8],false);
      key := return_key;
      Redraw_Circuit; {Setup circuit re-draw and return to F2}
      Write_File_Name(puff_file);
    End
  Else
    Begin {Make large Smith}
      Large_Smith_Coords;
      Screen_Plan;
 {Move if invalid cursor position}
      If (ccompt=dBmax_ptr) Or (ccompt=dBmax_ptr^.next_compt) Then
        Begin
          ccompt := Points_compt;
          cx := ccompt^.x_block;
        End;
    End;
  Pick_Smith(admit_chart);
  If Large_Smith Then Write_BigSmith_Coordinates;
  If filled_OK Then
    Begin
      Smith_and_Magplot(false,true,true);
      move_marker(0);
    End;
End; {* Toggle_Large_Smith *}


Procedure Read_Net(Var fname : file_string; init_graphics : boolean);
{* 
	Read in xxx.puf file. 
*}

Var 
  char1,char2  : char;
  file_read,
  bad_file : boolean;


Begin
  file_read := false;
  marker_OK := false;
  filled_OK := false;
  bad_file := false;
  If (pos('.',fname)=0) And (fname<>'') Then fname := fname+'.puf';
  If fileexists(true,net_file,fname) Then
    Begin
      read(net_file,char1);
      Repeat
        If char1=#13 Then read(net_file,char2) {Don't skip 2 lines on CR's}
        Else readln(net_file,char2);
        If char1='\' Then
          Begin
            Case char2 Of 
              'b','B' :
                        Begin {board parameters}
                          Read_Board(init_graphics);
                          If board_read Then
                            Begin
                              If init_graphics Then
                                Begin
                                  Screen_Init;
                                  Init_Mem;
                                  Fresh_Dimensions;
                                End; {!}
                              Erase_Circuit;
                              Set_Up_Board;
                            End;
                        End;
              'k','K' :
                        Begin {read in 'key' = plot parameters}
                          Read_KeyO;
                          Set_Up_KeyO;
                          bad_compt := false;
                          rho_fac := get_real(rho_fac_compt,1);
                          If bad_compt Or (rho_fac<=0.0) Then
                            Begin
                              rho_fac := 1;
                              rho_fac_compt^.descript := 'Smith radius 1.0';
                            End;
                        End;
              'p','P' : read_partsO;    {read parts list}
              's','S' : Read_S_Params; {read in calculated s-parameters}
              'c','C' : read_circuitO;  {read circuit}
              Else
                Begin
     {* readln(net_file); *} {else advance a line}
            {* read(net_file,char1); *}
     {! Should have character after backslash}
                  Message[1] := 'Improper';
                  Message[2] := 'Puff file';
                  Write_Message;
                  bad_file := true;
                  board_read := false;
                  If Not(init_graphics) Then
                    Begin
                      Close(net_file);
                      exit;
                    End;
                End;
            End; {case}
          End
        Else
          Read(net_file,char1); { look for '\' on this line }
      Until bad_file Or EOF(net_file) ;
      Close(net_file);
      file_read := true;
    End; {if fileexists}
  If Not(board_read) Then
    Begin  {if couldn't Read_Board data}
      read_setup(fname);  {then read setup.puf board data}
      If Not(board_read) Then bad_board;
      If init_graphics Then
        Begin
          Screen_Init;
          Fresh_Dimensions;
        End;
      Erase_Circuit;
      file_read := true;
    End;
  If file_read Then
    Begin
      puff_file := fname; {Change current file name}
      write_file_name(fname);


(*	ccompt:=Points_compt;   {previous location of plot_manager}
	if filled_OK then Plot_Manager(false,true,false,true);   *)

(*	New(net_beg);  *)

      ccompt := part_start;
      cx := ccompt^.x_block;
      compt3 := ccompt;
      cx3 := cx;
      action := true;
      x_sweep.Init_Use; {Initialize alt_sweep object}
      Pars_Compt_List;  {Parse before plotting to check for alt_sweep}
      If Large_Parts Then Write_Expanded_Parts
      Else
        Begin
          Write_Parts_ListO;
          Write_Board_Parameters;
        End;
      If filled_OK Then Plot_Manager(false,true,false,true,true)
      Else
        Begin
          Draw_Graph(xmin[8],ymin[8],xmax[8],ymax[8],false);
          Pick_Smith(admit_chart);
        End;
      key := F3;
    End; {if file_read}
End; {* Read_Net *}


Procedure Save_Net;
{*
	Routine for saving .puf file.
*}

Var 
  fname : file_string;
  drive : integer;

Begin
  Move_Cursor( 0, 0); {erase residual s-parameters}
  ccompt := Points_compt;
  cx := ccompt^.x_block;
  fname := input_string('File to save:','<'+puff_file+'>');
  If fname='' Then fname := puff_file;
  {Default: save under current file name}
  If Pos(':',fname)=2 Then drive := ord(fname[1])-ord('a')+1
  Else drive := -1;
  If enough_space(drive) Then
    Begin
      If pos('.',fname)=0 Then fname := fname+'.puf';
      Assign(net_file,fname);
    {$I-}
      Rewrite(net_file); {$I+}
      If IOresult=0 Then
        Begin
          puff_file := fname;
          If Not(Large_Smith) Then Write_File_Name(fname);
          save_boardO;
          save_keyO;
          save_partsO;
          save_s_paramsO;
          save_circuitO;
          close(net_file);
          erase_message
        End
      Else
        Begin
          message[1] := 'Invalid filename';
          write_message
        End; {if IOresult}
    End; {if enough}
End; {* Save_Net *}


Procedure check_esc;
{*
	Check that on exit Esc key was not accidently pressed.
*}

Var 
  tcompt : compt;

Begin
  message[1] := 'Exit? Type Esc to';
  message[2] := 'confirm, or other';
  message[3] := '  key to resume  ';
  write_message;
  tcompt := ccompt;
  ccompt := Nil;  {so cursor doesn't blink}
  Repeat
    get_key
  Until key<>screenresize;
  If key <> Esc Then key := not_esc;
  ccompt := tcompt;
  erase_message;
End; {check_esc}


Procedure Toggle_Help_Window;
{*
	Toggle help window in appropriate area of screen.
	help_displayed is a global variable.
*}
Begin
  If help_displayed Then
    Begin
      If (window_number=4) Then
        Begin
          If Large_Parts Then
            Begin
         {Write Large parts list under board window}
              Write_Expanded_Parts;
              Write_Board_Parameters;
              Highlight_Window;
            End
          Else
            Write_Parts_ListO;  {help window was over parts}
        End
      Else If Large_Parts Then
             Begin
               Write_Expanded_Parts;
             End
      Else
        Begin
          Write_Board_Parameters; {help window was over board}
        End;
    End
  Else
    Begin
      If (window_number=4) Then
        Begin
          Board_Help_Window  {Different area then write_commands}
        End
      Else If (window_number=3) Then
             Begin
               If ((Ord(ccompt^.descript[1])>106) )
                 Then
                 Begin
                   ccompt := part_start;   {goto top if part>'i'}
                   cx := ccompt^.x_block;
                 End;
               Write_Commands;  {write commands over Board window}
             End
      Else
        Write_Commands;  {write commands over Board window}
    End;
  help_displayed := Not(help_displayed);
End;


Procedure Toggle_Parts_Lists;
{*
	Toggle between small and large Parts Lists.
*}
Begin
  If Extra_Parts_Used Then
    Begin
      erase_message;
      Message[1] := 'Cannot Toggle.';
      Message[2] := 'Extra parts used';
      Message[3] := 'in Layout.';
      Write_Message;
    End
  Else
    Begin
      If Large_Parts Then
        Begin
       {Clear area}
          clear_window(xmin[3]-1,ymin[3]-1,xmax[5]+1,ymax[5]+1);
       {Write Board and small Parts windows}
          Write_Board_Parameters;
          Write_Parts_ListO;
          Highlight_Window;
       {return pointer to first part}
          ccompt := part_start;
          cx := part_start^.x_block;
        End
      Else
        Write_Expanded_Parts;
      Large_Parts := Not(Large_Parts);
    End; {extra parts}
End; {* Toggle_Parts_Lists *}


Procedure Time_Domain_Manager;
{*
	Procedure for directing time domain functions
	called from the Plot2 window.
*}
Begin
  Erase_Message;
  If Alt_Sweep Then
    Begin
      Message[1] := 'Frequency';
      Message[2] := 'sweep needed';
      Message[3] := 'for time plot';
      Write_Message;
    End
  Else If Large_Smith Then
         Begin
           Message[1] := 'Unavailable';
           Message[2] := 'with large';
           Message[3] := 'Smith chart';
           Write_Message;
         End
  Else
    Begin
      step_fn := key In ['s','S'];
      Plot_Manager(true,true,true,false,true); {time-analyze}
      If (filled_OK And Not(key In['h','H'])) Then
        Time_Response;  {do inverse FFT and time plot}
    End;
End; {* Time_Domain_Manager *}


Procedure Screen_Resize;
{*
	Process resizing of the "screen" (i.e., the X11 window under Linux)
*}

Var 
  tmp: compt;
Begin
  Small_Smith_Coords;
  Screen_Plan;
  clear_window_gfx(xmin[12],ymin[12],xmax[12],ymax[12]);
  tmp := ccompt;
  Set_Up_Board;       { update some stored coordinates in the F4 window }
  Update_KeyO_locations;        { update some stored coordinates in the F2 window }
  ccompt := tmp;
  Fresh_Dimensions;
  { need to call this to update the board size in other variables than the x/ymin/max arrays }
  Get_Coords;         { need to call this to update the magnitude plot vertical scale factor }
  If (Not Large_Smith) Then
    Begin
      Draw_Circuit;
      Write_File_Name(puff_file);
    End;
  Write_Board_Parameters;
  Write_Parts_ListO;
  Write_Message;
  Make_Text_Border(xmin[6]-1,ymin[6]-1,xmax[6]+1,ymax[6]+1,LightRed,true);
  Make_Text_Border(xmin[2]-1,ymin[2]-1,xmax[2]+1,ymax[2]+1,Green,true);
  write_compt(col_window[2],window_f[2]);
  If (Large_Smith) Then Large_Smith_Coords;
  Plot_Manager(false,true,false,true,true);
End; {* Screen_Resize *}



Procedure Layout1;
{*
	Procedure for directing circuit drawing functions in
	the circuit window.
*}
Begin
  missing_part := false;
  write_compt(white,compt1);
  Repeat
    Get_Key;
    If (key <> F3) And read_kbd Then erase_message;
    Case key Of   {these do not effect the keylist}
      Ctrl_e      :
                    Begin
                      Erase_Circuit;
                      write_compt(white,compt1);
                    End;
      Esc         : check_esc;
      F5   : Change_Bk_Color;
      F10         : Toggle_Help_Window;
      screenresize: Screen_Resize;
      Else
        Begin {HKMP bad}
          update_key := read_kbd;
          Case key Of 
            right_arrow : move_net(2,1);
            left_arrow  : move_net(4,1);
            down_arrow  : move_net(8,1);
            up_arrow    : move_net(1,1);
            sh_right    : move_net(2,0);
            sh_left     : move_net(4,0);
            sh_down,Mu  : move_net(8,0);
            sh_up       : move_net(1,0);
            sh_1        : join_port(1,0);
            sh_2        : join_port(2,0);
            sh_3        : join_port(3,0);
            sh_4        : join_port(4,0);
            'a'..'r',
            'A'..'R'    : choose_part(key);
            '1'..'4'    : join_port(ord(key)-ord('1')  +1,1);
            '='         : ground_node;
            '+'         : unground;
            Ctrl_n      : snapO;
            Else
              Begin
                update_key := false;
                If Not(key In [F1..F4,screenresize]) Then beep;
              End;
          End; {case key}
          If update_key Then update_key_list(node_number);
        End;
    End;  {case key}
    dx_dyO;
    write_message;
  Until key In [F2..F4,Esc];
  write_compt(lightgray,compt1);
  If help_displayed Then Write_Board_Parameters;
End; {* Layout1 *}


Procedure Plot2;
{*
	Procedure for directing plotting routines in the Plot window.
*}
Begin
  ccompt := Points_compt;
  cx := ccompt^.x_block;
  previous_key := ' ';
  Repeat
    Get_Key;
    Case key Of 
      '0'..'9','.',' ','-','+'
      : add_char(ccompt);
      Del         : del_char(ccompt);
      backspace   : back_char(ccompt);
      Ins         : insert_key := Not(insert_key);
      Up_Arrow    : move_cursor( 0,-1);
      Down_arrow  : move_cursor( 0, 1);
      Left_arrow  : move_cursor(-1, 0);
      Right_arrow : move_cursor( 1, 0);
      PgDn        : move_marker(-1);
      PgUp        : move_marker(+1);
      '='         : show_real;
      'i','I',
      's','S'     : Time_Domain_Manager;
      Ctrl_s      :
                    Begin
                      If Large_Smith Then Small_Smith_Coords;
                      Save_Net;
                      If Large_Smith Then Large_Smith_Coords;
                    End;
      Ctrl_a      : If Art_Form=2 Then Make_HPGL_file
                    Else Printer_Artwork;
      Ctrl_p      : Plot_manager (true,false,false,true,true); {replot}
      'p','P'     : Plot_manager (true, true,false,false,true); {analyze}
      'q','Q'     : Plot_Manager (true, true, false, false, false);
      Ctrl_q      : Plot_Manager (true, false, false, true, false);
      Tab         : Toggle_Smith_and_Plot;
      Mu {Alt_s}  : Toggle_Large_Smith(F2);
      screenresize: Screen_Resize;
      F5    : Change_Bk_Color;
      F10         : Toggle_Help_Window;
      Esc         : check_esc;
      Else If Not(key In [F1..F4]) Then beep;
    End; {case}
    previous_key := key;
  Until key In [F1,F3,F4,Esc];
  If (key <> ESC) Then Erase_Message;
  If Large_Smith Then Toggle_Large_Smith(key);
  If help_displayed Then Write_Board_Parameters;
End; {* Plot2 *}


Procedure Parts3;
{*
	Procedure for directing editing actions in the parts window.
*}

Label 
  component_start;

Var 
  tmp_file_name : string;

Begin
  ccompt := compt3;
  cx := cx3;
  component_start:
                   Repeat
                     If read_kbd Then get_key;
                     Case key Of 
                       C_R           : Carriage_Return;
                       right_arrow   : move_cursor( 1, 0);
                       left_arrow    : move_cursor(-1, 0);
                       Ins           : insert_key := Not(insert_key);
                       'a'..'z','A'..'Z','0'..'9','+','-','.',',',' ',
                       '(',')',':','\','?','!',Omega,Degree,Parallel,Mu
                       : add_char(ccompt);
                       del           : del_char(ccompt);
                       backspace     : back_char(ccompt);
                       down_arrow    : move_cursor( 0, 1);
                       up_arrow      : move_cursor( 0,-1);
                       '='           : Pars_Single_Part(ccompt);
                       Ctrl_r        :
                                       Begin
                                         tmp_file_name := input_string('File to read:',' ');
                                         If (tmp_file_name<>'') Then
                                           Begin
                                             puff_file := tmp_file_name;
                                             Read_Net(puff_file,false);
                                           End;
                                       End;
                       Ctrl_e        : Erase_Circuit;
                       F5      : Change_Bk_Color;
                       F10           : Toggle_Help_Window;
                       Tab      : Toggle_Parts_Lists;
                       Esc           : check_esc;
                       screenresize  : Screen_Resize;
                       Else If Not(key In [F1..F4]) Then beep;
                     End; {case}
                   Until key In [F1..F4,Esc];
  compt3 := ccompt;
  cx3 := cx;
  If (key <> Esc) And (key<>not_esc) Then
    Begin
      erase_message;
      action := true;
      Pars_Compt_List;
      If bad_compt Then
        Begin
          read_kbd := true;
          cx := ccompt^.x_block;
          Goto component_start;
        End;
    End;
  If Not(board_changed And (key=F4)) Then
    If circuit_changed And (key <>Esc) Then Redraw_Circuit;
  {Delay redraw if F4 and board_changed, in case of error}
  If help_displayed Then
    Begin
      If Large_Parts Then Write_Expanded_Parts
      Else Write_Board_Parameters;
      help_displayed := false;
    End;
End; {* Parts3 *}


Procedure Board4;
{*
	Procedure for directing editing in the Board window.
*}

Label 
  Start_Board_Label;

Begin
  Write_Board_Parameters; {in case a previous help window displayed}
  HighLight_Window;
  ccompt := board_start;
  cx := ccompt^.x_block;
  Start_Board_Label:
                     Repeat
                       Get_Key;
                       Case key Of 
                         '0'..'9','.',' ','E','P','T','G','M','k','m',
                         Mu,'n','p','f','a',Omega,'h','H','z','Z'
                         : add_char(ccompt);
                         Del         : del_char(ccompt);
                         backspace   : back_char(ccompt);
                         Ins         : insert_key := Not(insert_key);
                         Up_Arrow    : move_cursor( 0,-1);
                         Down_arrow  : move_cursor( 0, 1);
                         Left_arrow  : move_cursor(-1, 0);
                         Right_arrow : move_cursor( 1, 0);
                         C_R         : Carriage_Return;
                         Tab         : Toggle_Circuit_Type; {sets board_changed}
                         F10         : Toggle_Help_Window;
                         F5    : Change_Bk_Color;
                         Esc         : check_esc;
                         screenresize: Screen_Resize;
                         Else
                           If Not(key In [F1..F4]) Then beep;
                       End; {case}
                     Until key In [F1..F3,Esc];
  If (key <> Esc) Then
    Begin
      erase_message;
      action := true;
      Board_Parser;     {compute new board parameters}
      If bad_compt Then
        Begin
          read_kbd := true;
          cx := ccompt^.x_block;
          Goto Start_Board_Label;
        End;
      If board_changed Then
        Begin
          Fresh_Dimensions;          {load in new board parameters}
          Write_Plot_Prefix(false);  {write new prefix for x-coord}
          Pars_Compt_List;       {compute new component parameters}
          If bad_compt Then
            Begin
              read_kbd := true;                    {If error occurs, }
              cx := ccompt^.x_block;            {point to last change}
              Goto Start_Board_Label;
            End;
          Redraw_Circuit;
        End;
    End;
  If Large_Parts Then Write_Expanded_Parts
  Else If help_displayed Then Write_Parts_ListO;
End; {* Board4 *}



(***************************************************************
			Main Program
****************************************************************)

Begin
  Puff_Start;
  Init_Marker (dev_beg);   {Init device file memory block}
  Init_Marker (net_beg);   {Init network memory block}
  Read_Net(puff_file,true);
  read_kbd := Not(circuit_changed);
  Repeat
    window_number := Ord(key)-Ord(F1)+1;
    help_displayed := false;
    HighLight_Window;
    Case window_number Of 
      1 : Layout1;
      2 : Plot2;
      3 : Parts3;
      4 : Board4;
    End;
    If Not( (window_number=4) And Large_Parts) Then
      write_comptm(3,col_window[window_number],window_f[window_number]);
  Until key= Esc;
  CloseGraph;
  TextMode(OrigMode);
  ClrScr;
End.
