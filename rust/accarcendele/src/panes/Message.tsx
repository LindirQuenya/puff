import { useEffect, useState } from "react";
import "../styles/Message.css";
import { emit, listen } from "@tauri-apps/api/event";

export function Message() {
  const [message, setMessage] = useState(["", "", ""]);
  useEffect(() => {
    const unlisten = listen('set-message', (e) => {
      setMessage(e.payload as string[]);
    });
    return () => {
      unlisten.then((ul) => ul());
    };
  }, [setMessage]);
  return (
    <div id="message" className="second-to-shrink topmargin">
      <p id="message-p">
        {message[0]}
        <br />
        {message[1]}
        <br />
        {message[2]}
        <br />
      </p>
    </div>
  );
}

export function SetMessage(msg: string[]) {
  emit('set-message', msg);
}