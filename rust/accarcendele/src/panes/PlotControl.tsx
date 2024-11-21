import { useEffect, useState } from "react";
import { extract_float, extract_integer } from "../regex";
import { emit, listen } from "@tauri-apps/api/event";
import { DoPlotEvent, LayoutParsedEvent } from "../types";

export function PlotControl() {
	const [sToFrom, setSToFrom] = useState([[1, 1], [2, 1], [3, 1], [4, 1]] as ([number | null, number | null])[]);
	const [availablePorts, setAvailablePorts] = useState([] as number[]);
	useEffect(() => {
    const unlisten = listen("layout-parsed", (l) => {
      setAvailablePorts((l.payload as LayoutParsedEvent).availablePorts)
    });
    return () => {
      unlisten.then((ul) => ul());
    };
  }, [setAvailablePorts]);
	// Dummy value 10, port 10 doesn't exist and thus should not appear in availablePorts.
	const sToFrom_usable = sToFrom.filter(v => availablePorts.includes((v[0] ?? 10) - 1) && availablePorts.includes((v[1] ?? 10) - 1));
	const [freqLim, setFreqLim] = useState(["1k", "5G"]);
	const freqLim_parsed = freqLim.map(l => extract_float(l, 0, false)?.[0]).filter(f => f!==undefined);
	const [nPoints, setNPoints] = useState("200");
	const nPoints_parsed = parseInt(nPoints);
	const [smithR, setSmithR] = useState("1");
	const smithR_parsed = extract_float(smithR, 0, false)?.[0];
	return (
	<table id="plotcontroltable" onKeyDownCapture={(e) => {
		if (e.key.toLowerCase() === 'p') {
			e.preventDefault();
			// Try to plot.
			if (sToFrom_usable.length > 0 && freqLim_parsed.length == 2 && nPoints_parsed !== undefined) {
				console.log('PlotControl: do-plot');
				emit('do-plot', {params: sToFrom_usable, freqLim: freqLim_parsed, nPoints: nPoints_parsed} as DoPlotEvent);
			}
		}
	}}>
		<tr>
			<th>Points</th>
			<th><input value={nPoints}/></th>
		</tr>
		<tr>
			<th>Smith Radius</th>
			<th><input value={smithR}/></th>
		</tr>
		<tr>
			<th>fmin</th>
			<th><input value={freqLim[0]}/></th>
			<td>Hz</td>
		</tr>
		<tr>
			<th>fmax</th>
			<th><input value={freqLim[1]}/></th>
			<td>Hz</td>
		</tr>
	</table>
	);
}