import { useEffect, useState } from "react";
import "./Layout.css";
import { PartDimensions, PartsStr, SelectionEvent } from "./types";
import { emit } from "@tauri-apps/api/event";

export type LayoutProps = {
  dims: PartDimensions;
	/// in mm
  boardSize: number;
};
const clamp = (n: number, min: number, max: number) => {
  return Math.min(Math.max(n, min), max);
};

type NetNode  = {
	// Indicies of other nodes.
	left: number,
	right: number,
	up: number,
	down: number,
	// Position
	x: number,
	y: number,
};

export function Layout(props: LayoutProps) {
  // TODO make nets be the same if within some fuzzy region (manufacturing resolution?)
  // TODO make this incremental/cached?
  const [keysPressed, setKeysPressed] = useState([] as React.KeyboardEvent[]);
  // Convention: the origin is in the top left corner. X and Y range from 0 to 1.
  let cursorXY = [0.5, 0.5];
  let nodes: NetNode[] = [];
	let netlist: [keyof PartDimensions, number, number][] = []; 
  let selectedPart = "a" as keyof PartDimensions;
	let failed = false;
  for (const key of keysPressed) {
    if (key.key.substring(0, 5) === "Arrow") {
			const len = props.dims[selectedPart]?.dim.p_len;
			if (len === undefined) {
				// bad part? bail out. Don't try to draw.
				failed = true;
				break;
			}
			const normLen = len / props.boardSize;
      switch (key.key.substring(5)) {
        case 'Up':
					cursorXY[1] -= normLen;
          break;
				case 'Down':
					cursorXY[1] += normLen;
          break;
				case 'Left':
					cursorXY[0] -= normLen;
          break;
				case 'Right':
					cursorXY[0] += normLen;
					break;
			}
			if (Math.max(...cursorXY) > 1 || Math.min(...cursorXY) < -1) {
				failed = true;
				console.log('Failed!');
				break;
			}
    } else if (key.key.toLowerCase().match(/^[a-r]$/) != null) {
			selectedPart = key.key.toLowerCase() as keyof PartDimensions;
		}
  }
	useEffect(() => {
		const canvas = document.getElementById('layoutCanvas') as HTMLCanvasElement;
		const context = canvas.getContext("2d");
		const parent = getComputedStyle(document.getElementById("layout")!);
		if (context) {
			context.clearRect(0, 0, canvas.width, canvas.height);
			const [x, y] = [Math.round(canvas.width * cursorXY[0]), Math.round(canvas.height * cursorXY[1])];
			context.beginPath();
			context.moveTo(x - 10, y);
			context.lineTo(x + 10, y);
			context.moveTo(x, y - 10);
			context.lineTo(x, y + 10);
			context.strokeStyle = '#DB14C1';
			context.stroke();
		}
	}, [cursorXY]);
  return (
    <div id="layout" tabIndex = {0} onKeyDown={(e) => {
			if (e.key.toLowerCase().match(/^[a-r]$|^arrow/) != null) {
				console.log(`down: ${e.key}`);
				e.preventDefault();
				// TODO: filtering/undoing logic
				if (e.key.toLowerCase().match(/^[a-r]$/) != null) {
					console.log(`selected: ${e.key}`);
					emit('part-selection', {selection: e.key.toLowerCase() as keyof PartsStr} as SelectionEvent)
				}
				setKeysPressed([...keysPressed, e]);
			}
		}} onBlur={() => {
			emit('part-selection', {selection: undefined} as SelectionEvent)
		}}>
      <canvas id="layoutCanvas"/>
    </div>
  );
}
