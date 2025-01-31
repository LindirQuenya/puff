import { useEffect, useState } from "react";
import { extract_float } from "../regex";
import { emit, listen } from "@tauri-apps/api/event";
import { DoPlotEvent, LayoutParsedEvent } from "../types";

export function PlotControl() {
	const [sToFrom, _setSToFrom] = useState([[1, 1], [2, 1], [3, 1], [4, 1]] as ([number | null, number | null])[]);
	const [availablePorts, setAvailablePorts] = useState([] as number[]);
	useEffect(() => {
    const unlisten = listen("layout-parsed", (l) => {
      setAvailablePorts((l.payload as LayoutParsedEvent).availablePorts)
    });
    return () => {
      unlisten.then((ul) => ul());
    };
  }, [setAvailablePorts]);
	const colors = ["255, 0, 0", "0, 255, 255", "0, 0, 255", "255, 255, 0"];
	// Dummy value 10, port 10 doesn't exist and thus should not appear in availablePorts.
	const sToFrom_usable = sToFrom.map((v, i) => {return {"v": v, "c": colors[i]};})
	.filter((o) => availablePorts.includes((o['v'][0] ?? 10) - 1) && availablePorts.includes((o['v'][1] ?? 10) - 1))
	.map((o) => [o['v'][0], o['v'][1], o['c']] as [number, number, string]);
	const [freqLim, setFreqLim] = useState(["1k", "5G"]);
	const freqLim_parsed = freqLim.map(l => extract_float(l, 0, false)?.[0]).filter(f => f!==undefined);
	const [nPoints, setNPoints] = useState("200");
	const nPoints_parsed = parseInt(nPoints);
	const [smithR, setSmithR] = useState("1");
	//const smithR_parsed = extract_float(smithR, 0, false)?.[0];
	return (
	<div id="plotcontroldiv" className="second-to-shrink" >
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
		<tbody>
		<tr>
			<th>Points</th>
			<th><input value={nPoints} onChange={(e) => setNPoints(e.target.value)}/></th>
		</tr>
		<tr>
			<th>Smith Radius</th>
			<th><input value={smithR} onChange={(e) => setSmithR(e.target.value)}/></th>
		</tr>
		<tr>
			<th>fmin</th>
			<th><input value={freqLim[0]} onChange={(e) => setFreqLim([e.target.value, freqLim[1]])}/></th>
			<td>Hz</td>
		</tr>
		<tr>
			<th>fmax</th>
			<th><input value={freqLim[1]} onChange={(e) => setFreqLim([freqLim[0], e.target.value])}/></th>
			<td>Hz</td>
		</tr>
		</tbody>
	</table>
	</div>
	);
}