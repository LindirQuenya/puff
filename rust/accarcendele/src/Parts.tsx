import { useState } from 'react';
import { ValidatedInput } from './types';

type PartsStr = {
	a: ValidatedInput,
	b: ValidatedInput,
	c: ValidatedInput,
	d: ValidatedInput,
	e: ValidatedInput,
	f: ValidatedInput,
	g: ValidatedInput,
	h: ValidatedInput,
	i: ValidatedInput,
	j: ValidatedInput,
	k: ValidatedInput,
	l: ValidatedInput,
	m: ValidatedInput,
	n: ValidatedInput,
	o: ValidatedInput,
	p: ValidatedInput,
	q: ValidatedInput,
	r: ValidatedInput,
}

function validate_part(s: string): boolean {
	return true;
}

export function Parts() {
	const [parts, setParts] = useState(() => {
		return Array.from('abcdefghijklmnopqr').reduce((o, c) => ({...o, [c]: {content: "", valid: true}}), {}) as PartsStr;
	});
  return (
    <div id="parts" className="textelem row">
      <table>
        <tbody>
          {Object.keys(parts).map((c) => {
						const row = parts[c as keyof PartsStr];
						const inputclass = row.content.trim().length == 0 ? "" : row.valid ? "active" : "invalid";
						return (
            <tr>
              <th>{c}</th>
              <th>
                <input id={'part_' + c} className={inputclass} value={row.content} onInput={(e) => {
									setParts({
										...parts,
										[c]: {
											content: e.currentTarget.value,
											valid: validate_part(e.currentTarget.value),
										},
									})
								}}></input>
              </th>
            </tr>
          );})}
        </tbody>
      </table>
    </div>
  );
}
