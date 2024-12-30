import {
  Chart as ChartJS,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
} from "chart.js";
import { Line } from "react-chartjs-2";
import "../styles/Plot.css";
import { useEffect, useState } from "react";
import { listen } from "@tauri-apps/api/event";
import { DoPlotEvent, FrequencySweepArgs } from "../types";
import linspace from "@stdlib/array-linspace";
import { invoke } from "@tauri-apps/api/core";
import { Complex128 } from "@stdlib/complex-float64";
import cabs from "@stdlib/math-base-special-cabs";

ChartJS.register(
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
);

const options_init = {
  responsive: true,
  maintainAspectRatio: true,
  aspectRatio: 2,
  scales: {
    x: {
      type: 'linear',
      grace: '0%',
      
    },
    y: {
      min: -20,
      max: 0
    }
  },
  plugins: {
    legend: {
      position: "top" as const,
    },
    title: {
      display: false,
    },
  },
};

const labels = [0, 1, 2, 3, 4, 5, 100];

const data_init = {
  labels,
  datasets: [
    {
      label: "Dataset 1",
      data: labels.map(() => Math.random() * 1000),
      borderColor: "rgb(255, 99, 132)",
      backgroundColor: "rgba(255, 99, 132, 0.5)",
    },
    {
      label: "Dataset 2",
      data: labels.map(() => Math.random() * 1000),
      borderColor: "rgb(53, 162, 235)",
      backgroundColor: "rgba(53, 162, 235, 0.5)",
    },
  ],
};

export function Plot() {
  const [data, setData] = useState(data_init);
  useEffect(() => {
    const unlisten = listen('do-plot', (e) => {
      const payload = e.payload as DoPlotEvent;
      const freqs = linspace(payload.freqLim[0], payload.freqLim[1], payload.nPoints, {dtype: 'generic'});
      invoke('frequency_sweep', {freqs, sToFrom: payload.params.map(([a,b]) => [a-1,b-1])} as FrequencySweepArgs).catch(console.error).then((sp) => {
        const params = (sp as [number, number][][]).map(arr => arr.map((pair) => new Complex128(pair[0], pair[1])));
        const newData = {
          labels: freqs,
          datasets: params.map((arr, i) => {
            return {
              label: `s${payload.params[i][0]}${payload.params[i][1]}`,
              data: arr.map(s => 20*Math.log10(cabs(s))),
              borderColor: `rgb(${payload.params[i][2]})`,
              backgroundColor: `rgba(${payload.params[i][2]}, 0.25)`,
            };
          })
        };
        setData(newData);
      });
    });
    return () => {
      unlisten.then((ul) => ul());
    };
  }, [setData]);
  return (
    <div id="plot">
      <div id="chart-container">
        <Line options={options_init} data={data} />
      </div>
    </div>
  );
}
