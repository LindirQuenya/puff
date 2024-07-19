export type MessageProps = {
	message: string[],
}

export function Message(props: MessageProps) {
  return (
    <div id="message" className="textelem row">
      <p>
				{props.message[0]}
				<br/>
				{props.message[1]}
				<br/>
				{props.message[2]}
				<br/>
			</p>
    </div>
  );
}
