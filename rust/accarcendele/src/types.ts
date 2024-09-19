// DANGER: key names must match ConfigStr
export type ParsedConfig = {
  /** Port impedance */
  zd: number;
  /** Design frequency */
  fd: number;
  /** Dielectric relative permittivity */
  er: number;
  /** Dielectric height */
  h: number;
  /** Board size (todo make both dimensions configurable?) */
  s: number;
  /** Port spacing */
  c: number;
  mode: SimType;
};

export type Impedance = {
  value: number;
  units: ImpedanceUnit;
};

export type Length = {
  value: number;
  units: LengthUnit;
};

export type ValidatedInput = {
  content: string;
  valid: boolean;
};

export enum SimType {
  Microstrip,
  Stripline,
  /** Microstrip, manhattan drawing. */
  MicrostripMH,
  /** Stripline, manhattan drawing. */
  StriplineMH,
}

export type Dictionary<T> = {
  [Key: string]: T;
};

export enum ImpedanceUnit {
  Ohms,
  Siemens,
  Z0,
  Y0,
}

export enum LengthUnit {
  Degrees,
  Meters,
  SubstrateHeights,
}

export type TLine = {
  impedance: Impedance;
  length: Length;
  correction: Length;
};

export type TLineDimensions = {
  p_len: number;
  p_width: number;
};

export type Transformer = {
  ratio: number;
};

export type Part =
  | { kind: "t"; part: TLine }
  | { kind: "x"; part: Transformer };

export type ValidatedPart = {
  spec: string;
  parsed: Part | null;
};

export type PartsStr = {
  a: ValidatedPart;
  b: ValidatedPart;
  c: ValidatedPart;
  d: ValidatedPart;
  e: ValidatedPart;
  f: ValidatedPart;
  g: ValidatedPart;
  h: ValidatedPart;
  i: ValidatedPart;
  j: ValidatedPart;
  k: ValidatedPart;
  l: ValidatedPart;
  m: ValidatedPart;
  n: ValidatedPart;
  o: ValidatedPart;
  p: ValidatedPart;
  q: ValidatedPart;
  r: ValidatedPart;
};

export type PartDimensions = {
  [Property in keyof PartsStr]: PartDimension | undefined;
};

export type PartDimension = { kind: "t"; dim: TLineDimensions };

export type SelectionEvent = {
  selection: keyof PartsStr | undefined
};