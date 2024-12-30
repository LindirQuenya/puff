import { useEffect, useState } from "react";
import { Config } from "./Config";
import { Parts } from "./Parts";
import "../styles/main.css";
import { Message } from "./Message";
import { PartDimensions, PartsStr } from "../types";
import { Layout } from "./Layout";
import { Plot } from "./Plot";
import { listen } from "@tauri-apps/api/event";
import { invoke } from "@tauri-apps/api/core";
import { PlotControl } from "./PlotControl";
import { Smith } from "./Smith";

// TODO: selected part for F1 screen.
// TODO: react devtools
export default function App() {
  const [message, setMessage] = useState(["", "", ""]);
  const [dims, setDims] = useState({} as PartDimensions);
  const [boardDims, setBoardDims] = useState(12e-3);
  useEffect(() => {
    const unlisten = listen("config-update", async () => {
      setBoardDims(await invoke("get_dimensions"));
    });
    return () => {
      unlisten.then((ul) => ul());
    };
  }, [dims]);
  return (
    <div id="mainrow" className="row">
      <div id="textcol" className="column">
        <div id="plotconfig" className="textelem row">
          <PlotControl />
        </div>
        <Message message={message} />
        <Parts setMessage={setMessage} dims={dims} setDims={setDims} />
        <Config />
      </div>
      <div id="graphcol" className="column">
        <div id="layoutsmithrow" className="row">
          <Layout boardSize={boardDims} dims={dims} />
          <div id="smith">
            <Smith/>
          </div>
        </div>
        <Plot />
      </div>
    </div>
  );
}
