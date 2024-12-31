import "../styles/Message.css";

export type MessageProps = {
  message: string[];
};

export function Message(props: MessageProps) {
  return (
    <div id="message" className="second-to-shrink topmargin">
      <p>
        {props.message[0]}
        <br />
        {props.message[1]}
        <br />
        {props.message[2]}
        <br />
      </p>
    </div>
  );
}
