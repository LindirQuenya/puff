import { useEffect, useState } from "react";
import "./Layout.css";
import {
  CanvasProps,
  LayoutParsedEvent,
  ParseLayoutArgs,
  PartDimensions,
  SelectionEvent,
} from "./types";
import { emit } from "@tauri-apps/api/event";
import {
  LayoutEvent,
  optimize_event_list,
  processKeyPress,
  renderEvents,
} from "./layout_util";
import { invoke } from "@tauri-apps/api/core";

export type LayoutProps = {
  dims: PartDimensions;
  /// in mm
  boardSize: number;
};
const clamp = (n: number, min: number, max: number) => {
  return Math.min(Math.max(n, min), max);
};

export function Layout(props: LayoutProps) {
  // TODO make nets be the same if within some fuzzy region (manufacturing resolution?)
  // TODO make this incremental/cached?
  const [eventList, setEventList] = useState([] as LayoutEvent[]);
  // TODO memo
  const canvasProps = {
    pos: {
      x_m: props.boardSize / 2,
      y_m: props.boardSize / 2,
    },
    width_m: props.boardSize,
    height_m: props.boardSize,
  } as CanvasProps;
  const [layout, err] = renderEvents(props.dims, eventList, canvasProps);
  if (err != null) {
    // TODO make this a real error message.
    console.error("Layout error: " + err);
  }
  useEffect(() => {
    const canvas = document.getElementById("layoutCanvas") as HTMLCanvasElement;
    const context = canvas.getContext("2d");
    if (context) {
      context.clearRect(0, 0, canvas.width, canvas.height);
      for (const update of layout.updates) {
        update(context, canvas.width, canvas.height);
      }
    }
  }, [eventList, props.boardSize, props.dims]);
  return (
    <div
      id="layout"
      tabIndex={0}
      onKeyDown={(e) => {
        const newEvents = processKeyPress(e, eventList, props.dims, layout);
        if (newEvents !== null) {
          setEventList(optimize_event_list(newEvents));
        }
      }}
      onBlur={() => {
        emit("part-selection", { selection: undefined } as SelectionEvent);
        const ports = [];
        const sim_netlist = [...layout.netlist];
        for (const port of layout.ports) {
          if (port !== null) {
            sim_netlist.push({
              // Internally, z means match. It's not a real part, hush hush.
              part: "z" as keyof PartDimensions,
              port_nets: [port.net_index],
              source_event: 0,
            });
            ports.push(sim_netlist.length - 1);
          } else {
            ports.push(null);
          }
        }
        // TODO grounds
        invoke("parse_layout", {
          netlist: sim_netlist,
          portNetlistInd: ports,
          grounds: [],
        } as ParseLayoutArgs)
          .catch(console.error)
          .then((val) =>
            emit("layout-parsed", {
              availablePorts: val as number[],
            } as LayoutParsedEvent),
          );
      }}
      onFocus={() => {
        emit("part-selection", {
          selection: layout.selectedPart,
        } as SelectionEvent);
      }}
    >
      <canvas id="layoutCanvas" width="200px" height="200px" />
    </div>
  );
}
