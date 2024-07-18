import React from 'react';
import ReactDOM from 'react-dom/client';
import { Config } from './Config';
import { Parts } from './Parts';
import './main.css';

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <React.StrictMode>
    <div id="mainrow" className="row">
      <div id="textcol" className="column">
        <div id="plotconfig" className="textelem row">
          <a>F2</a>
        </div>
        <div id="message" className="textelem row">
          <a>message</a>
        </div>
        <Parts />
        <Config />
      </div>
      <div id="graphcol" className="column">
        <div id="layoutsmithrow" className="row">
          <div id="layout">
            <a>layout</a>
          </div>
          <div id="smith">
            <a>smith</a>
          </div>
        </div>
        <div id="plot">
          <a>plot</a>
        </div>
      </div>
    </div>
  </React.StrictMode>
);

