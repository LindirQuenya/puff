import Chart from "chartjs-chart-smith";
import { useEffect } from "react";
import '../styles/Smith.css';

export function Smith() {
  useEffect(() => {
    const ctx = (document.getElementById('chartjs-0') as HTMLCanvasElement).getContext('2d')!;
    const cfg = {
      type: 'smith',
      options: {
        aspectRatio: 1,
				maintainAspectRatio: false,
				responsive: true,
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
      data: {
        datasets: [{
					label: 's11',
					label_polar: false,
					display_precision: 3,
					data: [
									{ x : 0.65, y : 0.4,  f : "3.5GHz" },
									{ x : 0.23, y : 0.3,  f : "3.6GHz" },
									{ x : -0.5, y : 0.2,  f : "3.8GHz" },
									{ x : -0.7, y : -0.3, f : "3.9GHz" },
									{ x : -0.6, y : -0.6, f : "4.0GHz" },
									{ x :  0.0, y : -1.0, f : "4.1GHz" },
									{ x : 0.43, y : -0.6, f : "4.2GHz" }
					],
				}]
      }
    };
    new Chart(ctx, cfg);
  });
  return <div className="chartjs-wrapper"><canvas id="chartjs-0" className="chartjs"></canvas></div>;
}