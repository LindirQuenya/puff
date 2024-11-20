import {
  Dictionary,
  Impedance,
  ImpedanceUnit,
  Length,
  LengthUnit,
} from "./types";

export const TLINE_LABEL = /^t[a-z]*\s*/i;
export const SPARAMDEV_LABEL = /^d[a-z]*\s*/i;
export const IMPEDANCE_UNIT = /^([zysoΩ])\s*/i;
// TODO: support manhattan-length components?
export const LENGTH_UNIT = /^([mhdD°])\s*/;
export const GENERIC_FLOAT_CHUNK =
  /^([+-]?(?:(?:\d+(?:\.\d*)?)|(?:\.\d+)))\s*([fpnumckMGTP]?)\s*/;
export const INTEGER_CHUNK = /^([+-]?\d+)\s+/;

export function prefix_to_scale(s: string): number {
  const dict: Dictionary<number> = {
    P: 12,
    G: 9,
    M: 6,
    k: 3,
    c: -2,
    m: -3,
    u: -6,
    n: -9,
    p: -12,
    f: -15,
  };
  if (s in dict) {
    return dict[s];
  }
  return 0;
}

// If properly used, should never return null;
function impedance_unit(s: string): ImpedanceUnit | null {
  const dict: Dictionary<ImpedanceUnit> = {
    z: ImpedanceUnit.Z0,
    Z: ImpedanceUnit.Z0,
    y: ImpedanceUnit.Y0,
    Y: ImpedanceUnit.Y0,
    s: ImpedanceUnit.Siemens,
    S: ImpedanceUnit.Siemens,
    o: ImpedanceUnit.Ohms,
    O: ImpedanceUnit.Ohms,
    Ω: ImpedanceUnit.Ohms,
  };
  if (s in dict) {
    return dict[s];
  }
  return null;
}

// If properly used, should never return null;
function length_unit(s: string): LengthUnit | null {
  const dict: Dictionary<LengthUnit> = {
    h: LengthUnit.SubstrateHeights,
    m: LengthUnit.Meters,
    d: LengthUnit.Degrees,
    D: LengthUnit.Degrees,
    "°": LengthUnit.Degrees,
  };
  if (s in dict) {
    return dict[s];
  }
  return null;
}

export function extract_float(
  s: string,
  start: number,
  allowNegative?: boolean,
): [number, number] | null {
  const match = s.slice(start).match(GENERIC_FLOAT_CHUNK);
  if (!match) {
    return null;
  }
  const value = parseFloat(match[1]);
  if (value < 0 && !allowNegative) {
    return null;
  }
  const exponent = prefix_to_scale(match[2]);
  const newStart = start + match[0].length;
  return [value * 10 ** exponent, newStart];
}

export function extract_integer(
  s: string,
  start: number,
  allowNegative?: boolean,
): [number, number] | null {
  const match = s.slice(start).match(INTEGER_CHUNK);
  if (!match) {
    return null;
  }
  const value = parseInt(match[1]);
  if (value < 0 && !allowNegative) {
    return null;
  }
  const newStart = start + match[0].length;
  return [value, newStart];
}

export function extract_impedance(
  s: string,
  start: number,
): [Impedance, number] | null {
  const num = extract_float(s, start);
  if (!num) {
    return null;
  }
  let [impedanceNum, newStart] = num;
  const unit = s.slice(newStart).match(IMPEDANCE_UNIT);
  if (!unit) {
    return null;
  }
  newStart += unit[0].length;
  // This is a safe non-null assertion, because impedance_unit would only return
  // null for letters that wouldn't match the regex to begin with.
  return [{ value: impedanceNum, units: impedance_unit(unit[1])! }, newStart];
}

export function extract_length(
  s: string,
  start: number,
  allowNegative?: boolean,
): [Length, number] | null {
  const num = extract_float(s, start, allowNegative);
  if (!num) {
    return null;
  }
  let [lengthNum, newStart] = num;
  const unit = s.slice(num[1]).match(LENGTH_UNIT);
  if (!unit) {
    return null;
  }
  newStart += unit[0].length;
  return [{ value: lengthNum, units: length_unit(unit[1])! }, newStart];
}
