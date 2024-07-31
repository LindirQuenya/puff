#!/usr/bin/env bash
# DOT is on stdin.
sed -E 's/Complex \{ re: (\-?)([0-9.e\-]+), im: (\-?)([0-9.e\-]+) \}/\1\2 imagmarker\3\4j/;s/ imagmarker-/-/;s/ imagmarker/+/; s|0\.6+([+\-])|2/3\1|g; s|0\.3+[0-9]([+\-])|1/3\1|g; s/[0-9.]+e-17/0.0/g; s/[+-]?0\.0j?([+\-]?)/\1/'
