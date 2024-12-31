import Chart from "chartjs-chart-smith";
import { useEffect, useState } from "react";
import '../styles/Smith.css';
import { listen } from "@tauri-apps/api/event";
import { Dictionary, PlotSmithEvent } from "../types";

const SI: Dictionary<string> = {
	'12': 'P',
	'9': 'G',
	'6': 'M',
	'3': 'k',
	'-3': 'm',
	'-6': 'u',
  '-9': 'n',
	'-12': 'p',
	'-15': 'f',
};

function freqToString(f: number, digits: number): string {
	// Find order of magnitude.
	const mag = 3*Math.floor(Math.log10(f)/3);
	const mag_str = mag.toString()
	if (mag_str in SI) {
		// Divide by that magnitude, add suffix.
		return (f/Math.pow(10, mag)).toFixed(digits)+' ' +SI[mag_str] +'Hz';
	} else {
		return f.toFixed(digits) + 'Hz';
	}
}

export function Smith() {
	const [data, setData] = useState({datasets: [{
		label: 's11',
		label_polar: false,
		display_precision: 3,
		data: [
		] as {x: number, y: number, f: string}[]
	}]});
	useEffect(() => {
    const unlisten = listen('plot-smith', (e) => {
      const payload = e.payload as PlotSmithEvent;
      const datasets = payload.params.map((arr, i) => {
				return {
					label: `s${payload.payload.params[i][0]}${payload.payload.params[i][1]}`,
					data: arr.map((s, n) => {
						return {
							x: s.re,
							y: s.im,
							f: freqToString(payload.freqs[n], 4),
						};
					}),
					label_polar: true,
					display_precision: 3,
				};
			}) as typeof data.datasets;
			setData({datasets});
    });
    return () => {
      unlisten.then((ul) => ul());
    };
  }, [setData]);
  useEffect(() => {
    const ctx = (document.getElementById('chartjs-0') as HTMLCanvasElement).getContext('2d')!;
    const cfg = {
      type: 'smith',
      options: {
        aspectRatio: 1,
				maintainAspectRatio: false,
				responsive: true,
				resizeDelay: 5,
        elements: {
          point: {
            radius: 2,
            hoverRadius: 3,
            borderColor: 'white'
          }
        },
				legend: {display: true},
				scale: {
					gridLines: {
						color: 'rgba(255, 255, 255, 0.2)',
					},
				}
      },
      data: data
    };
    const chart = new Chart(ctx, cfg);
		return () => {
			chart.destroy();
		};
  }, [data]);
  return <div className="chartjs-wrapper"><canvas id="chartjs-0" className="chartjs"></canvas></div>;
}