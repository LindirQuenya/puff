Arbitrary choices I have made
====
The simulation backend tries to be as generic as possible. It does *only* simulation, not validation of constraints. The original _Puff_ code included validation of e.g. width constraints in the simulation functions. I think this is sloppy. Some simulation code can return errors if it thinks there will be numerical instability. Exception: components should include functions to allow for the frontend to calculate length corrections. Some things (degrees, for example) cannot possibly be known without internal backend knowledge.

TODO maybe remove that, and pull it into a separate constraints/warnings module along with manufacturing checks?

Parsing will be handled in a separate module. It is essentially a frontend design choice, so it should be handled there.

The name candidates include _hwesta_ (Quenya verb stem "to puff") and anything Gondolin-related. _Puff_ was named after the magic dragon, so a rusty version should naturally be named after the magical *iron* dragons, used by Melkor to besiege Gondolin after Maeglin's betrayal. Because this tool is to be used for crafting complex circuits, I decided that *Enerdhil* (a renowned jewel-smith from Gondolin who created the Elessar) would work temporarily.
