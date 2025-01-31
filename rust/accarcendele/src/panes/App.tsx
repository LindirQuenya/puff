import { Config } from "./Config";
import { Parts } from "./Parts";
import "../styles/main.css";
import { Message } from "./Message";
import { Layout } from "./Layout";
import { Plot } from "./Plot";
import { PlotControl } from "./PlotControl";
import { Smith } from "./Smith";

// TODO: selected part for F1 screen.
// TODO: react devtools
export default function App() {
  return (
    <div id="mainrow" className="row flex-container">
      <div id="textcol" className="column flex-container">
        <PlotControl/>
        <Message/>
        <Parts />
        <Config />
      </div>
      <div id="graphcol">
        <div id="layoutsmithrow" className="row flex-container">
        <Layout/>
        <Smith/>
        </div>
        <Plot/>
      </div>
    </div>
  );
}
