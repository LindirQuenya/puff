Arbitrary choices I have made
====
The simulation backend tries to be as generic as possible. It does *only* simulation, not validation of constraints. The original _Puff_ code included validation of e.g. width constraints in the simulation functions. I think this is sloppy. Some simulation code can return errors if it thinks there will be numerical instability.

TODO maybe remove that, and pull it into a separate constraints/warnings module along with manufacturing checks?

Parsing will be handled in a separate module.
