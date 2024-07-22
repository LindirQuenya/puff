import { SyntheticEvent, useEffect, useState } from "react";
import {
  Part,
  PartDimension,
  PartDimensions,
  PartsStr,
  TLineDimensions,
  ValidatedPart,
} from "./types";
import { invoke } from "@tauri-apps/api/core";
import { parse_tline } from "./tline";
import { subscribe, unsubscribe } from "./events";

const partNames = 'abcdefghijklmnopqr';

function validate_part(s: string): Part | null {
  if (s.length === 0) {
    return null;
  }
  switch (s[0]) {
    case "t": {
      const part = parse_tline(s);
      if (!part) return null;
      return { kind: "t", part };
    }
  }
  return null;
}

const PARTID = /part_([a-r])/;

function get_index(e: SyntheticEvent): keyof PartsStr | null {
  // This cast is technically incorrect - it may not be an <input>.
  // But it makes the TS compiler shut up about me accessing .id (possibly undefined), so we're good.
  const target = e.target as HTMLInputElement;
  const match = PARTID.exec(target.id ?? "");
  return match?.[1] as keyof PartsStr | null;
}

export type PartsProps = {
  setMessage: React.Dispatch<React.SetStateAction<string[]>>;
  dims: PartDimensions;
  setDims: React.Dispatch<React.SetStateAction<PartDimensions>>;
};

export function Parts(props: PartsProps) {
  const [parts, setPartstr] = useState(() => {
    return Array.from(partNames).reduce(
      (o, c) => ({ ...o, [c]: { spec: "", parsed: null } }),
      {},
    ) as PartsStr;
  });
  async function getDim(c: keyof PartsStr): Promise<PartDimension | undefined> {
    let newdim: PartDimension | undefined = undefined;
    // TODO handle errors from invoke.
    if (parts[c].parsed) {
      switch (parts[c].parsed.kind) {
        case "t": {
          const dim = (await invoke("add_transmission_line", {
            index: c,
            linedesc: parts[c].parsed.part,
          })) as TLineDimensions;
          newdim = { kind: "t", dim };
          break;
        }
      }
    }
    return newdim;
  }
  async function refreshDim(c: keyof PartsStr) {
    const dim = await getDim(c);
    console.log(dim);
    props.setDims({
      ...props.dims,
      [c]: dim,
    });
  }
  useEffect(() => {
    let refresh = async () => {
      await Promise.all([...partNames].map((c) => refreshDim(c as keyof PartsStr)));
    };
    subscribe('refreshdims', refresh);
    return () => unsubscribe('refreshdims', refresh);
  }, [parts]);
  return (
    <div
      id="parts"
      className="textelem row"
      onKeyDownCapture={async (e) => {
        const index = get_index(e);
        if (!index) {
          return;
        }
        // TODO: convenient UI things (tab, up/down arrows)
        if (e.key === "=") {
          e.preventDefault();
          const dim = await getDim(index);
          if (!dim) {
            props.setMessage(["", "Invalid part", ""]);
            return;
          }
          console.log(parts[index]);
          console.log(dim);
          switch (dim.kind) {
            case "t":
              // TODO: make formatting better with non-milli prefixes.
              props.setMessage([
                `l: ${(1000*dim.dim.p_len).toPrecision(5)}mm`,
                `w: ${(1000*dim.dim.p_width).toPrecision(5)}mm`,
                "",
              ]);
              break;
          }
        }
      }}
    >
      <table>
        <tbody>
          {Object.keys(parts).map((ind) => {
            const c = ind as keyof PartsStr;
            const row = parts[c].spec;
            let inputclass = "";
            if (row.trim().length !== 0) {
              if (parts[c].parsed) {
                // TODO: selection from F1.
                if (false) {
                  inputclass = "selected";
                } else {
                  inputclass = "active";
                }
              } else {
                inputclass = "invalid";
              }
            }
            return (
              <tr key={c}>
                <th>{c}</th>
                <th>
                  <input
                    id={"part_" + c}
                    className={inputclass}
                    value={row}
                    onInput={(e) => {
                      setPartstr({
                        ...parts,
                        [c]: {
                          spec: e.currentTarget.value,
                          parsed: validate_part(e.currentTarget.value),
                        } as ValidatedPart,
                      });
                    }}
                    onBlur={() => refreshDim(c)}
                  ></input>
                </th>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}