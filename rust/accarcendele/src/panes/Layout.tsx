import { useEffect, useState } from "react";
import "../styles/Layout.css";
import {
  CanvasPixels,
  CanvasProps,
  LayoutParsedEvent,
  ParsedConfig,
  ParseLayoutArgs,
  PartDimension,
  PartDimensions,
  PartsStr,
  SelectionEvent,
  UpdateDimEvent,
} from "../types";
import { emit, Event, listen } from "@tauri-apps/api/event";
import {
  board_init,
  LayoutEvent,
  optimize_event_list,
  processKeyPress,
  renderEvents,
} from "../layout_util";
import { invoke } from "@tauri-apps/api/core";
import { SetMessage } from "./Message";

export function setDim(index: keyof PartsStr, dim: PartDimension | undefined) {
  emit("dim-update", {
    index,
    dim,
  } as UpdateDimEvent);
}

export function setAllDims(dims: PartDimensions) {
  emit("all-dims-update", dims);
}

export function Layout() {
  const [dims, setDims] = useState({} as PartDimensions);
  useEffect(() => {
    const unlisten = listen("dim-update", async (e: Event<UpdateDimEvent>) => {
      setDims({ ...dims, [e.payload.index]: e.payload.dim });
    });
    return () => {
      unlisten.then((ul) => ul());
    };
  }, [dims]);
  useEffect(() => {
    const unlisten = listen(
      "all-dims-update",
      async (e: Event<PartDimensions>) => {
        setDims(e.payload);
      },
    );
    return () => {
      unlisten.then((ul) => ul());
    };
  }, [dims]);
  const [boardSize, setBoardSize] = useState(12e-3);
  const [portSpacing, setPortSpacing] = useState(10e-3);
  const [z0Width, setZ0Width] = useState(10e-3);
  useEffect(() => {
    const unlisten = listen("config-update", (e: Event<ParsedConfig>) => {
      setBoardSize(e.payload.s);
      setPortSpacing(e.payload.c);
      setZ0Width(e.payload.zd_width!);
    });
    return () => {
      unlisten.then((ul) => ul());
    };
  }, [dims]);
  // TODO make nets be the same if within some fuzzy region (manufacturing resolution?)
  // TODO make this incremental/cached?
  const [eventList, setEventList] = useState([] as LayoutEvent[]);
  const [borderWidth, _setBorderWidth] = useState(10);
  const dim_px = Math.floor(
    Math.min(0.45 * window.innerHeight, 0.35 * window.innerWidth),
  );
  // TODO memo
  const canvasProps = {
    pos: {
      x_m: boardSize / 2,
      y_m: boardSize / 2,
    },
    width_m: boardSize,
    height_m: boardSize,
  } as CanvasProps;
  const init_update = board_init(canvasProps, portSpacing, z0Width);
  const [layout, err] = renderEvents(dims, eventList, canvasProps);
  if (err != null) {
    // TODO make this a real error message.
    SetMessage(["Layout error: ", err, ""]);
  }
  useEffect(() => {
    const canvas = document.getElementById("layoutCanvas") as HTMLCanvasElement;
    const context = canvas.getContext("2d");
    if (context) {
      const canvas_px: CanvasPixels = {
        width_px: canvas.width - 2 * borderWidth,
        height_px: canvas.height - 2 * borderWidth,
        offset_x: borderWidth,
        offset_y: borderWidth,
      };
      // Calculate the port locations for the other draw functions.
      // Give this one a dummy port info, it won't use it.
      const ports = init_update(context, canvas_px, {
        z0Width: 0,
        ports_px: [],
      })!;
      for (const update of layout.updates) {
        update(context, canvas_px, ports);
      }
    }
  }, [eventList, boardSize, dims, borderWidth, init_update]);
  useEffect(() => {
    const unlisten = listen("reparse-layout", (_e) => {
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
    });
    return () => {
      unlisten.then((ul) => ul());
    };
  }, [layout.netlist, layout.ports]);
  return (
    <div
      id="layout"
      tabIndex={0}
      onKeyDown={(e) => {
        const newEvents = processKeyPress(e, eventList, dims, layout);
        if (newEvents !== null) {
          setEventList(optimize_event_list(newEvents));
        }
      }}
      onBlur={() => {
        emit("part-selection", { selection: undefined } as SelectionEvent);
        emit("reparse-layout");
      }}
      onFocus={() => {
        emit("part-selection", {
          selection: layout.selectedPart,
        } as SelectionEvent);
      }}
    >
      <canvas id="layoutCanvas" width={dim_px} height={dim_px} />
    </div>
  );
}
