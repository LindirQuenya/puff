{$R-}    {Range checking}
{$S-}    {Stack checking}
{$B-}    {Boolean complete evaluation or short circuit}
{$I+}    {I/O checking on}


Unit pfrw;


(*******************************************************************

	Unit PFRW;

        This code is now licenced under GPLv3.

	Copyright (C) 1991, S.W. Wedge, R.C. Compton, D.B. Rutledge.
        Copyright (C) 1997,1998, A. Gerstlauer.

	Code cleanup for Linux only build 2009 Leland C. Scott.

	Original code released under GPLv3, 2010, Dave Rutledge.


	Potentially hazardous code is denoted by {!xxx} comments

	Contains code for reading and writing .puf files.

********************************************************************)

Interface

Uses 
Dos,   {Unit found in Free Pascal RTL's}
xgraph, {Custom replacement unit for TUBO's "Crt" and "Graph" units}
pfun1, {Add other puff units}
pfun2;


Procedure Read_Board(read_graphics : boolean);
Procedure read_keyO;
Procedure read_partsO;
Procedure read_circuitO;
Procedure Read_S_Params;
Procedure save_boardO;
Procedure save_keyO;
Procedure save_partsO;
Procedure save_circuitO;
Procedure save_s_paramsO;
Procedure bad_board;
Procedure read_setup(Var fname2 : file_string);


Implementation


Procedure Read_Board(read_graphics : boolean);
{*
	Read board parameters from .puf file.
*}

Const 
  {* Artwork Reduction Ratios in mm/dot *}
  red_psx = 0.2117; { 25.4 mm/in  /(120 dots) in x dirn for matrix artwork}
  red_psy = 0.1764; { 25.4 mm/in  /(144 dots) in y dirn for matrix artwork}
  red_lasr = 0.169333; { LaserJet reduction ratio = 25.4 mm/in * 1/150dpi }

Var 
  i      : integer;
  value  : double;
  unit_prf      : string[80];  {unit-prefix string}
  char1,char2,
  char3,prefix  : char;


   {*****************************************************}
Function file_prefix(id_string : String) : char;

{*
		Look for prefixes when reading board parameters.
		If no prefix and no unit then return 'x' to
		designate that default prefixes are to be used.
	*}

Var 
  pot_prefix : char;

Begin
  While id_string[1]=' ' Do
    Delete(id_string,1,1); {delete leading blanks}
  If id_string[1] In Eng_Dec_Mux Then
    Begin
      pot_prefix := id_string[1];
      If (id_string[1]='m') And (Not(id_string[2] In ['H','O','m']))
        Then pot_prefix := ' ';
       {if its just meters, then no prefix}
    End
  Else If id_string[1]='U' Then
         Begin   {U = micro}
           pot_prefix := Mu;  {convert U to Mu}
         End
  Else If (id_string[1] In ['H','O']) Then
         Begin {Hz or Ohms?}
           pot_prefix := ' ';  {if units but no prefix}
         End
  Else  {if no prefix or units return 'x'}
    pot_prefix := 'x';
  file_prefix := pot_prefix;
End;

 {*******************************************************}
Procedure Attach_Prefix(b_num : integer; def_prefix : char;
                        Var board_param : double; zero_OK : boolean);
{*

*}
Begin
  ReadLn(net_file,value,unit_prf);
  prefix := file_prefix(unit_prf);
  If def_prefix='G' Then
    Begin   {Do not attach prefix for xHz}
      board_param := value;
      If prefix='x' Then
        Begin
          s_board[b_num,2] := 'G';
          freq_prefix := 'G'; {use default prefix}
        End
      Else
        Begin
          s_board[b_num,2] := prefix;
          freq_prefix := prefix;
        End;
    End
  Else If prefix='x' Then
         Begin
           board_param := value;
           s_board[b_num,2] := def_prefix; {use default prefix}
         End
  Else
    Begin {if prefix is given}
      board_param := value*Eng_Prefix(prefix)/Eng_Prefix(def_prefix);
 {return value in default units }
      s_board[b_num,2] := prefix;
    End;
  If (board_param > 0.0) Or ((board_param=0.0) And zero_OK) Then
    Begin
      board[b_num] := true;
      Str(value:7:3,s_board[b_num,1]);
      If ((value < 1.0e-3) Or (value > 1.0e+3)) And Not(value=0.0) Then
        Str(value:8,s_board[b_num,1]);
  {Write in exponential notation for small/large numbers}
    End;
End;
 {****************************************************}

Begin  {* Read_Board *}
  {* Default parameters for old .puf files without new parameters *}
  For i:=9 To 12 Do
    board[i] := true;  {Make these parameters optional}
  Art_Form := 0;
  Laser_Art := False;
  {initialize new parameters for old puff files}
  metal_thickness := 0.0;
  s_board[9,1] := '  0.000';
  s_board[9,2] := 'm';
  surface_roughness := 0.0;
  s_board[10,1] := '  0.000' ;
  s_board[10,2] := Mu;
  loss_tangent := 0.0;
  s_board[11,1] := '  0.000';
  s_board[11,2] := ' ';
  conductivity := 5.80e+7;
  s_board[12,1] := '  5.8E+7';
  s_board[12,2] := ' ';
  Repeat
    If SeekEoln(net_file) Then
      Begin {ignore blank lines}
        readln(net_file); {advance to beginning of next line}
        char1 := ' ';
      End
    Else
      Begin
        Repeat
          read(net_file,char1);
        Until char1 <> ' ';
        If char1 <> '\' Then
          Begin
            Read(net_file,char2);
            If (char2<>' ') Then
              Repeat
                read(net_file,char3)
              Until char3=' ';
            Case char1 Of 
              'z','Z' : Attach_Prefix(1,' ',z0,false);
              'f','F' : Attach_Prefix(2,'G',design_freq,false);
     {prefix not attached here}
              'e','E' :
                        Begin
                          ReadLn(net_file,er); {no units here}
                          If er > 0 Then
                            Begin
                              board[3] := true;
                              Str(er:7:3,s_board[3,1]);
                              s_board[3,2] := ' '; {no units}
                            End;
                        End;
              'h','H' : Attach_Prefix(4,'m',substrate_h,false);
              's','S' : If (char2 In ['r','R']) Then
                          Begin
                            Board[10] := false; {init-optional value}
                            Attach_Prefix(10,Mu,surface_roughness,true);
                          End
                        Else
                          Begin
                            Attach_Prefix(5,'m',bmax,false);
                          End;
              'c','C' : If (char2 In ['d','D']) Then
                          Begin
                            board[12] := false; {init-optional}
                            ReadLn(net_file,conductivity); {no units here}
                            If (conductivity > 0) Then
                              Begin
                                board[12] := true;
                                Str(conductivity:8,s_board[12,1]);
                                s_board[12,2] := ' '; {no units}
                              End;
                          End
                        Else
                          Attach_Prefix(6,'m',con_sep,true);
              'r','R' :
                        Begin
                          Attach_Prefix(7,'m',resln,false);
                          sresln := s_board[7,1]+s_board[7,2]+'m';
                        End;
              'a','A' : Attach_Prefix(8,'m',artwork_cor,true);
              'm','M' : If (char2 In ['t','T']) Then
                          Begin
                            Board[9] := false; {init-optional value}
                            Attach_Prefix(9,'m',metal_thickness,true);
                          End
                        Else
                          Begin
                            Readln(net_file,miter_fraction);
                            If (0 <= miter_fraction) And (miter_fraction < 1)
                              Then board[16] := true;
                          End;
              'l','L' :
                        Begin   {Loss Tangent}
                          Board[11] := false; {init-optional}
                          ReadLn(net_file,loss_tangent); {no units here}
                          If loss_tangent >= 0 Then
                            Begin
                              board[11] := true;
                              Str(loss_tangent:8,s_board[11,1]);
                              s_board[11,2] := ' '; {no units}
                            End;
                        End;
              'p','P' :
                        Begin
                          ReadLn(net_file,reduction);
                          If reduction > 0 Then
                            If Laser_Art Then
                              Begin  {setup 150 DPI}
                                psx := red_lasr/reduction;
                                psy := red_lasr/reduction;
                                board[13] := true;
                              End
                          Else
                            Begin  {setup 144 x 120 DPI}
                              psx := red_psx/reduction;
                              psy := red_psy/reduction;
                              board[13] := true;
                            End; {if reduction and/or Laser_art}
                        End;
              'd','D' : If read_graphics Then
                          Begin
                            readln(net_file,value);
                            display := Round(value);
                            board[14] := true;
   { ignore the VGA/EGA setting on Linux }
                            imin := 1;
                          End
                        Else
                          Begin
                            ReadLn(net_file,value);
                            board[14] := true;
                          End;
              'o','O' :
                        Begin   {* New entry for artwork output *}
                          readln(net_file,value);
                          Art_Form := Round(value);
                          If Art_Form = 1 Then Laser_Art := True;
                        End;
              't','T' :
                        Begin
                          ReadLn(net_file,value);
                          If (Round(value)=2) Then
                            Begin
                              Manhattan_Board := true;
                              stripline := true; {makes calculations easier}
                            End
                          Else
                            Begin
                              Manhattan_Board := false;
                              stripline := Round(value) <> 0;
                            End;
                          If (Round(value) In [0..2]) Then board[15] := true;
                        End;
              Else
                Begin
                  message[2] := 'Unknown board';
                  message[3] := 'parameter in .puf';
                  shutdown;
                End;
            End;{case char1}
          End; {if char1}
      End; {if SeekEoln}
  Until (char1='\') Or EOF(net_file);
  board_read := board[1];
  For i:=2 To 12 Do
    board_read := board_read And board[i];
  If board_read And Not(read_graphics) Then Fresh_Dimensions;
End; {* Read_Board *}


Procedure Read_KeyO;
{*
	Read key from .puf file.
*}

Var 
  len,j,i  : integer;
  des      : line_string;
  c1,c2,c3,char1 : char;

Begin
  For i:=1 To 6  Do
    s_key[i] := ' ';
  For i:=7 To 10 Do
    s_key[i] := '';
  Repeat
    If Eoln(net_file) Then
      Begin  {ignore blank lines}
        readln(net_file);
        char1 := ' ';
      End
    Else
      Begin
        read(net_file,char1);
        des := '';
        If char1 <> '\' Then
          Begin
            des := char1;
            Repeat
              read(net_file,char1);
              des := des+char1;
            Until (char1=lbrack) Or Eoln(net_file);
            readln(net_file);
            c1 := des[1];
            c2 := des[2];
            c3 := des[3];
            While Not(des[1]In ['+','-','.',',','0'..'9','e','E']) 
              Do
              Delete(des,1,1);
            len := length(des);
            While Not(des[len]In ['+','-','.',',','0'..'9','e','E'])
                  And (len > 0) Do
              Begin
                Delete(des,len,1);
                len := length(des);
              End;
            Case c1 Of 
              'd','D' : If c2 In ['u','U'] Then s_key[1] := des
                        Else s_key[2] := des;
              'f','F' : Case c2 Of 
                          'l','L': s_key[3] := des;
                          'u','U': s_key[4] := des;
                          'd','D': If c3='/' Then s_key[5] := des
                        End; {case}
              'p','P' : s_key[5] := des; {pts=number of points}
              's','S' : If c2 In ['r','R'] Then
                          Begin
                            s_key[6] := des;
                          End
                        Else
                          Begin
                            j := 6;
                            Repeat
                              j := j+1;
                            Until (length(s_key[j])=0) Or (j>9);
                            s_key[j] := des;
                          End;
            End; {case}
          End; {if char1 ..}
      End; {if Eoln}
  Until (char1='\') Or EOF(net_file);
End; {* Read_Key *}


Procedure read_partsO;

{*
	Read parts from .puf file. 
	Called by Read_Net() in pfmain1a.pas.
	Upon a call to read_partsO the read index has already 
	advanced to the point where a '\p' has been read.
*}

Var 
  char1  : char;
  i,j    : integer;
  des    : line_string;
  tcompt : compt;

Begin
  Large_Parts := False;
  {* Clear previous parts list *}
  For i:=1 To 18 Do
    Begin
      If i=1 Then tcompt := part_start
      Else tcompt := tcompt^.next_compt;
      With tcompt^ Do
        Begin
          descript := char(ord('a')+i-1)+' ';
          used := 0;
          changed := false;
          parsed := false;
          f_file := Nil;
          s_file := Nil;
          s_ifile := Nil;
        End; {with}
    End; {for i:=1 to 18}
  j := 0;
  Repeat
    If Eoln(net_file) Then
      Begin {if at end_of_line..}
        readln(net_file);        {do carriage return}
        char1 := ' ';    {initialize char1}
      End
    Else
      Begin
        read(net_file,char1);
        If char1 <> '\' Then
          Begin {dont read first line with '\p'}
            readln(net_file,des); {read string}
            insert(char1, des, 1);
            Inc(j);
            If j <= 18 Then
              Begin
                i := Pos(lbrack,des);
                If i> 0 Then Delete(des,i,length(des));
                For i:=1 To length(des) Do
                  Case des[i] Of 
                    'O' :  des[i] := Omega;
                    'D' :  des[i] := Degree;
                    'U' :  des[i] := Mu;
                    '|' :  des[i] := Parallel;
                  End; {case}
                While des[length(des)]=' ' Do
                  delete(des,length(des),1);
     {delete extra blanks}
                If j=1 Then tcompt := part_start
                Else tcompt := tcompt^.next_compt;
                With tcompt^ Do
                  If (length(des) = 0) Then
                    changed := true
       {descript:=descript}
       {leave part blank}
                  Else
                    Begin
                      descript := descript+des;
                      changed := true;
                      If (j>9) Then Large_Parts := True;
                    End; {if and with}
              End; {if j <= 18}
          End; {if char1<>'\'}
      End; {else Eoln}
  Until (char1='\') Or EOF(net_file);
End; {read_partsO}


Procedure read_circuitO;
{*
	Read in circuit from .puf file.
*}

Var 
  key_i,nn : integer;
  char1    : char;

Begin
  circuit_changed := true;
  key_end := 0;
  Repeat
    If Not(Eof(net_file)) Then  {read circuit}
      If Eoln(net_file) Then
        Begin  {ignore blank lines}
          readln(net_file);
          char1 := ' ';
        End
    Else
      Begin
        read(net_file,char1);
        If char1 <> '\' Then
          Begin
            readln(net_file,key_i,nn);
            key := char(key_i);
            update_key_list(nn);
          End;{if char1}
      End;{if Eoln}
  Until (char1='\') Or EOF(net_file);
  key_i := 0; {set_up for redraw}
End; {read_circuitO}



Procedure Read_S_Params;
{*
	Read s-parameters from .puf file.
	Uses procedure Read_Number.
*}

Var 
  ij          : integer;
  freq,mag,ph : double;
  char1       : char;

 {********************************************************}
Procedure Read_Number(Var s : double);
{*
	Read s-parameter values from files.
*}

Const 
  potential_numbers = ['+','-','.','0'..'9','e','E'];

Var 
  ss : string[128];
  code : integer;
  found : boolean;

Begin
  ss := '';
  If char1 In potential_numbers Then
    ss := char1  {char1 is the first freq character}
  Else
    Begin  {Search for first valid numeric character}
      found := false;
      If char1 In [lbrack,'#','!'] Then ReadLn(net_file);
 {skip potential comment lines}
      Repeat
        Read(net_file,char1);  {read another character}
        If char1 In [lbrack,'#','!'] Then ReadLn(net_file);
      {skip potential comment lines}
        If char1 In potential_numbers Then
          Begin
            ss := char1;
            found := true;
          End;
      Until found Or (char1='\');
    End;
  found := false;
  If Not(char1='\') Then
    Repeat {Add to string ss}
      Read(net_file,char1);
      If char1 In potential_numbers Then
        ss := ss+char1
      Else
        found := true;
    Until found Or Eoln(net_file);
  If (ss<>'') Then
    Begin
      Val(ss,s,code);
      If (code<>0) Then s := 0.0;
    End
  Else
    s := 0.0;
  { turn string ss into double number }
End; {read_number}
 {********************************************************}

Begin   {* Read_S_Params *}
  filled_OK := true;
  npts := -1;
  ReadLn(net_file); {Advance through \s comment line}
  For ij:=1 To max_params Do
    Begin
      s_param_table[ij]^.calc := false;
      c_plot[ij] := Nil;
      plot_des[ij] := Nil;
    End;
  Repeat
    If Eoln(net_file) Then
      Begin {ignore blank lines}
        ReadLn(net_file);
        char1 := ' ';
      End
    Else
      Begin
        Read(net_file,char1);
        If (char1<>'\') And (npts+1 < ptmax) Then
          Begin
            Read_Number(freq);
            Inc(npts);
            If npts=0 Then fmin := freq;
            ij := 0;
            Repeat
              Inc(ij);
              If c_plot[ij]=Nil Then c_plot[ij] := plot_start[ij]
              Else c_plot[ij] := c_plot[ij]^.next_p;
              If abs(freq-design_freq)=0 Then
                plot_des[ij] := c_plot[ij];
   {restore markers to fd}
              s_param_table[ij]^.calc := true;
              c_plot[ij]^.filled := true;
              read(net_file,mag,ph);
              c_plot[ij]^.x := mag*cos(ph*pi/180);
              c_plot[ij]^.y := mag*sin(ph*pi/180);
            Until Eoln(net_file) Or (ij=max_params);
            Readln(net_file);
          End; {if char}
      End; {if Eoln else}
  Until (char1='\') Or EOF(net_file);
  If npts<=1 Then filled_OK := false;
  For ij:=1 To max_params Do
    plot_end[ij] := c_plot[ij];
  finc := (freq-fmin)/npts;
End; {* Read_S_Params *}



Procedure Save_BoardO;
{*
	Save board parameters to .puf file.
*}

Var 
  sl,i : integer;

Begin
  For i:=1 To 12 Do
    Begin        {* Convert Mu's to U's *}
      If s_board[i,2]=Mu Then s_board[i,2] := 'U';
    End;
  writeln(net_file,'\b',lbrack,'oard',rbrack,' ',
          lbrack,'.puf file for PUFF, version 2.1d',rbrack);
  writeln(net_file,'d ',display:6,'     ',lbrack,
          'display: 0 VGA or PUFF chooses, 1 EGA',rbrack);
  writeln(net_file,'o ',Art_Form:6,'     ',lbrack,
          'artwork output format: 0 dot-matrix, 1 LaserJet, 2 HPGL file',rbrack);
  If Manhattan_Board Then sl := 2
  Else If stripline Then sl := 1
  Else sl := 0;
  writeln(net_file,'t ',sl:6,'     ',lbrack,
          'type: 0 for microstrip, 1 for stripline, 2 for Manhattan',rbrack);
  writeln(net_file,'zd  ',s_board[1,1]+' '+s_board[1,2]+'Ohms ',lbrack,
          'normalizing impedance. 0<zd',rbrack);
  writeln(net_file,'fd  ',s_board[2,1]+' '+s_board[2,2]+'Hz   ',lbrack,
          'design frequency. 0<fd',rbrack);
  writeln(net_file,'er  ',s_board[3,1]+'       ',lbrack,
          'dielectric constant. er>0',rbrack);
  writeln(net_file,'h   ',s_board[4,1]+' '+s_board[4,2]+'m    ',lbrack,
          'dielectric thickness. h>0',rbrack);
  writeln(net_file,'s   ',s_board[5,1]+' '+s_board[5,2]+'m    ',lbrack,
          'circuit-board side length. s>0',rbrack);
  writeln(net_file,'c   ',s_board[6,1]+' '+s_board[6,2]+'m    ',lbrack,
          'connector separation. c>=0',rbrack);
  writeln(net_file,'r   ',s_board[7,1]+' '+s_board[7,2]+'m    ',lbrack,
          'circuit resolution, r>0, use Um for micrometers', rbrack);
  writeln(net_file,'a   ',s_board[8,1]+' '+s_board[8,2]+'m    ',lbrack,
          'artwork width correction.',rbrack);
  writeln(net_file,'mt  ',s_board[9,1]+' '+s_board[9,2]+'m    ',lbrack,
          'metal thickness, use Um for micrometers.',rbrack);
  writeln(net_file,'sr  ',s_board[10,1]+' '+s_board[10,2]+'m    ',lbrack,
          'metal surface roughness, use Um for micrometers.',rbrack);
  writeln(net_file,'lt   ',s_board[11,1]+'   ',lbrack,
          'dielectric loss tangent.',rbrack);
  writeln(net_file,'cd   ',s_board[12,1]+'   ',lbrack,
          'conductivity of metal in mhos/meter.',rbrack);
  writeln(net_file,'p   ',reduction:7:3,'       ',lbrack,
          'photographic reduction ratio. p<=203.2mm/s',rbrack);
  writeln(net_file,'m   ',miter_fraction:7:3,'       ',lbrack,
          'mitering fraction.  0<=m<1',rbrack);
  For i:=1 To 12 Do
    Begin        {* Convert U's back to Mu's *}
      If s_board[i,2]='U' Then s_board[i,2] := Mu;
    End;
End; {save_boardO}


Procedure save_keyO;
{*
	Save Plot window parameters to .puf file.
*}

Var 
  tcompt : compt;
  i      : integer;
  temp   : line_string;

Begin
  writeln(net_file,'\k',lbrack,'ey for plot window',rbrack);
  For i:=1 To 10 Do
    Begin
      If i=1 Then tcompt := coord_start
      Else tcompt := tcompt^.next_compt;
      With tcompt^ Do
        Case i Of 
          1   :  writeln(net_file,'du  '+descript,
                         '   ',lbrack,'upper dB-axis limit',rbrack);
          2   :  writeln(net_file,'dl  '+descript,
                         '   ',lbrack,'lower dB-axis limit',rbrack);
          3   :  writeln(net_file,'fl  '+descript,
                         '   ',lbrack,'lower frequency limit. fl>=0',rbrack);
          4   :  writeln(net_file,'fu  '+descript,
                         '   ',lbrack,'upper frequency limit. fu>fl',rbrack);
          5   :
                Begin
                  temp := descript;
                  delete(temp,1,6); {delete "Points"}
                  writeln(net_file,'pts'+temp,
                          '   ',lbrack,'number of points, positive integer',rbrack);
                End;
          6   :
                Begin
                  temp := descript;
                  delete(temp,1,12);
                  writeln(net_file,'sr'+temp,
                          '   ',lbrack,'Smith-chart radius. sr>0',rbrack);
                End;
          7..10:
                 Begin
                   temp := descript;
                   delete(temp,1,1);
                   If length(temp) > 0 Then
                     Begin
                       write(net_file,'S   '+temp);
                       If i=7 Then writeln(net_file,
                                           '   ',lbrack,'subscripts must be 1, 2, 3, or 4',rbrack)
                       Else writeln(net_file);
                     End;
                 End;
        End; {case}
    End; {i}
End; {save_keyO}


Procedure Save_PartsO;
{*
	Save list of parts to .puf file.
*}

Var 
  tcompt : compt;
  des    : line_string;
  i      : integer;

Begin
  tcompt := Nil;
  writeln(net_file,'\p',lbrack,'arts window',rbrack,' ',
          lbrack,'O = Ohms, D = degrees, U = micro, |=parallel',rbrack);
  Repeat {write component list}
    If tcompt=Nil Then
      tcompt := part_start  {find starting pointer}
    Else
      tcompt := tcompt^.next_compt; { or find next }
    des := tcompt^.descript;
    If length(des) > 2 Then
      Begin  {if descript more than just a letter}
        Delete(des,1,2); {delete part letter designation}
        For i:=1 To length(des) Do
          Case des[i] Of   {change to O's, D's, U's, and |'s}
            Omega  : des[i] := 'O';
            Degree : des[i] := 'D';
            Mu     : des[i] := 'U';
            Parallel : des[i] := '|';
          End; {case}
        writeln(net_file,des);
      End    {if length(des) > 2}
    Else   {write blank message }
      writeln(net_file,lbrack,'Blank at Part ',des,rbrack);
  Until tcompt^.next_compt=Nil;
End; {* Save_PartsO *}


Procedure save_circuitO;
{*
	Save circuit to .puf file.
*}
Begin
  For key_i:=1 To key_end Do
    Begin
      If key_i=1 Then writeln(net_file,'\c',lbrack,'ircuit',rbrack);
      write(net_file,ord(key_list[key_i].keyl): 4,key_list[key_i].noden: 4);
      Case key_list[key_i].keyl Of 
        right_arrow : writeln(net_file,'  right');
        left_arrow  : writeln(net_file,'  left');
        down_arrow  : writeln(net_file,'  down');
        up_arrow    : writeln(net_file,'  up');
        sh_right    : writeln(net_file,'  shift-right');
        sh_left     : writeln(net_file,'  shift-left');
        sh_down     : writeln(net_file,'  shift-down');
        sh_up       : writeln(net_file,'  shift-up');
        sh_1        : writeln(net_file,'  shift-1');
        sh_2        : writeln(net_file,'  shift-2');
        sh_3        : writeln(net_file,'  shift-3');
        sh_4        : writeln(net_file,'  shift-4');
        '+'         : writeln(net_file,'  shift-=');
        Ctrl_n      : writeln(net_file,'  Ctrl-n');
        Else        writeln(net_file,'  ',key_list[key_i].keyl);
      End; {case}
    End; {for key_i}
End; {save_circuitO}


Procedure save_s_paramsO;
{*
	Save s-parameters to .puf file.
*}

Var 
  number_of_parameters,ij,txpt  : integer;
  first_line    : string[120];
  mag,deg       : double;
  last_plot_ptr   : array [1..max_params] Of plot_param;

Begin
  If filled_OK Then
    Begin
      writeln(net_file,'\s',lbrack,'parameters',rbrack);
      number_of_parameters := 0;
      first_line := '';
      For ij:=1 To max_params Do
        If s_param_table[ij]^.calc Then
          Begin
            last_plot_ptr[ij] := c_plot[ij];  {save last plot position}
            c_plot[ij] := Nil;
            If first_line='' Then
              first_line := '   f              '+s_param_table[ij]^.descript
            Else
              first_line := first_line+'              '+s_param_table[ij]^.descript;
            number_of_parameters := number_of_parameters+1;
          End; {for ij;if s_param_table}
      writeln(net_file,first_line);
      For txpt:=0 To npts Do
        Begin
          freq := fmin+finc*txpt;
          write(net_file,freq:9:5);
          For ij:=1 To max_params Do
            If s_param_table[ij]^.calc Then
              Begin
                If c_plot[ij]=Nil Then c_plot[ij] := plot_start[ij]
                Else c_plot[ij] := c_plot[ij]^.next_p;
                mag := sqrt(sqr(c_plot[ij]^.x)+sqr(c_plot[ij]^.y));
                deg := atan2(c_plot[ij]^.x,c_plot[ij]^.y);
                If betweenr(0.1,mag,99.0,0.0) Then
                  write(net_file,mag:10:5,' ',deg:6:1)
                Else
                  write(net_file,' ',mag:9,' ',deg:6:1)
              End; {for ij ; if s_param_table}
          writeln(net_file);
        End; {for txpt:=0 to npts}
      For ij:=1 To max_params Do
        If s_param_table[ij]^.calc Then
          c_plot[ij] := last_plot_ptr[ij];  {restore last plot position}
    End;{if filled_OK}
End; {save_s_paramsO}


Procedure bad_board;
{*
   Give error message when bad board element is present.
*}

Var 
  i : integer;
Begin
  erase_message;
  message[2] := 'Bad or invalid';
  i := 0;
  Repeat
    i := i+1;
    If Not(board[i]) Then
      Begin
        Case i Of 
          1 : message[3] := 'zd';
          2 : message[3] := 'fd';
          3 : message[3] := 'er';
          4 : message[3] := 'h';
          5 : message[3] := 's';
          6 : message[3] := 'c';
          7 : message[3] := 'r';
          8 : message[3] := 'a';
          9 : message[3] := 'mt';
          10 : message[3] := 'sr';
          11 : message[3] := 'lt';
          12 : message[3] := 'cd';
          13 : message[3] := 'p';
          14 : message[3] := 'd';
          15 : message[3] := 't';
          16 : message[3] := 'm';
        End;{case}
        message[3] := message[3]+' in .puf file'
      End;
  Until Not(board[i]);
  shutdown;
End; {* bad_board *}


Procedure read_setup(Var fname2 : file_string);
{*
	Read board parameters in setup.puf.
*}

Var 
  char1,char2 : char;

Begin
  If setupexists(fname2) Then
    Begin
      Repeat
        ReadLn(net_file,char1,char2);
      Until ((char1='\') And (char2 In ['b','B'])) Or Eof(net_file);
      If Not(EOF(net_file)) Then Read_Board(true);
      Close(net_file);
    End;
End; {* read_setup *}



End.
