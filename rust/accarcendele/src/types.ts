import { NetListElement } from "./layout_util";
import { Complex128 } from '@stdlib/types/complex';
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
  Microstrip = 0,
  Stripline = 1,
  /** Microstrip, manhattan drawing. */
  MicrostripMH = 2,
  /** Stripline, manhattan drawing. */
  StriplineMH = 3,
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

export type SparamDev = {
  nports: number;
  filename: string;
};

export type TriangleDimensions = {
  base: number;
  height: number;
  port_heights: number[];
};

export type Transformer = {
  ratio: number;
};

export type Part =
  | { kind: "t"; part: TLine }
  | { kind: "x"; part: Transformer }
  | { kind: "d"; part: SparamDev };

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

export type PartDimension =
  | { kind: "t"; dim: TLineDimensions }
  | { kind: "d"; dim: TriangleDimensions };

export type SelectionEvent = {
  selection: keyof PartsStr | undefined;
};

export enum Direction {
  Up,
  Down,
  Right,
  Left,
}

export type CanvasProps = {
  pos: PhysicalCoordinates;
  width_m: number;
  height_m: number;
};
export type DrawFunc = {
  (ctx: CanvasRenderingContext2D, width_px: number, height_px: number): void;
};
export type DrawingUpdate = {
  update: DrawFunc;
  new_pos: PhysicalCoordinates;
};
export type PhysicalCoordinates = {
  x_m: number;
  y_m: number;
};
export type ParseLayoutArgs = {
  netlist: NetListElement[];
  portNetlistInd: (number | null)[];
  grounds: number[];
};
export type LayoutParsedEvent = {
  availablePorts: number[];
};

export type DoPlotEvent = {
  params: [number, number, string][],
  freqLim: [number, number],
  nPoints: number
};

export type PlotSmithEvent = {
  params: Complex128[][],
  freqs: number[],
  payload: DoPlotEvent,
};

export type FrequencySweepArgs = {
  freqs: number[],
  sToFrom: [number, number][]
}