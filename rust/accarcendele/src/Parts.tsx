import { useState } from 'react';
import { Dictionary, Part, TLineDimensions } from './types';
import { invoke } from '@tauri-apps/api/core';
import { parse_tline } from './tline';

type PartsStr = {
	a: string,
	b: string,
	c: string,
	d: string,
	e: string,
	f: string,
	g: string,
	h: string,
	i: string,
	j: string,
	k: string,
	l: string,
	m: string,
	n: string,
	o: string,
	p: string,
	q: string,
	r: string,
}

type Parts = {
	[Property in keyof PartsStr]: Part;
}

// TODO: context
let selected: keyof PartsStr | undefined = undefined;

export function select_part(s: string): boolean {
	return true;
}

function validate_part(s: string): Part | null {
	// This should never happen, but just in case.
	if (s.length === 0) {
		return null;
	}
	switch (s[0]) {
		case 't':
			const part = parse_tline(s);
			if (!part) return null;
			return { kind: 't', part };
	}
	return null;
}

export type PartsProps = {
	setMessage: React.Dispatch<React.SetStateAction<string[]>>
}

// TODO: arrow key handling. Constant position?
export function Parts(props: PartsProps) {
	const [partstr, setPartstr] = useState(() => {
		return Array.from('abcdefghijklmnopqr').reduce((o, c) => ({...o, [c]: ""}), {}) as PartsStr;
	});
	// TODO: useMemo?
	const parts = Object.keys(partstr).reduce((o, c) => ({...o, [c]: validate_part(partstr[c as keyof PartsStr])}), {}) as Parts;
  return (
    <div id="parts" className="textelem row" onKeyDownCapture={async (e) => {
			// TODO: convenient UI things (tab, up/down arrows)
			if (e.key === '=') {
				e.preventDefault();
				const target = e.target as HTMLInputElement;
				// Index is the last character of the id.
				const index = target.id.slice(-1) as keyof PartsStr;
				if (!parts[index]) {
					props.setMessage(['', 'Invalid part', '']);
					return;
				}
				console.log(parts[index]);
				switch (parts[index].kind) {
					case 't':
  		  		// TODO: strongly type this.
	    			const dim = await invoke('add_transmission_line', {index: index, linedesc: parts[index].part}) as TLineDimensions;
						// TODO: make formatting better with non-milli prefixes.
						props.setMessage([`l: ${dim.p_len.toPrecision(5)}mm`, `w: ${dim.p_width.toPrecision(5)}mm`, '']);
						break;
				}
			}
		}}>
      <table>
        <tbody>
          {Object.keys(partstr).map((c) => {
						const row = partstr[c as keyof PartsStr];
						let inputclass = "";
						if (row.trim().length !== 0) {
							if (parts[c as keyof PartsStr]) {
								if (selected === c) {
									inputclass = "selected";
								} else {
									inputclass = "active";
								}
							} else {
								inputclass = "invalid";
							}
						}
						return (
            <tr key={c}>
              <th>{c}</th>
              <th>
                <input id={'part_' + c} className={inputclass} value={row} onInput={(e) => {
									setPartstr({
										...partstr,
										[c]: e.currentTarget.value,
									});
								}}></input>
              </th>
            </tr>
          );})}
        </tbody>
      </table>
    </div>
  );
}
