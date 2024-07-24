import { useState } from "react";
import { Config } from "./Config";
import { Parts } from "./Parts";
import "./main.css";
import { Message } from "./Message";
import { PartDimensions } from "./types";
import { Layout } from "./Layout";
import { Plot } from "./Plot";

// TODO: selected part for F1 screen.
// TODO: react devtools
export default function App() {
  const [message, setMessage] = useState(["", "", ""]);
  const [dims, setDims] = useState({} as PartDimensions);
  return (
    <div id="mainrow" className="row">
      <div id="textcol" className="column">
        <div id="plotconfig" className="textelem row">
          <a>F2</a>
        </div>
        <Message message={message} />
        <Parts setMessage={setMessage} dims={dims} setDims={setDims} />
        <Config />
      </div>
      <div id="graphcol" className="column">
        <div id="layoutsmithrow" className="row">
          <Layout/>
          <div id="smith">
            <a>smith</a>
          </div>
        </div>
        <Plot/>
      </div>
    </div>
  );
}
