import { useState } from 'react';
import { Dictionary, ParsedConfig, SimType, ValidatedInput } from './types';
import './Config.css';
import { prefix_to_scale } from './regex';

const POSITIVE_FLOAT =
  /^\s*(\+?(?:(?:\d+(?:\.\d*)?)|(?:\.\d+)))\s*([fpnumckMGTP]?)\s*$/;

// DANGER: key names must match ParsedConfig
type ConfigStr = {
  zd: ValidatedInput;
  fd: ValidatedInput;
  er: ValidatedInput;
  h: ValidatedInput;
  s: ValidatedInput;
  c: ValidatedInput;
};

function rotateMode(mode: SimType): SimType {
  switch (mode) {
    case SimType.Microstrip:
      return SimType.Stripline;
    case SimType.Stripline:
      return SimType.MicrostripMH;
    case SimType.MicrostripMH:
      return SimType.StriplineMH;
    case SimType.StriplineMH:
      return SimType.Microstrip;
  }
}

function stringMode(mode: SimType): string {
  switch (mode) {
    case SimType.Microstrip:
      return 'Microstrip';
    case SimType.Stripline:
      return 'Stripline';
    case SimType.MicrostripMH:
      return 'MicrostripMH';
    case SimType.StriplineMH:
      return 'StriplineMH';
  }
}

function parseConfig(config: ConfigStr, mode: SimType): ParsedConfig | null {
  // DANGER: this relies on ParsedConfig and ConfigStr having the same key names.
  let parsed = { mode } as ParsedConfig;
  for (const key in config) {
    const matches =
      config[key as keyof ConfigStr].content.match(POSITIVE_FLOAT);
    if (!matches) {
      return null;
    }
    const value = parseFloat(matches[1]);
    const exponent = prefix_to_scale(matches[2]);
    parsed[key as keyof ParsedConfig] = value * 10 ** exponent;
  }
  return parsed;
}

var parsedConfig: ParsedConfig | null = null;

export function getConfig(): ParsedConfig | null {
  return parsedConfig;
}

export function Config() {
  const [config, setConfig] = useState(() => {
    const temp = {
      mode: SimType.Microstrip,
      inputs: {
        zd: { content: '50.000 ', valid: true },
        fd: { content: '3.000G', valid: true },
        er: { content: '10.200 ', valid: true },
        h: { content: '1.270m', valid: true },
        s: { content: '20.000m', valid: true },
        c: { content: '16.000m', valid: true },
      } as ConfigStr,
    };
    parsedConfig = parseConfig(temp.inputs, temp.mode);
    return temp;
  });

  function configrow(key: keyof ConfigStr, label: string, unit: string) {
    const inputclass =
      'configin' + (config.inputs[key].valid ? '' : ' invalid');
    return (
      <tr>
        <th>{label}</th>
        <th>
          <input
            id={'config_'+key}
            className={inputclass}
            value={config.inputs[key].content}
            onInput={(e) =>
              setConfig({
                ...config,
                inputs: {
                  ...config.inputs,
                  [key]: {
                    content: e.currentTarget.value,
                    valid: POSITIVE_FLOAT.test(e.currentTarget.value),
                  },
                },
              })
            }
          ></input>
        </th>
        <td className="configunit">
          <a>{unit}</a>
        </td>
      </tr>
    );
  }

  let order = ['zd', 'fd', 'er', 'h', 's', 'c'];

  return (
    <div
      id="config"
      className="textelem row"
      onKeyDownCapture={(e) => {
        if (e.key === 'Tab') {
          e.preventDefault();
          setConfig({
            ...config,
            mode: rotateMode(config.mode),
          });
        } else if (e.key === 'ArrowDown') {
          e.preventDefault();
          let ind = order.indexOf(document.activeElement?.id ?? '');
          if (ind != -1) {
            ind = (ind + 1) % order.length;
            document.getElementById('config_'+order[ind])?.focus();
          }
        } else if (e.key === 'ArrowUp') {
          e.preventDefault();
          let ind = order.indexOf(document.activeElement?.id ?? '');
          if (ind != -1) {
            ind = (((ind - 1) % order.length) + order.length) % order.length;
            document.getElementById('config_'+order[ind])?.focus();
          }
        }
      }}
      onBlur={(e) => {
        if (
          e.relatedTarget != e.currentTarget &&
          !e.currentTarget.contains(e.relatedTarget)
        ) {
          parsedConfig = parseConfig(config.inputs, config.mode);
        }
      }}
    >
      <table id="configtable">
        <tbody>
          {configrow('zd', 'zd', 'Ω')}
          {configrow('fd', 'fd', 'Hz')}
          {configrow('er', 'er', '')}
          {configrow('h', 'h', 'm')}
          {configrow('s', 's', 'm')}
          {configrow('c', 'c', 'm')}
          <tr>
            <th>Tab</th>
            <th>
              <input
                id="config_mode"
                className="configin"
                readOnly={true}
                value={stringMode(config.mode)}
              ></input>
            </th>
            <td className="configunit">
              <a></a>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  );
}

