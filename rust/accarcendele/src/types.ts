// DANGER: key names must match ConfigStr
export type ParsedConfig = {
	/** Port impedance */
	zd: number,
	/** Design frequency */
	fd: number,
	/** Dielectric relative permittivity */
	er: number,
	/** Dielectric height */
	h: number,
	/** Board size (todo make both dimensions configurable?) */
	s: number,
	/** Port spacing */
	c: number,
	mode: SimType,
}

export type Impedance = {
	value: number,
	units: ImpedanceUnit,
}

export type Length = {
	value: number,
	units: LengthUnit,
}

export type ValidatedInput = {
	content: string,
	valid: boolean,
}

export enum SimType {
	Microstrip,
	Stripline,
	/** Microstrip, manhattan drawing. */
	MicrostripMH,
	/** Stripline, manhattan drawing. */
	StriplineMH,
}

export type Dictionary<T> = {
	[Key: string]: T
}

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
	impedance: Impedance,
	length: Length,
	correction: Length,
}

export type TLineDimensions = {
	p_len: number,
	p_width: number,
}

export type Transformer = {
	ratio: number,
}

export type Part = {kind: "t", part: TLine} | {kind: "x", part: Transformer};