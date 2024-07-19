import { useState } from 'react';
import { Config } from './Config';
import { Parts } from './Parts';
import './main.css';
import { Message, MessageContext } from './Message';

export default function App() {
	let [message, setMessage] = useState(['', '', '']);
	return (<div id="mainrow" className="row">
		<div id="textcol" className="column">
			<div id="plotconfig" className="textelem row">
				<a>F2</a>
			</div>
			<MessageContext.Provider value={message}>
				<Message/>
			</MessageContext.Provider>
			<Parts setMessage={setMessage}/>
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
	</div>);
}