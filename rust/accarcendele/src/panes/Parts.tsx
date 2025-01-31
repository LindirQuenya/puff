import { SyntheticEvent, useEffect, useState } from "react";
import {
  Part,
  PartDimension,
  PartDimensions,
  PartsStr,
  SelectionEvent,
  TLineDimensions,
  TriangleDimensions,
  ValidatedPart,
} from "../types";
import { invoke } from "@tauri-apps/api/core";
import { parse_tline } from "../parts/tline";
import { emit, listen } from "@tauri-apps/api/event";
import { parse_sparamdev } from "../parts/sparamdev";
import "../styles/Parts.css";
import { SetMessage } from "./Message";
import { setAllDims, setDim } from "./Layout";

const partNames = "abcdefghijklmnopqr";

function validate_part(s: string): Part | null {
  if (s.length === 0) {
    return null;
  }
  switch (s[0]) {
    // hmm I want to abstract this into some data structure. TODO please
    case "t": {
      const part = parse_tline(s);
      if (!part) return null;
      return { kind: "t", part };
    }
    case "d": {
      const part = parse_sparamdev(s);
      if (!part) return null;
      return { kind: "d", part };
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

export function Parts() {
  const [parts, setPartstr] = useState(() => {
    return Array.from(partNames).reduce(
      (o, c) => ({ ...o, [c]: { spec: "", parsed: null } }),
      {},
    ) as PartsStr;
  });
  const [selectedPart, setSelectedPart] = useState(
    undefined as keyof PartsStr | undefined,
  );
  async function getDim(c: keyof PartsStr): Promise<PartDimension | undefined> {
    let newdim: PartDimension | undefined = undefined;
    if (parts[c].parsed) {
      switch (parts[c].parsed.kind) {
        case "t": {
          const dim = (await invoke("add_transmission_line", {
            index: c,
            desc: parts[c].parsed.part,
          })) as TLineDimensions;
          newdim = { kind: "t", dim };
          break;
        }
        case "d": {
          const dim = (await invoke("add_sparam_device", {
            index: c,
            desc: parts[c].parsed.part,
          })) as TriangleDimensions;
          newdim = { kind: "d", dim };
          break;
        }
      }
    }
    return newdim;
  }
  async function refreshDim(c: keyof PartsStr) {
    try {
      const dim = await getDim(c);
      console.log(dim);
      setDim(c, dim);
    } catch (e) {
      SetMessage([`Part error: ${c}`, ...(e as string).split('\n'), ""]);
    }
  }
  useEffect(() => {
    const unlisten = listen("config-update", async () => {
      try {
        const dims = (await Promise.all(
          [...partNames].map((c) => getDim(c as keyof PartsStr)
          .then((d) => ({[c as keyof PartsStr]: d} as PartDimensions))
          .catch((e) => {
            SetMessage([`Part error: ${c}`, ...(e as string).split('\n'), ""]);
            throw e;
          }))
        )).reduce((acc, d) => ({...acc, ...d}), {} as PartDimensions);
        setAllDims(dims);
      } catch (e) {
        console.error(e);
      }
      emit("reparse-layout");
    });
    return () => {
      unlisten.then((ul) => ul());
    };
  }, [parts]);
  useEffect(() => {
    const unlisten = listen("part-selection", (e) => {
      setSelectedPart((e.payload as SelectionEvent).selection);
    });
    return () => {
      unlisten.then((ul) => ul());
    };
  }, [parts]);
  return (
    <div
      id="parts"
      className="topmargin"
      onKeyDownCapture={async (e) => {
        const index = get_index(e);
        if (!index) {
          return;
        }
        // TODO: convenient UI things (tab, up/down arrows)
        if (e.key === "=") {
          e.preventDefault();

          let dim = undefined;
          try {
            dim = await getDim(index);
          } catch (e) {
            SetMessage([`Part error: ${index}`, ...(e as string).split('\n'), ""]);
            return;
          }
          if (!dim) {
            SetMessage(["", "Invalid part", ""]);
            return;
          }
          console.log(parts[index]);
          console.log(dim);
          switch (dim.kind) {
            case "t":
              // TODO: make formatting better with non-milli prefixes.
              SetMessage([
                `l: ${(1000 * dim.dim.p_len).toPrecision(5)}mm`,
                `w: ${(1000 * dim.dim.p_width).toPrecision(5)}mm`,
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
                if (selectedPart === c) {
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
                    onBlur={() => {
                      refreshDim(c);
                      emit("reparse-layout");
                    }}
                  ></input>
                </th>
                <td/>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
