{$R-}    {Range checking}
{$S-}    {Stack checking}
{$B-}    {Boolean complete evaluation or short circuit}
{$I+}    {I/O checking}


Unit pfun1;


(*********************************************************************

	UNIT PFUN1.PAS

        This code is now licenced under GPLv3.

	Copyright (C) 1991, S.W. Wedge, R.C. Compton, D.B. Rutledge.
        Copyright (C) 1997,1998, A. Gerstlauer.

        Modifications for Linux compilation 2000-2007 Pieter-Tjerk de Boer.

	Code cleanup for Linux only build 2009 Leland C. Scott.

	Original code released under GPLv3, 2010, Dave Rutledge.


	Contents: 	Variable declarations, constants, and types
			Graphics Routines, message routines,
			complex math, microstip and stripline
			models, parsing routines.

	Potentially buggy code is noted by {!xxx} comments

**********************************************************************)

Interface

Uses 
Dos,   {Unit found in Free Pascal RTL's}
Printer,  {Unit found in Free Pascal RTL's}
xgraph; {Custom replacement unit for TUBO's "Crt" and "Graph" units}


Const 

{* The following constants are the keyboard return codes.
   See Turbo Manual Appendix K.
   For the extended codes 27 XX, key=#128+XX 		*}
  not_esc = #0;
  Ctrl_a = #1;
  Ctrl_d = #4;
  Ctrl_e = #5;
  backspace = #8;
  Ctrl_n = #14;
  Ctrl_p = #16;
  Ctrl_r = #18;
  Ctrl_s = #19;
  Ctrl_c = #3;
  Ctrl_q = #17;
  Esc = #27;
  sh_1 = #33;
  sh_3 = #35;
  sh_4 = #36;
  sh_2 = #64;
  Alt_o = #152;
  Alt_d = #160;
  Alt_m = #178;
  Alt_p = #153;
  Tab = #9;
  sh_down = #178;
  sh_left = #180;
  sh_right = #182;
  sh_up = #184;
  C_R = #13;
  F1 = #187;
  F2 = #188;
  F3 = #189;
  shift_F3 = #214;
  F4 = #190;
  F5 = #191;
  F6 = #192;
  shift_F5 = #216;
  F10 = #196;
  Alt_s = #159;
  up_arrow = #200;
  PgUp = #201;
  left_arrow = #203;
  right_arrow = #205;
  down_arrow = #208;
  PgDn = #209;
  Ins = #210;
  Del = #211;
  screenresize = #255; { pseudo key, used to report a screen size change in the Linux version }
 {The following characters refer to extended graphics character set}
 {Lambda=#128;}
  Delta = #235; {Shift_arrow=#130;}
  the_bar = #179;
 {ground=#132;}
  infin = #236;
  ity = #32;
  Parallel = #186;
  Mu = #230;
  Omega = #234;
  Degree = #248;
  lbrack = #123;
  rbrack = #125;

  des_len = 22;

 {* Number of parts in parts list *}
  max_net_size = 9;
 {* Conv_size is maximum matrix size for sdevice et al.*}
  Conv_size = 9;

  col_window : array[1..4] Of integer = (Lightcyan,Lightgreen,Yellow,Lightblue);
  s_color    : array[1..4] Of integer = (Lightred,Lightcyan,Lightblue,Yellow);
 {* Engineering Decimal multipliers *}
  Eng_Dec_Mux : set Of char = ['E','P','T','G','M','k',
                              'm', Mu,'n','p','f','a'];
  charx = 8;
  chary = 14;
  key_max = 2000;
  max_ports = 4;
  max_params = 4;

  one: double = 0.999999999998765;
  {* Attenuation factor for tee's, crosses,
 			           shorts, opens and negative resistors  *}
  minus2 :  integer = -2;
  {* Global const needed by the Assembler
 				   Routines for Sine_Asm, Cos_Asm 	*}
  ln10   :  double = 2.302585092994045684;
  Pi     :  double = 3.141592653;  {* Use only 10 digits of Pi to *}
  infty  :  double = 1.0e+37;      {* ensure numerical stability  *}
  nft = 256;       {* Number of FFT points *}
  c_in_mm: double = 2.99792458e+11;             {* Speed of light in mm/s *}
  Mu_0: double    = 1.25664e-6;  {* Permeability of free space H/m *}

(***** Temp Circuit Board constants ***************)


(**************************************************)

Type 
  textfile     = text;
  line_string  = String[des_len];
  file_string  = String[127];
  char_s       = array[1..112] Of byte;


{* POINTER Types *}

  s_param      = ^s_parameter_record;
  plot_param   = ^plot_record;
  spline_param = ^spline_record;
  net          = ^net_record;
  conn         = ^connector_record;
  compt        = ^compt_record;

  marker       = Record
    Used: LONGINT;
  End;


{********************* PUFF DATA STRUCTURES ****************}

  TComplex = Record
    r,i : double;  {! This was changed from a real for speed increase}
  End;

  PMemComplex = ^TMemComplex;
  TMemComplex = Record
    c: TComplex;
  End;

  s_parameter_record = Record
    z          : PMemComplex;
    next_s     : s_param;
  End;

  plot_record = Record
    next_p,prev_p : plot_param;
    filled        : boolean;
    x,y           : double;
  End;

  spline_record = Record
    next_c,prev_c : spline_param;
    sx,sy,h       : double;
  End;

  net_record = Record
    com                   : compt;
    con_start             : conn;
    xr,yr                 : double; {postion in mm}
    node,chamfer,grounded : boolean;
    next_net,other_net    : net;
    nx1,nx2,ny1,ny2,
    number_of_con,nodet,
    ports_connected    : integer;
  End;

  connector_record = Record
    port_type,conn_no : integer; {0 norm 1... max_port external 5,6 internal}
    cxr,cyr           : double;    {position in mm}
    dir               : byte;
    net               : net;
    next_con,mate     : conn;
    s_start           : s_param;
  End;

  compt_record = Record
    lngth,width,zed,zedo,init_ere,
    alpha_c,alpha_d,alpha_co,alpha_do,
    lngth0,wavelength,wavelengtho,
    zed_e0,zed_o0,zed_S_e0,zed_S_o0,
    e_eff_e0,e_eff_o0,
    u_even,u_odd,g_fac,
    con_space,spec_freq    : double;
    xp,xmaxl,x_block,
    xorig,yp,number_of_con,used         : integer;
    s_begin,s_file,s_ifile,f_file        : s_param;
    calc,changed,right,super,
    parsed,step,sweep_compt   : boolean;
    next_compt,prev_compt       : compt;
    descript                    : line_string;
    typ                         : char;
  End;

  key_record = Record
    keyl      : char;
    noden     : integer;
  End;

{* The following types are defined for S parameter conversions: *}
{* Conv_size is currently set to 9 *}
  s_conv_matrix = array [1..conv_size,1..conv_size] Of TComplex;
  s_conv_vector = array [1..conv_size] Of TComplex;
  s_conv_index  = array [1..conv_size] Of integer;

{**************** PUFF OBJECTS **********************}

  Sweep = Object
    element     : compt;   {pointer to part}
    id,prefix,units      : char;    {ident, prefix and units}
    part_label,unit_label   : string[6]; {labels for plot window}
    prop_const1,prop_const2 : double;  {Proportionality constants}
    index      : integer; {Part type index}
    Omega0,new_value    : double; {angular frequency at fd and new value}
    used       : boolean; {has sweep been used?}
    Procedure Init_Use;
    Procedure Init_Element(tcompt : compt; in_id,in_prefix,in_unit : char);
    Procedure Check_Reset(tcompt : compt);
    Procedure Label_Axis;
    Procedure Label_Plot_Box;
    Procedure Load_Prop_Const(Const prop_consta,prop_constb : double);
    Procedure Load_Index(i : integer);
    Procedure Load_Data(Const sweep_data : double);
  End; {sweep object}




{**************** PUFF VARIABLES ********************}

Var 
  co1           : TComplex;                     {1+j0}
  c_s           : s_param;
  conk,ccon     : conn;
  sresln        : string[9];
  big_text_buf  : array[1..2048] Of char; { 2k buffer for net_ and dev_ files}
  sdevice       : s_conv_matrix;
  x_sweep       : sweep;    {x_sweep is the object with x-y plot information}
  iji           : array[1..16,1..2] Of integer;
  key_list      : array[1..key_max] Of key_record;{List decribing circuit}
  board         : array[1..16] Of boolean;        {used in reading board setup}
  s_key         : array[1..10] Of line_string;    {plot window paramters}
  s_board       : array[1..12,1..2] Of line_string;{board window parameters}
  s_param_table : array[1..max_params] Of compt;  {Which s-params to plot}
  xvalo,yvalo   : array[1..4] Of integer;         {used by plotting in rcplot}
  cross_dot     : array[1..35] Of integer;        {Dot colors under cross}
  box_dot       : array[1..26,0..8] Of integer;   {Dot colors under markers}
  box_filled    : array[1..8] Of boolean;         {true if box_dot set}
  portnet       : array[0..max_ports] Of net;     {Record of port}
  inp,out       : array[1..max_ports] Of boolean; {Is port input or output?}
  si,sj         : array[1..max_ports] Of integer;
  mate_node     : array[1..4] Of net;             {used in layout of clines}
  message       : array[1..3] Of file_string;     {Displayed message}

 {* The following graphics variables were constants in Puff 1.5 *}

  xmin : array[1..12] Of integer;{These were constants in the EGA version}
  ymin : array[1..12] Of integer;{They contain both text and graphics}
  xmax : array[1..12] Of integer;{positions for each of the windows}
  ymax : array[1..12] Of integer;
  centerx, centery, rad  : integer;  {Smith chart position variables}
  Max_Text_X : integer;   {Needed for extra wide windows on Linux}
  Max_Text_Y : integer;   {Used for 25/34 line EGA/VGA switch}
  yf   : double;   {used to specify aspect ratios}
  x_y_plot_text  : array[1..6,1..2] Of integer;
  filename_position  : array[1..3] Of integer;
  checking_position,
  layout_position     : array[1..2] Of integer;

  puff_file     : file_string;

  net_file,dev_file       : textfile;
  command_f,window_f      : array[1..4] Of compt; {was 1..3}
  spline_start,spline_end : spline_param;  {Start and end of list of s-params}
  dirn{,cursor_char}        : byte;          {dirn 1=North 2=East 4=West 8=South}
  name,network_name       : line_string;   {Names put on artwork}
  key,key_o,
  chs,previous_key,            {keys for linked list}
  freq_prefix          : char;  {prefix for design_freq}
  plot_start,plot_end,
  c_plot,plot_des   : array[1..max_params] Of plot_param;
                                    {start, end, current and design s-params}
  net_beg,   {Mark() beginning of network for later release}
  dev_beg   {Mark() beginning of device file data for release}
  : marker;

  Box_Sv_Pntr   : Array [1..8] Of Pointer;
  Box_Sv_Size   : Array [1..8] Of Word;

  fmin,finc,              {frequency minimum,frequency increment}
  Z0,                     {characteristic impedance}
  rho_fac,                {radius factor of smith chart}
  q_fac,                  {fd/df=Q}
  resln,                  {resolution of circuit drawing in mm}
  sfx1,sfy1,              {scale factors for pixels for circuit drawing}
  xrold,yrold,sigma,
  sxmax,sxmin,
  symax,symin,   {max and min values on rectangular plot}
  reduction,              {photographic reduction ratio}
  er,                     {relative substrate dielectric constant}
  bmax,                   {substrate board size in mm}
  substrate_h,            {substrate thickness}
  con_sep,                {connector seperation}
  freq,design_freq,  {current frequency and design frequency in GHz}
  Rs_at_fd,   {Sheet resistance at design frequency}
  Lambda_fd,   {Wavelength in mm, in air, at design freq}
  xm,ym,                  {circuit cursor postion in mm}
  psx,psy,csx,csy,
  artwork_cor,
  miter_fraction,
  widthZ0,                {width of normalizing impedance}
  lengthxm,lengthym,      {length in x and y current part}
  Manh_length,   {Manhattan layout length - read_board}
  Manh_width,   {Manhattan layout width - read_board}
  conductivity,   {units are mhos/meter}
  loss_tangent,           {for dielectric, unitless}
  metal_thickness,    {in millimeters}
  surface_roughness       {in micrometers}
  : double;

  cwidthxZ02,cwidthyZ02,
  pwidthxZ02,pwidthyZ02,  {screen and mask half width Z0}
  message_color,          {color in message block}
  key_i,key_end,
  xi,xii,yi,yii,
  window_number,          {current window number}
  ptmax,                  {maximum number of graph points}
  spx,spy,spp,            {Re(s),Im(s),|s| dot position}
  displayo,display,
  Art_Form,   {0 if dot-matrix, 1 LaserJet, 2 HPGL}
  idb,iv,xpt,
  npts,cx,cx3,
  min_ports,imin,
  OrigMode,  {used to remember initial text mode}
  GraphDriver,GraphMode {Used for graphics initialization}
  : integer;

  blackwhite: boolean;

  read_kbd,board_read,
  insert_key,
  step_fn,stripline,
  update_key,
  spline_in_rect,
  spline_in_smith,
  Laser_Art,  {True if LaserJet printer selected}
  filled_OK,remain,
  admit_chart,  {admittance smith chart flag}
  circuit_changed,
  board_changed,
  marker_OK,p_labels,
  bad_compt,action,
  demo_mode,
  help_displayed, {is help window currently displayed?}
  port_dirn_used,
  Extra_Parts_Used,      {True when a part j..r has been used for layout}
  Large_Parts,  {true when extra parts are selected}
  Large_Smith,  {is large Smith chart enabled? VGA only}
  Alt_Sweep,   {do alternate parameter sweep}
  Manhattan_Board, {Draw all parts in Manhattan Geometry}
  missing_part  {True if part used in layout was deleted}
  : boolean;

  Points_compt,rho_fac_compt,
  part_start,coord_start,
  board_start,
  ccompt,compt1,compt3,
  dBmax_ptr,
  fmin_ptr  : compt;

  netK,netL,cnet,
  net_start       : net;

{***** INTERFACE List of Functions and Procedures to be Public *****}

Procedure puff_draw(x1,y1,x2,y2,color : integer);
Procedure Draw_Box(xs,ys,xm,ym,color : integer);
Procedure Make_Text_Border(x1,y1,x2,y2,colour: integer; single : boolean);
Procedure fill_box(x1,y1,x2,y2,color : integer);
Procedure clear_window(x1, y1, x2, y2 : integer);
Procedure clear_window_gfx(x1, y1, x2, y2 : integer);
Procedure pattern(x1,y1,ij,pij : integer);
Procedure box(x,y,ij : integer);
Procedure write_compt(color : integer; tcompt : compt);
Procedure write_comptm(m,color : integer; tcompt : compt);
Procedure beep;
Procedure rcdelay(j : integer);
Procedure write_message;
Procedure erase_message;
Procedure write_error(Const time : double);
Function input_string(Const mess1,mess2 : line_string) : file_string;
Procedure dirn_xy;
Procedure increment_pos(i : integer);
Procedure lengthxy(tnet : net);
Function betweenr(Const x1,x2,x3,sigma : double) : boolean;
Function betweeni(x1,x2,x3 : integer) : boolean;
Function ext_port(tcon : conn) : boolean;


(****** These were sine_asm, cosine_asm, ln_asm ****
function Sin_387(theta_in : extended) :extended;
function Cos_387(theta_in : extended) : extended;
function Ln_387(arg_in : extended) : extended;
************* removed for 5.5 testing *****************)
{* Complex Arithmetic *}
Procedure prp(Var vu: TComplex; Const vX,vY : Tcomplex);
Procedure supr(Var vu: TComplex; Const vX,vY : TComplex);
Procedure co(Var co: TComplex; Const s,t : double);
Procedure di(Var di: TComplex; Const s,t : Tcomplex);
Procedure su(Var su: TComplex; Const s,t : Tcomplex);
Procedure rc(Var rc: TComplex; Const z : Tcomplex);
Procedure sm(Var sm: TComplex; Const s : double; Const t : Tcomplex);
Function co_mag(Const z : Tcomplex) : double;
{* Parsing utilities *}
Function Eng_Prefix(c : char) : double;
Function Manhattan(tcompt : compt) : boolean;
Function super_line(tcompt : compt) : boolean;
Function goto_numeral(n : integer; x : line_string) : integer;
Function Get_Real(tcompt : compt; n : integer) : double;
Procedure Get_Param(tcompt : compt; n : integer; Var value : double;
                    Var value_string: line_string; Var u1,prefix: char; Var alt_param: boolean);
Procedure Get_Lumped_Params(tcompt: compt; Var v1,v2,v3,v4:double;
                            Var u,last_ID,last_prefix: char; Var alt_param,parallel_cir : boolean);
Function arctanh(Const x:double) : double;
Function kkk(Const x:double) : double;
Function widtht(Const zed:double) : double; {width in mm}
Function sinh(Const x : double) : double;
Function cosh(Const x : double) : double;
{* function cl_cosh(x : double) : double; *}
Function arccosh(Const x : double) : double;
Procedure error(Const g,wo,ceven : double; Var fg,dfg : double);
Procedure w_s_stripline_cline(Const zede,zedo : double; Var woh,soh : double);
Procedure w_s_microstrip_cline(Const we,wo : double; Var woh,soh : double);
Procedure shutdown;
Function fileexists(note:boolean;Var inf:textfile;fname:file_string): boolean;
Function setupexists(Var fname : file_string) : boolean;
Function atan2(Const x,y : double) : double;
Function enough_space(defaultdrive : integer) : boolean;
Function node_number : integer;
Procedure update_key_list(nn : integer);
Procedure Carriage_Return;
Procedure move_cursor(x1,y1 : integer);
Function tanh(Const x : double) : double;
Function KoK(Const k : double) : double;
Procedure capac(Const W_h,S_h,er : double;Var ce,co : double);
Procedure ere_even_odd(Const W_h,S_h:double;Var ee,eo:double);
Procedure Indef_Matrix(Var S : s_conv_matrix; n : integer);

{* Uses internal Procedures:
	LU_Decomp();
	LU_Sub();
	Matrix_Inversion();
	Matrix_Mux();
	Matrix_Conv();
*}
Function HeapFunc(Size:word) : integer;
Function No_mem_left : boolean;


(******************** Memory management *****************************)


Procedure Init_Mem;

Function Mem_Left: LONGINT;


Procedure New_c (Var P: PMemComplex);
Procedure New_s (Var P: s_param);
Procedure New_plot (Var P: plot_param);
Procedure New_spline (Var P: spline_param);
Procedure New_n (Var P: net);
Procedure New_conn (Var P: conn);
Procedure New_compt (Var P: compt);

Procedure Init_Marker (Var P: marker);
Function Marked (Var P: marker): BOOLEAN;
Procedure Mark_Mem (Var P: marker);
Procedure Release_Mem (Var P: marker);

Procedure Copy_Networks (NetStart, NetEnd: marker; Var CopyNetStart: marker);

{ ----------------------------- }

Procedure SetCol(col: word);
Procedure TextCol(col: word);


Implementation

(********************* Graphics Procedures and Functions *************)

Procedure puff_draw(x1,y1,x2,y2,color : integer);
{*
	Line drawing routine.
	Only used by draw_ticks,
	Draw_Smith, and draw_to_port.
*}
Begin
  SetCol(color);
  Line(x1,y1,x2,y2);
End; {* puff_draw *}


Procedure Draw_Box(xs,ys,xm,ym,color : integer);
{*
	This procedure reduced using new graphics.
*}
Begin
  SetCol(color);
  Rectangle(xs,ys,xm,ym);
End; {draw_box}



Procedure fill_box(x1,y1,x2,y2,color : integer);

{*
	This procedure has been drastically reduced using
	Turbo Pascal graphics.  
	 
	Used for erasing sections of the screen (color=brown)
	and for drawing	tlines (color=white).
*}
Begin
  If (blackwhite) Then SetFillStyle(SolidFill, white)
  Else SetFillStyle(SolidFill,Color);
  Bar(x1,y1,x2,y2);
End; {fill_box}


Procedure clear_window(x1, y1, x2, y2 : integer);

{*
	Clear region of screen. Text coordinates are the input.
	Erasing was done in textmode, now in graphics mode.
*}
Begin

(*
  Window(x1,y1,x2,y2);   {specify area as window}
  TextCol(black);      {Here TextColor behaves as background}
  ClrScr;  		 {clear to background color}
*)
  Window(1,1,Max_Text_X,Max_Text_Y);     {return to default window}
  SetFillStyle(SolidFill,Black);
  Bar(8*(x1-1),14*(y1-1),8*x2,14*y2)
End; {clear_window}


Procedure clear_window_gfx(x1, y1, x2, y2 : integer);

{*
	Clear region of screen. Graphics coordinates are the input.
	Erasing was done in textmode, now in graphics mode.
*}
Begin
  Window(1,1,Max_Text_X,Max_Text_Y);     {return to default window}
  SetFillStyle(SolidFill,Black);
  Bar(x1,y1,x2,y2)
End; {clear_window_gfx}


Procedure Make_Text_Border(x1,y1,x2,y2,colour: integer; single : boolean);
{*	
	Creates text border pattern for start screen and other windows
*}

Const 
  sing_vert = #179;
  doub_vert = #186;  {side bars}
  sing_horz = #196;
  doub_horz = #205;
  sing_UL = #213;
  doub_UL = #201;      {corner bars}
  sing_UR = #184;
  doub_UR = #187;
  sing_LL = #212;
  doub_LL = #200;
  sing_LR = #190;
  doub_LR = #188;

Var 
  vert,horz,UL,
  UR,LL,LR   : char;
  i   : integer;

Begin
  If single Then
    Begin
      vert := sing_vert;
      horz := doub_horz;
      UL := sing_UL;
      UR := sing_UR;
      LL := sing_LL;
      LR := sing_LR;
    End
  Else
    Begin
      vert := doub_vert;
      horz := doub_horz;
      UL := doub_UL;
      UR := doub_UR;
      LL := doub_LL;
      LR := doub_LR;
    End;
  clear_window(x1,y1,x2,y2);   {clear area}
  TextCol(colour);
  For i := y1 To y2 Do
    Begin     {* Draw Border for startup screen *}
      GotoXY(x1,i);
      Write(vert);
      GotoXY(x2,i);
      Write(vert);
    End;
  For i := x1 To x2 Do
    Begin
      GotoXY(i,y1);
      Write(horz);
      GotoXY(i,y2);
      Write(horz);
    End;
  GotoXY(x1,y1);
  Write(UL);
  GotoXY(x2,y1);
  Write(UR);
  GotoXY(x1,y2);
  Write(LL);
  GotoXY(x2,y2);
  Write(LR);
End; {* Make_Text_Border *}


Procedure pattern(x1,y1,ij,pij : integer);
{*
	Draw marker pattern for s-parameter plots
	ij=1 box, ij=2 X, ij=3 diamond, ij=4 +
*}
Begin
  SetCol(s_color[ij]);
  Case ij Of 
    1 : Rectangle(x1-3,y1-3,x1+3,y1+3); {draw the box}
    2 :
        Begin  {draw X}
          Line(x1-3,y1-3,x1+3,y1+3);
          Line(x1-3,y1+3,x1+3,y1-3);
        End;
    3 :
        Begin {draw diamond}
          Line(x1-4,y1,x1,y1+4);
          Line(x1-3,y1-1,x1,y1-4);
          Line(x1+4,y1,x1+1,y1+3);
          Line(x1+3,y1-1,x1+1,y1-3);
        End;
    4 :
        Begin {draw +}
          Line(x1-4,y1  ,x1+4,y1  );
          Line(x1  ,y1+4,x1  ,y1-4);
        End;
  End;{case}
End; {pattern}


Procedure box(x,y,ij : integer);
{*
	Draw small box to indicate where s-parameters are calculated.
*}
Begin
  Case ij Of 
    2 :
        Begin
          Dec(y);
          Dec(x);
        End;
    3 : Dec(x);
    4 : Dec(y);
  End; {case}
  PutPixel(x,y,s_color[ij]);
  PutPixel(x+1,y,s_color[ij]);
  PutPixel(x,y+1,s_color[ij]);
  PutPixel(x+1,y+1,s_color[ij]);
End; {box}


Procedure write_compt(color : integer; tcompt : compt);
{*
	Display a component -- highlighted
*}
Begin
  TextCol(color);
  With tcompt^ Do
    Begin
      gotoxy(xp,yp) ;
      write(descript);
    End;
End; {* write_compt *}


Procedure write_comptm(m,color : integer; tcompt : compt);
{*
	Display the first m characters of a component.
*}

Var 
  i : integer;

Begin
  TextCol(color);
  With tcompt^ Do
    Begin
      gotoxy(xp,yp);
      For i:=1 To m Do
        write(descript[i]);
    End;
End; {* write_comptm *}


Procedure beep;
{*
	Make the Puff tone.
*}
Begin
  Sound(250);
  Delay(50);
  Nosound;
End;


Procedure rcdelay(j : integer);
{*
	Interuptable delay for use in demo mode.
*}

Var 
  i : integer;

Begin
  For i:=1 To j Do
    Begin
      If keypressed Then
        Begin
          chs := Readkey;
          If chs='S' Then
            Begin
              beep;
              textmode(co80);
              halt(1);
            End
          Else
            delay(2000);
        End
      Else
        delay(10);  {if keypressed}
    End; {for i:= 1 to j}
End; {rcdelay}


Procedure write_message;
{*
	Write message in center box.
*}
Begin
  TextCol(message_color);
  Gotoxy((xmin[6]+xmax[6]-length(message[1])) div 2,ymin[6]);
  Write(message[1]);
  Gotoxy((xmin[6]+xmax[6]-length(message[2])) div 2,ymin[6]+1);
  Write(message[2]);
  Gotoxy((xmin[6]+xmax[6]-length(message[3])) div 2,ymin[6]+2);
  Write(message[3]);
  If (message[1]+message[2]+message[3] <> '') And read_kbd Then beep;
  If demo_mode Then rcdelay(50);
End; {write_message}


Procedure Erase_message;
{*
	Erase message in center box.
*}
Begin
  clear_window(xmin[6],ymin[6],xmax[6],ymax[6]); {set up window}
  Message[1] := '';
  Message[2] := '';
  Message[3] := '';
End; {Erase_message}


Procedure write_error(Const time : double);
{*
	Flash error message in message window.
*}
Begin
  write_message;
  delay(Round(1000*time));
  erase_message;
End; {write_error}


Function input_string(Const mess1,mess2 : line_string) : file_string;
{*
	Prompt user to input string (filename).
	The escape key cannot be used to exit here.
*}

Var 
  answer : file_string;

Begin
  Erase_message;
  Window(xmin[6],ymin[6],xmax[6],ymax[6]); {set up window for oversized text}
  TextCol(Yellow);
  WriteLn(mess1);
  WriteLn(mess2);
  Write('?');
  ReadLn(answer);
  input_string := answer;
  Erase_message;
End; {input_string}


Procedure dirn_xy;
{*
	Checks cursor direction.
	Maps dirn into x and y changes.
*}
Begin
  xii := 0;
  yii := 0;
  Case dirn Of 
    2 : xii := 1; {East}
    4 : xii := -1; {West}
    8 : yii := 1; {South}
    1 : yii := -1; {North}
  End;
End; {dirn_xy}


Procedure increment_pos(i : integer);
{*
	Increment postion of cursor on circuit.
*}
Begin
  dirn_xy;
  If odd(i) Then
    Begin
      If i=-1 Then
        Begin     {step 1/2 of compt}
          xm := xm+(compt1^.lngth*xii+yii*compt1^.con_space)/2.0;
          ym := ym+(compt1^.lngth*yii+xii*compt1^.con_space)/2.0;
        End
      Else
        Begin
          If (compt1^.typ In ['i','d']) Then
            Begin
              If compt1^.number_of_con <>1 Then
                Begin
                  xm := xm+lengthxm*xii/(compt1^.number_of_con-1);
                  ym := ym+lengthym*yii/(compt1^.number_of_con-1);
                End;
            End
          Else
            Begin
              xm := xm+lengthxm*xii;
              ym := ym+lengthym*yii;
            End;
        End;
    End {if odd i}
  Else
    Begin
      If i=0 Then
        Begin
          xm := cnet^.xr;
          ym := cnet^.yr;
        End
      Else
        Begin
          If (compt1^.typ In ['i','d']) Then
            Begin
              xm := xm+lengthxm*xii/(compt1^.number_of_con-1);
              ym := ym+lengthym*yii/(compt1^.number_of_con-1);
            End
          Else
            Begin
              xm := xm+lengthxm*xii-compt1^.con_space*yii;
              ym := ym+lengthym*yii-compt1^.con_space*xii;
            End;
        End; {if i else}
    End; {if odd else}
  xi := Round(xm/csx);
  yi := Round(ym/csy);
  If (Not(compt1^.typ In ['i','d'])) Or (i<=0)
     Or (i=(compt1^.number_of_con-1)) Then
    Case dirn Of 
      1 : dirn := 8;
      2 : dirn := 4;
      4 : dirn := 2;
      8 : dirn := 1;
    End; {case}
End; {increment pos}


Procedure lengthxy(tnet : net);
{*
	Convert part lengths and widths to increments 
	in the x and y directions.
*}

Var 
  lengths,widths : double;

Begin
  dirn_xy;
  If tnet <> Nil Then
    Begin
      lengths := tnet^.com^.lngth;
      widths := tnet^.com^.width;
    End
  Else
    writeln(lst,'error');
  lengthxm := lengths*abs(xii)+widths*abs(yii);
  lengthym := lengths*abs(yii)+widths*abs(xii);
End; {lengthxy}


Function betweenr(Const x1,x2,x3,sigma : double) : boolean;
{*
	True if real x2 is between x1-sigma and x3+sigma.
*}
Begin
  If x1 > x3 Then
    Begin
      If (x3-sigma<= x2 ) And (x2 <= x1+sigma) Then
        betweenr := true
      Else
        betweenr := false;
    End
  Else
    Begin
      If (x1-sigma<= x2 ) And (x2 <= x3+sigma) Then
        betweenr := true
      Else
        betweenr := false;
    End;
End;


Function betweeni(x1,x2,x3 : integer) : boolean;
{* 
	Check to see that x2 is between x1 and x3
*}
Begin
  If (x1 <= x2 ) And (x2 <= x3) Then
    betweeni := true
  Else
    betweeni := false;
End;


Function ext_port(tcon : conn) : boolean;
{*
	Check to see if a connector is joined to an external port.
*}
Begin
  ext_port := betweeni(1,tcon^.port_type,min_ports);
End;


{******************** Complex Number Utilities ***********************}

Procedure prp(Var vu: TComplex; Const vX,vY: TComplex);
{*
	Complex product.
	Multiply two complex numbers.
*}
Begin
  vu.r := vX.r*vY.r-vX.i*vY.i;
  vu.i := vX.r*vY.i+vX.i*vY.r;
End;


Procedure supr(Var vu: TComplex; Const vX,vY: TComplex);
{*
	Complex sum and product.
	Multiply two complex numbers and add.
	vu = vu + vx*vy
*}
Begin
  vu.r := vu.r+vX.r*vY.r-vX.i*vY.i;
  vu.i := vu.i+vX.r*vY.i+vX.i*vY.r;
End;


Procedure diffpr(Var vu: TComplex; Const vX,vY: TComplex);
{*
	Complex difference and product.
	Multiply two complex numbers and subtract.
	vu = vu - vX*vY
*}
Begin
  vu.r := vu.r-vX.r*vY.r+vX.i*vY.i;
  vu.i := vu.i-vX.r*vY.i-vX.i*vY.r;
End;


Procedure co(Var co: TComplex; Const s,t : double);
{*
	Create a complex number type.
*}
Begin
  co.r := s;
  co.i := t;
End; {co}


Procedure di(Var di: TComplex; Const s,t: TComplex);
{*
	Calculate difference of two complex numbers (s - t).
*}
Begin
  di.r := s.r - t.r;
  di.i := s.i - t.i;
End; {di}


Procedure su(Var su: TComplex; Const s,t: TComplex);
{*
	Calculate sum of two complex numbers (s + t).
*}
Begin
  su.r := s.r + t.r;
  su.i := s.i + t.i;
End; {s+t}


Procedure rc(Var rc: TComplex; Const z: TComplex);
{*
	Calculate the reciprocal of a complex number (1/z).
*}

Var 
  mag : double;         {! was real, changed 10/15/90}

Begin
  mag := sqr(z.r)+sqr(z.i);
  {!* check for 1/0 added here *}
  If (mag=0.0) Then
    Begin
      rc.r := 0.0; {Although this is equivalent to saying 1/0 = 0}
      rc.i := 0.0; {it works properly for the few times it occurs}
    End
  Else
    Begin
      rc.r := z.r/mag;
      rc.i := -z.i/mag ;
    End;
End; {* 1/z *}


Procedure sm (Var sm: TComplex; Const s: double; Const t: TComplex);
{*
	Scale magnitude of a complex number s*t.
*}
Begin
  sm.r := s * t.r;
  sm.i := s * t.i;
End; {sm or s*t}


Function co_mag (Const z: TComplex): double;
{*
	Compute magnitude of a complex number.
	Used for pivoting in matrix inversion routines.
*}
Begin
  co_mag := sqrt (sqr(z.r) + sqr(z.i));
End; {* co_mag *}


Procedure Equate_Zs (Var z1: TComplex; Const z2: Tcomplex);
{*
	sets z1 := z2;
*}
Begin
  z1.r := z2.r;
  z1.i := z2.i;
End;


{*********************** Parsing Utilities ***********************}

Function Eng_Prefix(c : char) : double;
{*
	Find multiplication factor for engineering prefixes
*}
Begin
  Case c Of 
    'E' : Eng_Prefix := 1.0e+18;
    'P' : Eng_Prefix := 1.0e+15;
    'T' : Eng_Prefix := 1.0e+12;
    'G' : Eng_Prefix := 1.0e+09;
    'M' : Eng_Prefix := 1.0e+06;
    'k' : Eng_Prefix := 1.0e+03;
    'm' : Eng_Prefix := 1.0e-03;
    Mu  : Eng_Prefix := 1.0e-06;
    'n' : Eng_Prefix := 1.0e-09;
    'p' : Eng_Prefix := 1.0e-12;
    'f' : Eng_Prefix := 1.0e-15;
    'a' : Eng_Prefix := 1.0e-18;
    Else
      Eng_Prefix := 1.0;
  End; {case}
End; {* Eng_Prefix *}


Function Manhattan(tcompt : compt) : boolean;

{*
	Determine if Manhattan layout has been selected.
	Looks for 'M' at the end of tcompt^.descript
	 or a '?' anywhere in the description.
*}

Var 
  c_string : line_string;
  long    : integer;

Begin
  If Manhattan_Board Then
    Manhattan := true
  Else
    Begin
      c_string := tcompt^.descript;
      long := length(c_string);
      While c_string[long]=' ' Do
        Dec(long); {ignore end blanks}
    {* Select Manhattan if last character is an 'M' *}
      If c_string[long]='M' Then Manhattan := true
      Else Manhattan := false;
    {* Select Manhattan if a '?' is present in clines or tline *}
      While (long>0) Do
        Begin
          If (c_string[long]='?') And (tcompt^.typ In ['c','t'])
            Then Manhattan := true;
          Dec(long);
        End;
    End; {else}
End; {* Manhattan *}


Function super_line(tcompt : compt) : boolean;
{*
	Determine if super line has been selected.
	Looks for '!' anywhere in tcompt^.descript.
*}

Var 
  c_string : line_string;
  long    : integer;

Begin
  super_line := false;
  c_string := tcompt^.descript;
  long := length(c_string);
  {* super line if a '!' is present in clines or tline *}
  While (long>0) Do
    Begin
      If (c_string[long]='!') And (tcompt^.typ In ['c','t'])
        Then super_line := true;
      Dec(long);
    End;
End; {* super_line *}


Function goto_numeral(n : integer; x : line_string) : integer;

{*
	Find location of nth number in x.
	Used by tlineO, clineO, get_real, get_param
	Will also return location of '?'.
*}

Var 
  long,i,j : integer;
  found    : boolean;

Begin
  i := 0;
  found := false;
  goto_numeral := 0;
  j := 1;
  long := length(x);
  If long > 0 Then
    Repeat
      If x[j]='(' Then j := Pos(')',x);
      If x[j] In ['?','+','-','.',',','0'..'9'] Then
        Begin
          Inc(i);
          If i=n Then found := true
          Else
            Repeat  {step over number to find next number}
              Inc(j);
            Until Not(x[j] In ['?','-','.',',','0'..'9']) Or (j=long+1);
        End
      Else
        Inc(j);
    Until found Or (j=long+1);
  If found Then
    goto_numeral := j
  Else
    Begin
      bad_compt := true;
      message[2] := 'Number is missing';
    End;
End; {* goto_numeral *}


Function Get_Real(tcompt : compt; n : integer) : double;
{*
	Read nth number in tcompt.

	Called by get_coordsO, get_s_and_fO, Read_Net
*}

Var 
  c_string,s_value  : line_string;
  j,code,long   : integer;
  value         : double;
  found         : boolean;

Begin
  c_string := tcompt^.descript;
  j := goto_numeral(n,c_string);
  If bad_compt Then
    Begin
      ccompt := tcompt;
      exit;
    End;
  s_value := '';
  long := length(c_string);
  found := false;
  Repeat
    If c_string[j] In [{'+',}'-','.',',','0'..'9'] Then
      Begin
        If c_string[j]=',' Then s_value := s_value+'.'
        Else s_value := s_value+c_string[j];
        Inc(j);
      End
    Else
      found := true;
  Until (found Or (j=long+1));
  Val(s_value,value,code);
  If (code<>0) Or (length(s_value)=0) Then
    Begin
      ccompt := tcompt;
      bad_compt := true;
      message[2] := 'Invalid number';
      exit;
    End;
  get_real := value;
End; {* Get_Real *}


Procedure Get_Param(tcompt : compt; n : integer; Var value : double;
                    Var value_string: line_string; Var u1,prefix: char; Var alt_param: boolean);

{*
	Get nth parameter in tcompt.
	Used for parsing tlines, clines, qlines, BOARD, etc.
	Ignores '+' signs.

	Called by tlineO, clineO, Atten, Transformer,etc.
*}

Const 
  potential_units: set Of char = [degree,Omega,'m','h','H',
                                 's','S','z','Z','y','Y'];

  potential_numbers: set Of char = ['+','-','.',',','0'..'9'];

Var 
  c_string,s_value  : line_string;
  i,j,code,long  : integer;
  found_value   : boolean;

Begin
  alt_param := false;
  c_string := tcompt^.descript;
  j := goto_numeral(n,c_string);
  If bad_compt Then
    Begin
      ccompt := tcompt;
      exit;
    End;
  long := length(c_string);
  While c_string[long]=' ' Do
    Dec(long);  {ignore end spaces}
  If j > 0 Then
    Begin
      found_value := false;
      s_value := '';
      Repeat
        If c_string[j] In potential_numbers Then
          Begin
            If Not(c_string[j]='+') Then
              Begin   {force a skip over '+' signs}
                If c_string[j]=',' Then
                  s_value := s_value+'.'     {sub '.' for ','}
                Else
                  s_value := s_value+c_string[j];
              End; { '+' sign check }
            Inc(j);
          End
        Else If c_string[j]='?' Then
               Begin    {Check here for variable}
                 alt_param := true;
                 Inc(j);
               End
        Else
          found_value := true;
      Until (found_value Or (j=long+1));
      Val(s_value,value,code);
      If (code<>0) Or (length(s_value)=0) Then
        Begin
          If (alt_param=true) Then
            Begin
              value := 1.0;   {return these for uninitialized variables}
              value_string := '1.0';
            End
          Else
            Begin
              ccompt := tcompt;
              bad_compt := true;
              message[2] := 'Invalid number';
              exit;
            End;
        End
      Else
        value_string := s_value;
    End;
  While (c_string[j] = ' ') And (j < long+1) Do
    Inc(j);   {Skip spaces}
  prefix := ' '; {initialize prefix to blank}
  If (c_string[j] In Eng_Dec_Mux) And (j<=long) Then
    Begin
      If c_string[j]='m' Then
        Begin   {is 'm' a unit or prefix?}
          i := j+1;
          While (c_string[i] = ' ') And (i < long+1) Do
            Inc(i);
 {* Skip spaces to check for some unit *}
          If (c_string[i] In potential_units) Then
            Begin
    {it's the prefix milli 'm' next to a unit}
              prefix := 'm';
              value := Eng_Prefix('m')*value;
              j := i; {make j point past the prefix, to the unit}
            End;
        End  {if 'm' is a unit do nothing}
      Else
        Begin  {if other than 'm' factor in prefix}
          prefix := c_string[j];
          value := Eng_Prefix(c_string[j])*value;
          Inc(j);  {advance from prefix toward unit}
        End;
    End;
  While (c_string[j] = ' ') And (j <= long) Do
    Inc(j);   {Skip spaces}
  If j <=long Then u1 := c_string[j]
  Else u1 := '?';
  If u1='m' Then value := 1000*value; {return millimeters, not meters}
End; {* Get_Param *}


Procedure Get_Lumped_Params(tcompt: compt; Var v1,v2,v3,v4: double;
                            Var u,last_ID,last_prefix: char; Var alt_param,parallel_cir : boolean);

{*
	Get paramters for a lumped element.

	example tcompt^.descript := 'a lumped 50-j10+j10'#139' 4mm'
					                 ohms
	Currently, only a single alt_parameter may be
	passed to LumpedO, (either v1,v2,v3, or v4)
	otherwise, an error will occur (in LumpedO).

*}

Label 
  exit_get_lumped;

Var 
  c_string,s_value    : line_string;
  i,j,code,long,sign  : integer;
  value,L_value,
  temp_val,C_value,
  omega0   : double;
  found,par_error   : boolean;
  ident,scale_char : char;

    {***************************************************}
Procedure skip_space;
  {*
			Skip one or more spaces to advance to next
			legitimate data or unit value.
		*}
Begin
  Repeat
    Inc(j);    {advance past spaces}
  Until (c_string[j] <> ' ') Or (j=long+1);
End;
  {****************************************************}


Begin   {* Get_lumped_params *}
  v1 := 0;
  v2 := 0;
  v3 := 0;
  v4 := 0;
  u := '?';
  last_ID := ' ';
  last_prefix := ' ';
  L_value := 0;
  C_value := 0;
  par_error := false;
  parallel_cir := false;
  alt_param := false;
  omega0 := 2*Pi*design_freq*Eng_Prefix(freq_prefix);
  {convert design Freq to rad/sec times prefix}
  c_string := tcompt^.descript;
  j := 2;  {look past id letter}
  If bad_compt Then exit;
  long := length(c_string);
  While c_string[long]=' ' Do
    Dec(long); {ignore end blanks}
  If Pos(Parallel,c_string) > 0 Then parallel_cir := true;
  {* Look for character which represents a parallel circuit *}
  For i:=1 To 4 Do
    Begin
      s_value := '';
      scale_char := ' ';
      found := false;
      If j > long Then goto exit_get_lumped;
      While Not(c_string[j] In ['?','+','-','.',',','0'..'9','j']) Do
        Begin
          Inc(j);         {Advance characters until legitimate data found}
          If j > long Then goto exit_get_lumped;
        End;
      If c_string[j]='+' Then skip_space;
      If c_string[j]='-' Then
        Begin
          skip_space;
          sign := -1;
        End
      Else
        sign := 1;
      If c_string[j]='j' Then
        Begin
          skip_space;
          ident := 'j'
        End
      Else
        ident := ' ';
    { Check for sweep variable }
      If c_string[j]='?' Then
        If alt_param=false Then
          Begin
            alt_param := true;
            skip_space;
          End
      Else
        Begin
          par_error := true;
          goto exit_get_lumped;
        End;
    {* Load string with number characters *}
      Repeat
        If c_string[j] In ['.',',','0'..'9'] Then
          Begin
            If c_string[j]=',' Then s_value := s_value+'.'
            Else s_value := s_value+c_string[j];
            Inc(j);
          End
        Else
          found := true;
      Until (found Or (j=long+1));
      If (c_string[j] = ' ') Then skip_space;
    {* Look for engineering prefixes *}
      If (c_string[j] In Eng_Dec_Mux) And (j<long) Then
        Begin
          scale_char := c_string[j]; {* ignore 'm' if last character *}
          skip_space;
        End;
      If (c_string[j] In ['j','m','H','F']) And (j<>long+1) Then
        Begin
          ident := c_string[j];
          skip_space;
        End;
      If j<=long Then
        If c_string[j] In ['y','Y','z','Z','s','S',Omega] Then
          Begin
            u := c_string[j];
            skip_space;
          End;
      Val(s_value,value,code);
      If (code<>0) Or (length(s_value)=0) Then
        Begin
          If (alt_param=true) And (ident<>'m') Then
            Begin
              value := 1.0;   {return 1.0 for uninitialized variables}
            End
          Else
            Begin
              par_error := true;
              goto exit_get_lumped;
            End;
        End;
      value := value*sign*Eng_Prefix(scale_char);
      Case ident Of 
        'F'   : If C_value=0 Then
                  Begin
                    C_value := value;
                    If C_value=0 Then C_value := 1.0/infty;
    {watch for zero capacitance}
                  End
                Else
                  Begin
                    par_error := true;
                    goto exit_get_lumped;
                  End;
        'H'   : If L_value=0 Then
                  Begin
                    L_value := value;
                    If L_value=0 Then L_value := 1.0/infty;
    {watch for zero inductance}
                  End
                Else
                  Begin
                    par_error := true;
                    goto exit_get_lumped;
                  End;
        'j'   : If value > 0 Then
                  Begin
                    If v2=0 Then v2 := value
                    Else
                      Begin
                        par_error := true;
                        goto exit_get_lumped;
                      End;
                  End
                Else
                  Begin
                    If v3=0 Then v3 := value
                    Else
                      Begin
                        par_error := true;
                        goto exit_get_lumped;
                      End;
                  End;
        'm'   :  v4 := 1000*value; {convert from meters to mm}
         {* return v4=0 if solo m i.e. Manhattan *}
        Else
          If v1=0 Then v1 := value
        Else
          Begin
            par_error := true;
            goto exit_get_lumped;
          End;
      End; {case}
    {Save part ID and prefix for alt_param}
      If Not(ident In [' ','m']) Then last_ID := ident;
      If (scale_char<>' ') And (ident<>'m') Then last_prefix := scale_char;
    End; {for i}
  exit_get_lumped:
                   If Not(par_error) Then
                     Begin
                       If (u In ['z','Z',Omega]) And (parallel_cir=true) Then
                         Begin
                           temp_val := v2;    {* Swap values if parallel circuit is desired *}
                           If v1<>0 Then v1 := 1.0/v1;
                           If v3<>0 Then v2 := -1.0/v3;
                           If temp_val<>0 Then v3 := -1.0/temp_val;
                           If u=Omega Then u := 'S'    {*swap units too *}
                           Else u := 'y';
                         End; {if u in}
    {* Add in capacitor and inductor values *}
                       If C_value <> 0 Then
                         Case u Of 
                           Omega   : v3 := v3 - 1.0/(omega0*C_value);
                           'z','Z' : v3 := v3 - 1.0/(z0*omega0*C_value);
                           'y','Y' : v2 := v2 + z0*omega0*C_value;
                           's','S' : v2 := v2 + omega0*C_value;
                           Else {if 'F' the only unit}
                             If parallel_cir Then
                               Begin
                                 u := 'S';
                                 If v1<>0 Then v1 := 1.0/v1; {assume ohms @ v1 if no units}
                                 v2 := v2 + omega0*C_value;
                               End
                           Else
                             Begin
                               u := Omega;
                               v3 := v3 - 1.0/(omega0*C_value);
                             End;
                         End; {if..case}
                       If L_value <> 0 Then
                         Case u Of 
                           Omega   : v2 := v2 + omega0*L_value;
                           'z','Z' : v2 := v2 + omega0*L_value/z0;
                           'y','Y' : v3 := v3 - z0/(omega0*L_value);
                           's','S' : v3 := v3 - 1.0/(omega0*L_value);
                           Else  {if 'H' the only unit}
                             If parallel_cir Then
                               Begin
                                 u := 'S';
                                 If v1<>0 Then v1 := 1.0/v1; {assume ohms @ v1 if no units}
                                 v3 := v3 - 1.0/(omega0*L_value);
                               End
                           Else
                             Begin
                               u := Omega;
                               v2 := v2 + omega0*L_value;
                             End; {else}
                         End; {if..case}
                     End; {not par_error}
  If par_error Or (u='?') Then
    Begin
      ccompt := tcompt;
      bad_compt := true;
      message[1] := 'Error in';
      message[2] := 'lumped element';
      message[3] := 'description';
    End;
End; {* Get_Lumped_Params *}



{************************** Numerical Routines *************************}

Function arctanh(Const x:double) : double;

Begin
  arctanh := 0.5*ln((1+x)/(1-x));
End;


Function kkk(Const x:double) : double;

{*
	Function used to calculate Cohn's "k" factor for stripline
	width formulas.  See equation 3.6, page 13 of the Puff Manual.
	Used by widthO, w_s_stripline_cline.
*}

Var 
  expx : double;

Begin
  If x > 1 Then
    Begin
      expx := exp(pi*x);
      kkk := sqrt(1-sqr(sqr((expx-2)/(expx+2))));
    End
  Else
    Begin
      expx := exp(pi/x);
      kkk := sqr((expx-2)/(expx+2))
    End;
End; {kkk}


Function widtht(Const zed:double) : double; {width in mils}

{*
	Function for calculating width in mils of microstrip
	and stripline transmission lines.  See Puff manual
	pages 12-13 for details.

	Microstrip models are from Owens:
		Radio and Elect Eng, 46, pp 360-364, 1976.
	Stripline models are from  Cohn:
		MTT-3 pp19-126, March 1955.
	See also Gupta, Garg, Chadha:
		CAD of Microwave Circuits Artech House, 1981.
*}

Const 
  lnpi_2 = 0.451583;
  ln4_pi = 0.241564;

Var 
  Hp,expH,de,x : double;

   {******************************************}
Procedure High_Z_Error;
Begin
  bad_compt := true;
  message[1] := 'Impedance';
  message[2] := 'too large';
  widtht := 0;
End;
 {******************************************}

Begin
  If stripline Then
    Begin
      x := zed*sqrt(er)/(30*pi);
      If (pi*x > 87.0) Then
        High_Z_Error  {or else kkk(x) will explode}
      Else
        widtht := substrate_h*2*arctanh(kkk(x))/pi; {Use kkk for k factor}
    End
  Else
    Begin { if microstripline then }
      If zed > (44-2*er) Then
        Begin
          Hp := (zed/120)*sqrt(2*(er+1)) + (er-1)*(lnpi_2+ln4_pi/er)/(2*(er+1));
          If Hp > 87.0 Then
            Begin  {e^87 = 6.0e37}
              High_Z_Error;
            End
          Else
            Begin
              expH := exp(Hp);
              widtht := substrate_h/(expH/8-1/(4*expH));
            End;
        End
      Else
        Begin  { if zed <= (44-2*er) }
          de := 60*sqr(pi)/(zed*sqrt(er));
          widtht := substrate_h*(2/pi*((de-1)-ln(2*de-1))+
                    (er-1)*(ln(de-1)+0.293-0.517/er)/(pi*er));
        End; { if zed }
    End; {if stripline}
End; {widtht}


Function sinh(Const x : double) : double;

{*
	Hyperbolic sine used for s-parameter
	calculations in tlines and clines.

	Reals will explode with x > 300.
*}

Var a: double;

Begin
  a := exp(x);
  sinh := (a-1/a)/2;
End; {* sinh *}


Function cosh(Const x : double) : double;

{*
	Hyperbolic cosine used for tline and cline
	s-parameter calculation.

	Reals will explode with x > 300
*}
Begin
  cosh := (exp(x)+1/exp(x))/2;
End; {* cosh *}


Function cl_cosh(Const x : double) : double;
{*
	Hyperbolic cosine used for cline calculation.
*}

Var 
  exp1 : double;

Begin
  If x > 300 Then
    Begin
      exp1 := infty;
      bad_compt := true;
      message[1] := 'cline impedances';
      message[2] := 'can'+char(39)+'t be realized';
      message[3] := 'in microstrip';
    End
  Else
    Begin
      exp1 := exp(x);
      cl_cosh := (exp1+1/exp1)/2;
    End;
End; {* cl_cosh *}


Function arccosh(Const x : double) : double;
{*
	Inverse cosh.
	Used for Procedures error() and w_s_microstip_cline.
*}

Var 
  sqx : double;

Begin
  sqx := sqr(x);
  If sqx <= 1 Then
    Begin
      arccosh := 0;
      bad_compt := true;
      message[1] := 'cline impedances';
      message[2] := 'can'+char(39)+'t be realized';
      message[3] := 'in microstrip';
    End
  Else
    arccosh := ln(x+sqrt(sqr(x)-1));
End; {arccosh}


Procedure error(Const g,wo,ceven : double; Var fg,dfg : double);

{*
	This routine is used to calculate cline dimensions.
	When error=0 a consistent solution of the cline equations
	has been reached. See Edwards p139.
*}

Var 
  hh,sqm1,rsqm1,dcdg,
  acoshh,acoshg,u1,u2,
  du1dg,du2dg,dhdg,
  dcdu1,dcdu2,dcdh   : double;

Begin
  hh := 0.5*((g+1)*ceven+g-1);
  dhdg := 0.5*(ceven+1.0);
  acoshh := arccosh(hh);
  If bad_compt Then exit;
  acoshg := arccosh(g);
  If bad_compt Then exit;

  sqm1 := sqr(hh)-1;
  rsqm1 := sqrt(sqm1);
  dcdh := (rsqm1+hh)/(hh*rsqm1+sqm1);

  sqm1 := sqr(g)-1;
  rsqm1 := sqrt(sqm1);
  dcdg := (rsqm1+g)/(g*rsqm1+sqm1);

  u1 := ((g+1)*ceven-2)/(g-1);
  du1dg := ((g-1)*ceven-((g+1)*ceven-2))/sqr(g-1);
  u2 := acoshh/acoshg;
  du2dg := (acoshg*dcdh*dhdg-acoshh*dcdg)/sqr(acoshg);

  sqm1 := sqr(u1)-1;
  rsqm1 := sqrt(sqm1);
  dcdu1 := (rsqm1+u1)/(u1*rsqm1+sqm1);

  sqm1 := sqr(u2)-1;
  rsqm1 := sqrt(sqm1);
  dcdu2 := (rsqm1+u2)/(u2*rsqm1+sqm1);

  If (er > 6) Then
    Begin
      fg := (2*arccosh(u1)+arccosh(u2))/pi-wo;
      If bad_compt Then exit;
      dfg := (2*dcdu1*du1dg+dcdu2*du2dg)/pi;
    End
  Else
    Begin
      fg := (2*arccosh(u1)+4*arccosh(u2)/(1.0+er/2.0))/pi-wo;
      If bad_compt Then exit;
      dfg := (2*dcdu1*du1dg+4*dcdu2*du2dg/(1.0+er/2.0))/pi;
    End;
End; {error}


Procedure w_s_stripline_cline(Const zede,zedo : double; Var woh,soh : double);
{*
	Computes ratios W/b and S/b for stripline clines.
	See Puff Manual page 14 for details.

*}

Var 
  ke,ko : double;

Begin
  ke := kkk(zede*sqrt(er)/(30*pi));
  ko := kkk(zedo*sqrt(er)/(30*pi));
  woh := 2*arctanh(sqrt(ke*ko))/pi;
  soh := 2*arctanh(sqrt(ke/ko)*(1-ko)/(1-ke))/pi;
End; {w_s_stripline_cline}


Procedure w_s_microstrip_cline(Const we,wo : double; Var woh,soh : double);

{*
	This routine uses Netwon's method to find the cline width
	and spacing. Errors occur in the repeat (newton	algorithm)
	loop if the even and odd impedances are too close.
*}

Const 
  tol = 0.0001;

Var 
  codd,ceven,g,fg,dfg,dg,g1 : double;
  i : integer;

Begin
  ceven := cl_cosh(pi*we/2);
  codd := cl_cosh(pi*wo/2);
  soh := 2*arccosh((ceven+codd-2)/(codd-ceven))/pi;
  If bad_compt Then exit;
  g := cl_cosh(pi*soh/2); {starting guess}
  i := 0;
  Repeat {newton algorithm}  {!* beware of divergence in this loop *}
    g1 := g;
    error(g,wo,ceven,fg,dfg);
    If bad_compt Then exit;
    dg := fg/dfg;
    g := g1-dg;
    Inc(i);
    If g<= 1.0 Then i := 101;
  Until ((abs(dg)<abs(tol*g)) Or (i > 100));
  If i> 100 Then
    Begin
      bad_compt := true;
      message[1] := 'cline impedances';
      message[2] := 'can'+char(39)+'t be realized';
      message[3] := 'in microstrip';
      exit;
    End;
  soh := 2.0*arccosh(g)/pi;
  woh := arccosh(0.5*((g+1)*ceven+g-1))/pi-soh/2.0;
End; {w_s_microstrip_cline}


Procedure shutdown;
{*
	Called when a disastrous error condition
	has been reached to stop Puff.
*}
Begin
  CloseGraph;
  TextMode(OrigMode);
  message[1] := 'FATAL ERROR:';
  write_message;
  Gotoxy(1,23);
  write('Press any key to quit');
  ReadKey;
  Halt(3);
End;


Function Fileexists(note:boolean;Var inf:textfile;fname:file_string): boolean;

{*
	Performs an Assign and Reset on textfile if the file exists.
	Note that Textfile is used here. Consider changing the
	buffer size using SetTextBuffer.

*}
Begin
  fileexists := False;
  If fname <> '' Then
    Begin
      Assign(inf,fname);
    {$I-}
      Reset(inf); {$I+}  {* Disable I/O check in case file not present *}
      If IOResult=0 Then fileexists := true    {* IOResult of 0 means success *}
      Else
        Begin
          If note Then
            Begin
              message[2] := 'File not found';
              message[3] := fname;
              write_message;
              Delay(1000);
            End;
        End; {if IO}
    End; {if fname}
End; {* Fileexists *}


Function setupexists(Var fname : file_string) : boolean;
{*
	Look for setup.puf in current directory of in \PUFF.
*}

Var 
  found : boolean;

Begin
  found := false;
  message[2] := fname;
  If fname <> 'setup.puf' Then
    Begin
      fname := 'setup.puf';
      found := fileexists(false,net_file,fname);
    End;
  If Not(found) Then
    Begin
      fname := '\PUFF\setup.puf';
      found := fileexists(false,net_file,fname);
    End;
  If found Then
    Begin
      erase_message;
      message[1] := 'Missing board#';
      message[2] := 'Try';
      message[3] := fname;
      write_error(2);
    End;
  setupexists := found;
End; {setupexists}


Function atan2(Const x,y : double) : double;
{*
	Modified arctan to get phase in all quadrants
	and avoid blow ups when x=0.
*}

Var 
  atan2t : double;

Begin
  If x=0 Then
    Begin
      If y > 0 Then atan2t := 90.0
      Else atan2t := -90.0;
    End
  Else
    Begin
      If x > 0 Then atan2t := 180*arctan(y/x)/pi
      Else
        Begin
          If y > 0 Then atan2t := 180*arctan(y/x)/pi+180
          Else atan2t := 180*arctan(y/x)/pi-180;
        End;
    End;
  If abs(atan2t) < 1.0e-25 Then atan2 := 0
  Else atan2 := atan2t;
End; {atan2}


Function enough_space(defaultdrive : integer) : boolean;
{*
	Look for space on disk -- a: 0, b: 1 ..
*}

Begin


{* 
   On Linux, don't actually test whether there is enough disk space; 
   that doesn't help much on a multitasking system anyway 
*}

  enough_space := true;
End; {* Enough_space *}


Function node_number : integer;
{*
	Find number of node in linked list of nets.
*}

Var 
  nn   : integer;
  tnet : net;

Begin
  tnet := Nil;
  nn := 0;
  If net_start <> Nil Then
    Repeat
      If tnet=Nil Then tnet := net_start
      Else tnet := tnet^.next_net;
      If tnet^.node Then Inc(nn);
    Until (tnet^.next_net=Nil) Or (cnet=tnet);
  If cnet=tnet Then node_number := nn
  Else node_number := 0;
End; {node_number}


Procedure update_key_list(nn : integer);
{*
	Update array which contains keystrokes used to layout circuit.
*}
Begin
  If key_end=0 Then key_end := 1
  Else Inc(key_end);
  If key_end=key_max Then
    Begin
      key_end := key_max-1;
      message[1] := 'Circuit is too';
      message[2] := 'complex for';
      message[3] := 'redraw';
      write_message;
    End;
  key_list[key_end].keyl := key;
  key_list[key_end].noden := nn;
End; {update_key_list}


Procedure Carriage_Return;

{*
     Carriage return operation used only in the
     Parts Window.	
     Advances to next part, puts cursor on first character.
*}
Begin
  If ( (ccompt^.next_compt=Nil)
     Or
     ( Not(Large_Parts) And
     (window_number=3) And (ccompt^.descript[1]='i') )
     Or
     (Large_Parts And (window_number=3) And
     (ccompt^.descript[1]='j') And help_displayed )
     )
    Then
    Begin
      Case window_number Of 
        3 : ccompt := part_start;
        4 : ccompt := board_start;
        Else
          beep;
      End; {case}
    End
  Else
    ccompt := ccompt^.next_compt;
  cx := ccompt^.x_block;
End;


Procedure Move_Cursor(x1,y1 : integer);
{*
	Move character cursor. Used for Board, Parts, and Plot windows.
*}

Var 
  long,i  : integer;
  has_spaces : boolean;

Begin
  has_spaces := false;
  If x1 <> 0 Then With ccompt^ Do
                    Begin
                      long := length(descript);
                      If cx+x1 <= long Then
                        Begin
                          cx := cx+x1;
                          If cx < x_block Then cx := x_block;
                          If right And (cx+xp >= xorig) Then
                            Begin
                              If (window_number=2) Then Inc(WindMax);
 {Increment WindMax to prevent scrolling in plot window}
                              Dec(xp);
                              write_compt(lightgray,ccompt);
                              Write(' ');
                              If (window_number=2) Then Dec(WindMax);
 {Restore WindMax}
                            End;
                        End;
                    End
                    Else
                      Begin { if x1=0 then... }
                        Erase_message;
                        If Pos(' ',ccompt^.descript) <> 0 Then has_spaces := true;
                        If (window_number=2)
                           And ( (length(ccompt^.descript)<3) Or (has_spaces) ) Then
                          For i:=1 To max_params Do   {Delete invalid S-parameter designations}
                            If s_param_table[i]=ccompt Then
                              Begin
                                Delete(ccompt^.descript,2,2);
                                GotoXY(ccompt^.xp-2,ccompt^.yp);
                                Write('     ');   {erase invalid s-parameter on screen}
                              End;
                        If y1 <> 0 Then
                          Begin   {if y1=0 then skip the following}
                            If y1=-1 Then
                              Begin
                                If ccompt^.prev_compt = Nil Then beep
                                Else ccompt := ccompt^.prev_compt;
                              End
                            Else
                              Begin  {y1=1}
                                If ( (ccompt^.next_compt=Nil)
                                   Or
                                   (Not(Large_Parts) And (window_number=3) And (ord(ccompt^.descript
                                   [1])-ord('a') >= ymax[3]-ymin[3]) )
                                   Or
                                   (Large_Parts And (window_number=3) And (ord(ccompt^.descript[1])-
                                   ord('a') >= ymax[3]-ymin[3]) And help_displayed )
                                   )
                                  Then beep
                                Else ccompt := ccompt^.next_compt;
                              End; {y1=-1}
                            If (window_number=2) And (length(ccompt^.descript)=1) Then
                              For i:=1 To max_params Do
                                If s_param_table[i]=ccompt Then
                                  Begin
                                    pattern(xmin[2]*charx-1,(ymin[2]+2+i)*chary-8,i,0);
                                    write_comptm(1,lightgray,ccompt); {write "S"}
                                  End;
                            long := length(ccompt^.descript);
                            If cx > long Then cx := long;
                            If window_number=2 Then cx := ccompt^.x_block;
                            If cx < ccompt^.x_block Then cx := ccompt^.x_block;
                          End; { if y1 <> 0}
                      End; {else}
End; {move_cursor}


Function tanh(Const x : double) : double;
{*
	Calculate the hyperbolic tangent.
*}

Var 
  ex : double;

Begin
  If (x < -30) Then
    Begin
      tanh := -1.0;
      exit;
    End;
  If (x > 30) Then
    tanh := 1.0
  Else
    Begin
      ex := exp(x);
      tanh := (ex-1/ex)/(ex+1/ex);
    End;
End;


Function KoK(Const k : double) : double;
{*
*}

Var 
  kp : double;

Begin
  kp := sqrt(1-sqr(k));
  If sqr(k) < 0.5 Then
    kok := ln(2*(1+sqrt(kp))/(1-sqrt(kp)))/pi
  Else
    kok := pi/ln(2*(1+sqrt(k))/(1-sqrt(k)));
End;


Procedure capac(Const W_h,S_h,er : double; Var ce,co : double);
{*
	Calculate capacitances of coupled microstrip.
*}

Var 
  cp,cf,cfp,cga,cgd,ere,zo,a : double;

Begin
  ere := (er+1)/2 + (er-1)/2/sqrt(1+10/W_h);
  If W_h <= 1.0 Then
    zo := 370.0*ln(8.0/W_h+0.25*W_h)/(2.0*pi*sqrt(ere))
  Else
    zo := 370.0/((W_h+1.393+0.667*ln(W_h+1.44))*sqrt(ere));
  a := exp(-0.1*exp(2.33-2.53*W_h));
  cp := er*W_h;
  cf := 0.5*(sqrt(ere)/(zo/(120*pi))-cp);
  cfp := cf*sqrt(er/ere)/(1+a*tanh(8*S_h)/S_h);
  cga := KoK(S_h/(S_h+2*W_h));
  cgd := er*ln(1/tanh(pi*S_h/4))/pi+0.65*cf*(0.02*sqrt(er)/S_h+1-1/sqr(er));
  ce := cp+cf+cfp;
  co := cp+cf+cga+cgd;
End; {capac}


Procedure ere_even_odd(Const W_h,S_h:double;Var ee,eo:double);
{*
	Compute effective relative dielectric constants for cline
	even and odd impedances.
*}

Var 
  ce1,co1,cee,coe: double;

Begin
  capac(W_h,S_h,1,ce1,co1);
  capac(W_h,S_h,er,cee,coe);
  ee := cee/ce1;
  eo := coe/co1;
End; {ere_even_odd}


Procedure LU_Decomp(Var a: s_conv_matrix;
                    n: integer;
                    Var indx: s_conv_index;
                    Var d: double);

{*
	L-U Decomposition routine inspired by Numerical Recipes.
   	The following types are used here:

	s_conv_matrix = array [1..conv_size,1..conv_size] of TComplex;
	s_conv_vector = array [1..conv_size] of TComplex;
	s_conv_index  = array [1..conv_size] of integer;
	s_real_vector = array [1..conv_size] of double;


*}

Const 
  tiny = 1.0e-20;

Type 
  s_real_vector = array [1..conv_size] Of double;

Var 
  k,j,imax,i  : integer;
  sum,dum_z,
  z_dum       : TComplex;
  big,dum_r   : double;
  vv          : s_real_vector;

Begin
{   new(vv); }
  d := 1.0;
   {* Loop over rows to get implicit scaling information *}
  For i := 1 To n Do
    Begin
      big := 0.0;
      For j := 1 To n Do
        If (co_mag(a[i,j]) > big) Then big := co_mag(a[i,j]);
      If big = 0.0 Then
        Begin      {if zeros all along the column...}
          Message[1] := 'Warning!';
          Message[2] := 'indef part has';
          Message[3] := 'singular matrix';
          Write_Message;
          big := tiny;  {! This will not cause recovery *}
        End;
      vv[i] := 1.0/big;  {save the scaling for future reference}
    End;
  For j := 1 To n Do
    Begin
      For i := 1 To j-1 Do
        Begin
          Equate_Zs(sum,a[i,j]);
          For k := 1 To i-1 Do
            Diffpr(sum,a[i,k],a[k,j]); {* sum=sum-a[i,k]*a[k,j] *}
          Equate_Zs(a[i,j],sum);
        End;
      big := 0.0;
      For i := j To n Do
        Begin
          Equate_Zs(sum,a[i,j]);
          For k := 1 To j-1 Do
            Diffpr(sum,a[i,k],a[k,j]);  {* sum=sum-a[i,k]*a[k,j] *}
          Equate_Zs(a[i,j],sum);
  {* Check here for a better figure of merit for the pivot *}
          dum_r := vv[i]*co_mag(sum);
          If dum_r >= big Then
            Begin  {*if better, exchange and save index*}
              big := dum_r;
              imax := i
            End;
        End;
      If j <> imax Then
        Begin  {* Interchange rows if needed *}
          For k := 1 To n Do
            Begin
              Equate_Zs(dum_z,a[imax,k]);
              Equate_Zs(a[imax,k],a[j,k]);
              Equate_Zs(a[j,k],dum_z);
            End;
          d := -d;
          vv[imax] := vv[j];  {* Interchange the scale factor *}
        End;
      indx[j] := imax;
      If co_mag(a[j,j]) = 0.0 Then a[j,j].r := tiny;
      If j <> n Then
        Begin
          Rc (z_dum, a[j,j]);  {complex reciprocal-creates pointer z_dum}
          For i := j+1 To n Do
            Begin
              prp (dum_z, a[i,j], z_dum); {! is this legal?}
              Equate_Zs (a[i,j], dum_z); {*a[i,j] := a[i,j]*z_dum *}
            End;
        End;
    End;
End;  {* LU_Decomp *}


Procedure LU_Sub(Var a : s_conv_matrix;
                 n : integer;
                 Var indx : s_conv_index;
                 Var b : s_conv_vector);

{*
	Routine for L-U forward and backward substitution,
	needed to solve for linear systems and do matrix inversions.

	The following types are used here:

	s_conv_matrix = array [1..conv_size,1..conv_size] of complex;
	s_conv_vector = array [1..conv_size] of complex;
	s_conv_index  = array [1..conv_size] of integer;
*}

Var 
  j,ip,ii,i   : integer;
  sum,dum_z   : TComplex;

Begin
  ii := 0;
  For i := 1 To n Do
    Begin
      ip := indx[i];
      Equate_Zs(sum,b[ip]);  { sum := b[ip]  }
      Equate_Zs(b[ip],b[i]); { b[ip] := b[i] }
      If ii <> 0 Then
        For j := ii To i-1 Do
          Diffpr(sum,a[i,j],b[j])  { sum := sum-a[i,j]*b[j] }
          Else If (co_mag(sum) <> 0.0) Then
                 ii := i;
      Equate_Zs(b[i],sum);
    End;
  For i := n Downto 1 Do
    Begin
      Equate_Zs(sum,b[i]);
      For j := i+1 To n Do
        Diffpr(sum,a[i,j],b[j]);   { sum := sum-a[i,j]*b[j] }
      Rc (dum_z, a[i,i]);  { complex reciprocal - new pointer }
      Prp(b[i],sum,dum_z);  {! is this legal?}
    End;
End; {* Lub_Sub *}


Procedure Matrix_Inversion(Var a : s_conv_matrix; n : integer);

{*
  	Uses the LU decomposition and substitution
	routines to invert the matrix "a" of size n x n.

	The original matrix "a" is destroyed and replaced
	with its inverse.

	Inversion is performed column by column.
*}

Var 
  i,j       : integer;
  d         : double;
  co_0,co_1 : TComplex;
  indx      : s_conv_index;
  col       : s_conv_vector;
  y      : s_conv_matrix;

Begin
  Co(co_0,0.0,0.0); {complex zero}
  Co(co_1,1.0,0.0); {complex one}
  LU_Decomp(a,n,indx,d);    {* LU decomposition of matrix a *}
  For j:= 1 To n Do
    Begin
      For i := 1 To n Do
        Equate_Zs(col[i],co_0); {fill column with zeros}
      Equate_Zs(col[j],co_1);  {Put 1+j0 in the proper position}
      LU_Sub(a,n,indx,col);
      For i:= 1 To n Do
        Equate_Zs(y[i,j],col[i]);
    End;
  {* Fill Matrix "a" with data in "y" *}
  For j:= 1 To n Do
    For i:=1 To n Do
      Equate_Zs(a[i,j],y[i,j]);
End; {* Matrix_Inversion *}


Procedure Matrix_Mux(Var a,b,c : s_conv_matrix;
                     n : integer);

{*
	Performs the matrix multiplication:
		a = b * c
	  where a,b,c are matrices of complex numbers
	  each of dimension n x n.
	Matrices b and c are unaffected.
	It is assumed that all matrices are initialized.
*}

Var 
  i,k,j       : integer;
  sum,co_0    : TComplex;

Begin
  co(co_0,0.0,0.0);
  For j:=1 To n Do
    Begin
      For i:=1 To n Do
        Begin
          Equate_Zs(sum,co_0);  {initialize sum to zero}
          For k:=1 To n Do
            Supr(sum,b[i,k],c[k,j]);
       {* sum:= sum + b[i,k]*c[k,j] *}
          Equate_Zs(a[i,j],sum); {fill matrix "a"}
        End;
    End;
End;  {* Matrix_Mux *}


Procedure Matrix_Conv(Var a: s_conv_matrix; n : integer);

{*
	Performs the calculation:

	   A := (I - A)(I + A)^(-1)

	Used to convert between S and Y matrices

	Defined are B = (I - A) and C = (I + A)

	When converting from a two port to a three port
	the s-parameters are switched such that  2 <-> 3
	for each of the port numbers.  This causes the
	(indefinite) ground to be created at port 2,
	and is easier to use in the layout window.
*}

Var 
  i,j       : integer;
  b,c       : s_conv_matrix;
  co_0,co_1 : TComplex;

Begin
  co(co_0,0.0,0.0);
  co(co_1,1.0,0.0);
  {initialize pointers for c[i,j] b[i,j] and make copy of a[i,j]}
  For j:=1 To n Do
    For i:=1 To n Do
      Begin
        If i=j Then
          Begin
            di(b[i,j],co_1,a[i,j]); {di is complex difference}
            su(c[i,j],co_1,a[i,j]); {su is complex sum}
          End
        Else
          Begin
            di(b[i,j],co_0,a[i,j]); {di is complex difference}
            Equate_Zs(c[i,j],a[i,j]); {su is complex sum}
          End;
      End;
  {* Now B = (I - A) and C = (I + A)  *}
  Matrix_Inversion(c,n);
  {* Now B = (I - A) and C = (I + A)^(-1)  *}
  Matrix_Mux(a,b,c,n);
  {* Now A = (I - A)(I + A)^(-1)  *}
End;  {* Matrix_Conv *}


Procedure Indef_Matrix(Var S : s_conv_matrix; n : integer);

{*
	Procedure for converting n port S matrix
	to n+1 port S matrix.
	Warning! The "S" pointers must be initialized to n+1 size!


	Steps:  1. S(n port) -> Y(n port)
		2. Y(n port) -> Y(n+1 port)
		3. Y(n+1 port) -> S(n+1 port)
*}

Var 
  i,j         : integer;
  co_0,sum    : TComplex;

 {******************************************}
Procedure Sign_Change(Var z : TComplex);
 {*
		Change sign of complex number
	*}
Begin
  z.r := -z.r;
  z.i := -z.i;
End;
 {******************************************}
Procedure Sum_Up(Var z1,z2: TComplex);
 {*
		z1 = z1 +z2
	*}
Begin
  z1.r := z1.r+z2.r;
  z1.i := z1.i+z2.i;
End;
 {*******************************************}
Procedure Swap_2_and_3(Var T : s_conv_matrix);
 {*
		Swap s-parameters between ports 2 and 3.
		To be called only for the 2 port device.
	*}

Var 
  temp_z  : TComplex;
Begin
   {* S12 <-> S13 *}
  Equate_Zs(temp_z,T[1,3]);
  Equate_Zs(T[1,3],T[1,2]);
  Equate_Zs(T[1,2],temp_z);
   {* S21 <-> S31 *}
  Equate_Zs(temp_z,T[3,1]);
  Equate_Zs(T[3,1],T[2,1]);
  Equate_Zs(T[2,1],temp_z);
   {* S23 <-> S32 *}
  Equate_Zs(temp_z,T[2,3]);
  Equate_Zs(T[2,3],T[3,2]);
  Equate_Zs(T[3,2],temp_z);
   {* S22 <-> S33 *}
  Equate_Zs(temp_z,T[3,3]);
  Equate_Zs(T[3,3],T[2,2]);
  Equate_Zs(T[2,2],temp_z);
End;
 {********************************************}

Begin
  Matrix_Conv(S,n);  {Changes S to a normalized admittance matrix}
  {* Y n-port to Y n+1 port routine: *}
  Co(co_0,0.0,0.0);
  For j:=1 To n Do
    Begin
      Equate_Zs(sum,co_0); {initialize sum to complex zero}
      For i:=1 To n Do
        Begin
          Sum_Up(sum,S[i,j]);
        End;
      Sign_Change(sum);
      Equate_Zs(S[n+1,j],sum); {new value for Y[n+1,j] }
    End;
  For i:=1 To n Do
    Begin
      Equate_Zs(sum,co_0); {initialize sum to complex zero}
      For j:=1 To n Do
        Begin
          Sum_Up(sum,S[i,j]);
        End;
      Sign_Change(sum);
      Equate_Zs(S[i,n+1],sum); { new value for Y[i,n+1] }
    End;
  Equate_Zs(sum,co_0); {initialize sum to complex zero}
  For i:=1 To n Do
    For j:=1 To n Do
      Sum_Up(sum,S[i,j]);
  Equate_Zs(S[n+1,n+1],sum); { new value for Y[n+1,n+1] }
  Matrix_Conv(S,n+1);  {Change from Y to indef S matrix}
  If (n=2) Then Swap_2_and_3(S);
  {* Exchange ports 2 and 3 for the 3 port indef *}
End; {* Indef_Matrix *}



Function HeapFunc(Size: word) : integer;

{*
	A call is made to this function whenever a call to
	New or GetMem cannot be completed i.e. when no room
	remains on the heap. The net result of setting
	HeapFunc:=1 is that New and GetMem will then return
	a nil pointer and the program will not be aborted
	with a 203 error.

	In TP 6.0 a quick exit is required for Size=0
*}
Begin
  If (Size > 0) Then
    Begin
      If message[3] <> ' Exhausted ' Then
        Begin
          erase_message;
          message[1] := '  DANGER!  ';
          message[2] := '  Memory   ';
          message[3] := ' Exhausted ';
          If window_number=2 {plot window} Then
            Begin
              write_message;
              delay(1500);
            End
          Else
            shutdown;
        End;
      HeapFunc := 1;
    End; {if Size }
End; {* HeapFunc *}





{************* METHODS FOR THE SWEEP OBJECT ******************}

Procedure Sweep.Init_Use;
{*
	Reset sweep object.
*}
Begin
  element := Nil;
  used := false;
  Alt_Sweep := false;  {this is a global variable}
  unit_label := '';
  index := 0;
End;  {* Init_Use *}


Procedure Sweep.Init_Element(tcompt: compt; in_id,in_prefix,in_unit : char);

{*
	Initialize the sweep object element if it hasn't been
	previously initialized. Called by lumped,clines,tline,etc.

*}

Const 
  potential_units: set Of char = [degree,Omega,'m','h',
                                 's','S','z','Z','y','Y','Q'];

Begin
  If Not(used) Then
    Begin
      used := true;
      element := tcompt;  {element points to compt}
      id := in_id;
      prefix := in_prefix;
      omega0 := 2*Pi*design_freq*Eng_Prefix(freq_prefix);
     {convert design Freq to rad/sec times prefix}
      units := in_unit;
      alt_sweep := true;  {this is a global flag}
      tcompt^.sweep_compt := true;  {tell tcompt that its the sweep}
      part_label := 'Part '+ tcompt^.descript[1];
      If prefix In Eng_Dec_Mux Then unit_label := prefix
      Else unit_label := '';
      If (id='j') Then unit_label := 'j'+ unit_label;
      If (id In ['F','H']) Then
        unit_label := unit_label+id
      Else If (id='a') Then
             unit_label := unit_label+'dB'
      Else If (id='t') Then     {transformer is n:1}
             unit_label := unit_label+'n:1'
      Else If (units In potential_units) Then
             unit_label := unit_label+units;
    End
  Else
    Begin
      element^.changed := True; {Force re-parsing of last ?}
      Init_Use;   {clear current alt_param}
      tcompt^.sweep_compt := false;
      bad_compt := true;
      message[1] := 'Parts list has';
      message[2] := 'multiple sweep';
      message[3] := 'parameters';
    End;
End; {* Init_Element *}


Procedure Sweep.Check_Reset(tcompt : compt);
{*
	See if a previous sweep_compt part has been changed.
	Called by Pars_Compt_List;
*}
Begin
  If (element=tcompt) And tcompt^.changed Then
    Begin
      Init_Use;
      tcompt^.sweep_compt := false;
    End;
End; {* Check_Reset *}


Procedure Sweep.Label_Axis;
{*
	Label x axis of x-y plot and Smith plot.
*}

Var 
  label_string : line_string;
  label_lngth : integer;

Begin
  label_string := part_label+' : '+unit_label;
  label_lngth := Length(label_string);
  GotoXY(x_y_plot_text[5,1]+2-label_lngth Div 2,x_y_plot_text[5,2]);
  Write(label_string);
End; {* Label_Axis *}


Procedure Sweep.Label_Plot_Box;
{*
	Label data in plot window from frequency to alt_param.
*}

Var 
  i : integer;
Begin
  GotoXY(xmin[2],ymin[2]+2);
  Write(part_label); {write part label over 'f'}
  GotoXY(xmin[2]+17,ymin[2]+2);
  Write(unit_label);
  If (Length(unit_label)<=2) Then
    For i:=0 To (2-Length(unit_label)) Do
      Write(' ');
End; {* Label_Plot_Box *}


Procedure Sweep.Load_Prop_Const(Const prop_consta,prop_constb : double);
{*
   Load in proportionality constants to be used in sweep calculations.
*}
Begin
  prop_const1 := prop_consta;
  prop_const2 := prop_constb;
End;


Procedure Sweep.Load_Index(i : integer);

{*
   Read index for lumped element and clines sweep_compt.
      LUMPED
   	i=1 : resistance
	i=2 : + reactance or susceptance
	i=3 : - reactance or susceptance 
      CLINES
   	i=1 : even mode impedance only
	i=2 : odd mode impedance only
	i=3 : even and odd mode impedances given, even is the variable
	i=4 : even and odd mode impedances given, odd is the variable
*}
Begin
  index := i;
  If (id='j') And (index=3) Then unit_label := '-'+unit_label;
  {identify negative X's and B's}
End; {* Load_Index *}


Procedure Sweep.Load_Data(Const sweep_data : double);

{*
	Read data during alternate parameter sweep.

	Parse data and place in appropriate element
	location.
*}
Begin
  new_value := sweep_data*Eng_Prefix(prefix);
  If (new_value=0.0) Then new_value := 1.0/infty;  {make 1e-35}
  Case element^.typ Of 
    'x','a'  : element^.zed := new_value;
    'q','t'  :
               Begin
                 Case units Of 
                   omega   :  element^.zed := new_value;
                   's','S' :  element^.zed := 1.0/new_value;
                   'z','Z' :  element^.zed := z0*new_value;
                   'y','Y' :  element^.zed := z0/new_value;
                   degree  :  element^.wavelength := new_value/360.0;
                   'm'   :  element^.wavelength := 1000.0*new_value*prop_const1;
       {must put in mm}
                   'h','H' : element^.wavelength := new_value*prop_const1;
                   'Q' :
                         Begin
                           element^.alpha_c := (Pi*element^.wavelength)/
                                               (new_value*element^.lngth0);
                           element^.alpha_d := 0.0;
                         End;
                 End;
               End;
    'c'  :
           Begin  {Coupled lines}
             Case units Of  {fix impedances later using index}
     {omega  :  new_value:=new_value;}
               's','S' :  new_value := 1.0/new_value;
               'z','Z' :  new_value := z0*new_value;
               'y','Y' :  new_value := z0/new_value;
               degree  :
                         Begin
                           element^.wavelength := new_value*prop_const1/360.0;
                           element^.wavelengtho := new_value*prop_const2/360.0;
                         End;
               'm'   :
                       Begin
                         element^.wavelength := 1000.0*new_value*prop_const1;
                         element^.wavelengtho := 1000.0*new_value*prop_const2;
                       End;
        {Use factor of 1000 to put in mm}
               'h','H' :
                         Begin
                           element^.wavelength := new_value*prop_const1; {even}
                           element^.wavelengtho := new_value*prop_const2; {odd}
                         End;
        {for 'h' substrate_h has been factored in prop_const1}
             End; {case units}
             Case index Of {if an impedance, fix it up}
               1 :
                   Begin
                     element^.zed := new_value;
                     If (new_value>1.0e-17) Then
                       element^.zedo := sqr(z0)/new_value
                     Else
                       element^.zedo := sqrt(infty);
                   End;
               2 :
                   Begin
                     element^.zedo := new_value;
                     If (new_value>1.0e-17) Then
                       element^.zed := sqr(z0)/new_value
                     Else
                       element^.zed := sqrt(infty);
                   End;
               3 : element^.zed := new_value; {both given, even var}
               4 : element^.zedo := new_value; {both given, odd var}
             End; {case index}
           End;
    'l'  :
           Begin {use index to find what lumped value is to be changed}
             If (id In ['F','H']) Then
               If index=2 Then
                 new_value := Omega0*new_value
             Else If index=3 Then
                    new_value := 1.0/(Omega0*new_value);
             Case units Of 
               omega   :  new_value := new_value/z0;
      { 'z','Z','y','Y' :  new_value:=new_value; }
               's','S' :  new_value := new_value*z0;
             End; {case units}
             Case index Of 
               1 : element^.zed := new_value;
     {resistance or conductance}
               2 : element^.zedo := new_value;
     {+ reactance or susceptance}
               3 : element^.wavelength := -new_value;
     {- reactance or susceptance}
   {need minus sign to work for j's}
             End; {Case index}
           End; {Case 'l'}
  End; {case}
End; {* Load_Data *}


(************* Memory Management ********************)




Const memsize = 2*1024*1024;

Var membase : Pointer;
  memused : Longint;

Procedure Init_Mem;
Begin
  getmem(membase,memsize);
  If (membase=Nil) Then
    Begin
      WriteLn ('Memory allocation error!!');
      Halt;
    End;
  memused := 0;
End;

Function Mem_Left: LONGINT;
Begin
  Mem_Left := memsize-memused;
End;

Procedure mygetmem(Var p: pointer; size: longint);
Begin
  p := membase+memused;
  memused := memused+size;
End;

Procedure New_c (Var P: PMemComplex);
Begin
  myGetMem (P, SizeOf (P^));
End;

Procedure New_s (Var P: s_param);
Begin
  myGetMem (P, SizeOf (P^));
End;

Procedure New_plot (Var P: plot_param);
Begin
  myGetMem (P, SizeOf (P^));
End;

Procedure New_spline (Var P: spline_param);
Begin
  myGetMem (P, SizeOf (P^));
End;

Procedure New_n (Var P: net);
Begin
  myGetMem (P, SizeOf (P^));
End;

Procedure New_conn (Var P: conn);
Begin
  myGetMem (P, SizeOf (P^));
End;

Procedure New_compt (Var P: compt);
Begin
  myGetMem (P, SizeOf (P^));
End;

Procedure Mark_Mem (Var P: marker);
Begin
  P.used := memused;
End;

Procedure Release_Mem (Var P: marker);
Begin
  If (P.used>=0) Then memused := P.used;
End;

Procedure Init_Marker (Var P: marker);
Begin
  P.used := -1;
End;

Function Marked (Var P: marker): BOOLEAN;
Begin
  Marked := (P.used >=0 );
End;


Procedure Copy_Networks (NetStart, NetEnd: marker; Var CopyNetStart: marker);
{*
	Make a copy of the circuit for 'destructive' analysis.
*}

Var 
  Size: LONGINT;
  SrcOfs, DestOfs: LONGINT;

Function Min (a, b, c: LONGINT): LONGINT;
Begin
  If (a < b) Then
    Begin
      If (a < c) Then Min := a
      Else Min := c;
    End
  Else
    Begin
      If (b < c) Then Min := b
      Else Min := c;
    End;
End;

Begin
  Size := NetEnd.used - NetStart.used;
  If (Not Marked(CopyNetStart)) Then
    Begin
      If (memused + Size + 1024 >= MemSize) Then Exit;
      CopyNetStart.Used := memused;
      memused := memused + Size;
      DestOfs := CopyNetStart.used;
      SrcOfs := NetStart.used;
    End
  Else
    Begin
      SrcOfs := CopyNetStart.used;
      DestOfs := NetStart.used;
    End;
  Move ( (membase+SrcOfs)^, (membase+DestOfs)^, Size);

End;


Function No_mem_left : boolean;
{*
	Check to see that there is at least a 16 byte
	block of memory remaining on the heap.
*}
Begin
  If Mem_Left < 1024 Then No_mem_left := true
  Else No_mem_left := false;
End;


Procedure SetCol(col: word);
Begin
  If (blackwhite) Then
    Case col Of 
      0    : SetColor(0);
{      1..7 : SetColor(lightgray); }
      8    : SetColor(0);
      Else SetColor(white);
    End
  Else
    SetColor(col);
End;

Procedure TextCol(col: word);
Begin
  If ((blackwhite) And (col <> black)) Then
    TextColor(white)
  Else
    TextColor(col);
End;




End.
