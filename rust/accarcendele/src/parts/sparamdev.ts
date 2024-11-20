import { extract_integer, SPARAMDEV_LABEL } from "../regex";
import { SparamDev } from "../types";

// Returns null if invalid.
export function parse_sparamdev(s: string): SparamDev | null {
  // Strip off the label from the front.
  const labelMatch = SPARAMDEV_LABEL.exec(s);
  if (!labelMatch) {
    return null;
  }
  let startInd = labelMatch.index + labelMatch[0].length;

  // Extract the number of ports.
  const nports_parsed = extract_integer(s, startInd);
  if (nports_parsed) {
    startInd = nports_parsed[1];
  }

  // Extract the filename.
  const filename = s.slice(startInd);
  const nports_guessed = filename.match(/s(\d+)p$/i);
  let nports = 0;
  if (nports_parsed) {
    nports = nports_parsed[0];
  } else if (nports_guessed) {
    nports = parseInt(nports_guessed[1]);
  } else {
    return null;
  }

  // Don't do path validation here, let the backend handle that.
  return {
    filename,
    nports,
  };
}
