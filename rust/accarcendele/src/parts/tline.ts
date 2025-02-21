import { getNode, NetListElement, NetNode, to_px } from "../layout_util";
import { extract_impedance, extract_length, TLINE_LABEL } from "../regex";
import { Render } from "../render/Render";
import {
  CanvasPixels,
  CanvasProps,
  Direction,
  DrawingUpdate,
  LengthUnit,
  PartDimensions,
  PhysicalCoordinates,
  TLine,
  TLineDimensions,
} from "../types";

// Returns null if invalid.
export function parse_tline(s: string): TLine | null {
  // Strip off the label from the front.
  const labelMatch = TLINE_LABEL.exec(s);
  if (!labelMatch) {
    return null;
  }
  let startInd = labelMatch.index + labelMatch[0].length;

  // Extract the impedance.
  const impedance = extract_impedance(s, startInd);
  if (!impedance) {
    return null;
  }
  startInd = impedance[1];

  // Extract the length.
  const length = extract_length(s, startInd);
  if (!length) {
    return null;
  }
  startInd = length[1];

  // Extract the correction, if it exists.
  const correction = extract_length(s, startInd, true) ?? [
    { value: 0, units: LengthUnit.Degrees },
    0,
  ];

  return {
    impedance: impedance[0],
    length: length[0],
    correction: correction[0],
  };
}

export function move_half_tline(
  dim: TLineDimensions,
  canvas: CanvasProps,
  dir: Direction,
): PhysicalCoordinates | null {
  let doubled = draw_tline(
    "a",
    dim,
    {
      pos: {
        x_m: canvas.pos.x_m * 2,
        y_m: canvas.pos.y_m * 2,
      },
      width_m: canvas.width_m * 2,
      height_m: canvas.height_m * 2,
    },
    dir,
  );
  if (doubled === null) {
    return null;
  }
  return {
    x_m: doubled[0].new_pos.x_m / 2,
    y_m: doubled[0].new_pos.y_m / 2,
  };
}

export function draw_tline(
  letter: string,
  dim: TLineDimensions,
  canvas: CanvasProps,
  dir: Direction,
): [DrawingUpdate, PhysicalCoordinates[]] | null {
  let maxX = -1,
    maxY = -1,
    minX = -1,
    minY = -1,
    newX = -1,
    newY = -1;
  switch (dir) {
    // TODO maybe simplify with e.g. "getDimensions()->bounding box", and then a generic function to do direction-matching?
    // Though honestly there are only a few components that don't end up looking the same. Most are either a rectangle or triangle.
    // Coupled lines are an odd one out.
    case Direction.Up: {
      maxX = canvas.pos.x_m + dim.p_width / 2;
      minX = canvas.pos.x_m - dim.p_width / 2;
      maxY = canvas.pos.y_m;
      minY = canvas.pos.y_m - dim.p_len;
      newX = canvas.pos.x_m;
      newY = minY;
      break;
    }
    case Direction.Down: {
      maxX = canvas.pos.x_m + dim.p_width / 2;
      minX = canvas.pos.x_m - dim.p_width / 2;
      maxY = canvas.pos.y_m + dim.p_len;
      minY = canvas.pos.y_m;
      newX = canvas.pos.x_m;
      newY = maxY;
      break;
    }
    case Direction.Left: {
      maxY = canvas.pos.y_m + dim.p_width / 2;
      minY = canvas.pos.y_m - dim.p_width / 2;
      maxX = canvas.pos.x_m;
      minX = canvas.pos.x_m - dim.p_len;
      newY = canvas.pos.y_m;
      newX = minX;
      break;
    }
    case Direction.Right: {
      maxY = canvas.pos.y_m + dim.p_width / 2;
      minY = canvas.pos.y_m - dim.p_width / 2;
      maxX = canvas.pos.x_m + dim.p_len;
      minX = canvas.pos.x_m;
      newY = canvas.pos.y_m;
      newX = maxX;
      break;
    }
  }
  if (minY < 0 || maxY > canvas.height_m || minX < 0 || maxX > canvas.width_m) {
    return null;
  }

  const update = (
    render: Render
  ) => {
    render.draw_box({x_m: minX, y_m: minY}, {x_m: maxX-minX, y_m: maxY-minY}, "#808000");
    render.preview_text({x_m: (minX+maxX)/2, y_m: (minY+maxY)/2}, letter, "red");
  };

  return [
    {
      update,
      new_pos: {
        x_m: newX,
        y_m: newY,
      },
    },
    [
      {
        x_m: canvas.pos.x_m,
        y_m: canvas.pos.y_m,
      },
      {
        x_m: newX,
        y_m: newY,
      },
    ],
  ];
}

export function update_netlist_tline(
  port_locations: PhysicalCoordinates[],
  netlist: NetListElement[],
  nodes: NetNode[],
  dir: Direction,
  source_event: number,
  part: keyof PartDimensions,
): [NetListElement[], NetNode[]] {
  let port1 = -1,
    port2 = -1;
  // TODO figure out tolerance
  [nodes, port1] = getNode(
    nodes,
    port_locations[0].x_m,
    port_locations[0].y_m,
    1e-12,
  );
  [nodes, port2] = getNode(
    nodes,
    port_locations[1].x_m,
    port_locations[1].y_m,
    1e-12,
  );
  switch (dir) {
    case Direction.Up: {
      nodes[port1] = { ...nodes[port1], up: [port2, netlist.length] };
      nodes[port2] = { ...nodes[port2], down: [port1, netlist.length] };
      break;
    }
    case Direction.Down: {
      nodes[port1] = { ...nodes[port1], down: [port2, netlist.length] };
      nodes[port2] = { ...nodes[port2], up: [port1, netlist.length] };
      break;
    }
    case Direction.Left: {
      nodes[port1] = { ...nodes[port1], left: [port2, netlist.length] };
      nodes[port2] = { ...nodes[port2], right: [port1, netlist.length] };
      break;
    }
    case Direction.Right: {
      nodes[port1] = { ...nodes[port1], right: [port2, netlist.length] };
      nodes[port2] = { ...nodes[port2], left: [port1, netlist.length] };
      break;
    }
  }
  return [
    [
      ...netlist,
      {
        part,
        port_nets: [port1, port2],
        source_event: source_event,
      },
    ],
    nodes,
  ];
}
