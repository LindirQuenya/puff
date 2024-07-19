import { extract_impedance, extract_length, TLINE_LABEL } from "./regex";
import { LengthUnit, TLine } from "./types";

// Returns null if invalid.
export function parse_tline(s: string): TLine | null {
  // Strip off the label from the front.
  const labelMatch = TLINE_LABEL.exec(s);
  if (!labelMatch) {
    return null;
  }
  let startInd = labelMatch.index + labelMatch[0].length;

  // Extract the impedance.
  const impedance = extract_impedance(s, startInd);
  if (!impedance) {
    return null;
  }
  startInd = impedance[1];

  // Extract the length.
  const length = extract_length(s, startInd);
  if (!length) {
    return null;
  }
  startInd = length[1];

  // Extract the correction, if it exists.
  const correction = extract_length(s, startInd, true) ?? [
    { value: 0, units: LengthUnit.Degrees },
    0,
  ];

  return {
    impedance: impedance[0],
    length: length[0],
    correction: correction[0],
  };
}
