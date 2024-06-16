{$R-}    {Range checking}
{$S-}    {Stack checking on}
{$B-}    {Boolean complete evaluation or short circuit}
{$I+}    {I/O checking on}

Unit testlib;

Interface
Function Rough_alpha(alpha_in,freq,Mu_0,conductivity,surface_roughness : double) : double;
Implementation

Function Rough_alpha(alpha_in,freq,Mu_0,conductivity,surface_roughness : double) : double;

{*
        Scale conductor loss alpha to include surface roughness.
        Surface_roughness is given in micrometers.
*}

Var
  skin_depth,
  angle_arg  : double;

Begin
  If (freq>0.0) And (surface_roughness>0.0) Then
    Begin
      skin_depth := 1.0e6/sqrt(Pi*freq*Mu_0*conductivity);
      angle_arg := 1.4*sqr(surface_roughness/skin_depth);
      Rough_alpha := alpha_in*(1.0 + 2*arctan(angle_arg)/Pi);
    End
  Else
    Rough_alpha := alpha_in;
End;

End.
