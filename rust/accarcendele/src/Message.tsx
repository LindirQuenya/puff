import { createContext, useContext } from 'react';

// TODO: array
export const MessageContext = createContext(['', '', '']);

export function Message() {
  let message = useContext(MessageContext);
  return (
    <div id="message" className="textelem row">
      <p>
				{message[0]}
				<br/>
				{message[1]}
				<br/>
				{message[2]}
				<br/>
			</p>
    </div>
  );
}
