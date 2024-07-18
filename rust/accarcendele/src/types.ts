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

export type ValidatedInput = {
	content: string,
	valid: boolean,
}

export enum SimType {
	Microstrip,
	Stripline,
	MicrostripMH,
	StriplineMH,
}

export type Dictionary<T> = {
	[Key: string]: T
}

export enum ImpedanceSpec {
	Ohms,
	Siemens,
	Z0,
	Y0,
}

export enum LengthSpec {
	Degrees,
	Millimeters,
	SubstrateHeights,
}
