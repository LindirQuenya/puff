import { emit } from "@tauri-apps/api/event";
import { draw_tline, move_half_tline, update_netlist_tline } from "./parts/tline";
import { CanvasProps, Direction, DrawFunc, DrawingUpdate, PartDimensions, PartsStr, PhysicalCoordinates, SelectionEvent } from "./types";

export function to_px(x_m: number, y_m: number, canvas: CanvasProps, width_px: number, height_px: number): [number, number] {
	return [x_m * width_px / canvas.width_m, 
		      y_m * height_px / canvas.height_m];
}

export type NetListElement = {
	part: keyof PartDimensions,
	// net node indexes
	port_nets: number[],
	// Index in layoutEvents
	source_event: number
};

export type PortConnection = {
	net_index: number,
	source_event: number
} | null;

export type NetNode = {
	// Indicies: [node index, netlist index]
	left: [number, number | null] | null,
	right: [number, number | null] | null,
	up: [number, number | null] | null,
	down: [number, number | null] | null,
	// Position
	x_m: number,
	y_m: number,
};

export function getNode(nodes: NetNode[], x_m: number, y_m: number, tolerance_m: number): [NetNode[], number] {
	let filtered = nodes.map((node, i) => [Math.abs(x_m - node.x_m) < tolerance_m && Math.abs(y_m - node.y_m) < tolerance_m, i])
	.filter(([withinTol, i]) => withinTol as boolean);
	if (filtered.length > 0) {
		return [nodes, filtered[0][1] as number];
	} else {
		const newNode: NetNode = {
			left: null,
			right: null,
			up: null,
			down: null,
			x_m,
			y_m
		};
		return [[...nodes, newNode], nodes.length];
	}
}

export type LayoutResults = {
  pos: PhysicalCoordinates, 
  netlist: NetListElement[],
  nodes: NetNode[],
  ports: PortConnection[], 
  updates: DrawFunc[],
	selectedPart: keyof PartDimensions
}

function invert_direction(dir: Direction): Direction {
	switch (dir) {
		case Direction.Up: return Direction.Down;
		case Direction.Down: return Direction.Up;
		case Direction.Right: return Direction.Left;
		case Direction.Left: return Direction.Right;
	}
}

function sorted_stringify(a: any): string {
	return JSON.stringify(a, Object.keys(a).sort());
}

export function optimize_event_list(events: LayoutEvent[]): LayoutEvent[] {
	// TODO combine opposite moves, remove any contradictory operations, e.g. moves that end up in the same place.
	const newEvents: LayoutEvent[] = [];
	for (const event of events) {
		if (newEvents.length > 0) {
			if (event.kind === 'selectPart' && newEvents[newEvents.length - 1].kind === 'selectPart') {
				newEvents[newEvents.length - 1] = event;
			} else if (event.kind === 'moveToPort' && newEvents[newEvents.length - 1].kind === 'moveToPort') {
				newEvents[newEvents.length - 1] = event;
			} else if (event.kind === 'moveHalfPlacement' && sorted_stringify(newEvents[newEvents.length - 1])===sorted_stringify({...event, dir: invert_direction(event.dir)})) {
				newEvents.pop();
			} else if (event.kind === 'moveNextNode' && sorted_stringify(newEvents[newEvents.length - 1])===sorted_stringify({...event, dir: invert_direction(event.dir)})) {
				newEvents.pop();
			} else {
				newEvents.push(event);
			}
		} else {
			newEvents.push(event);
		}
	}
	return newEvents;
}

function drawCursor(canvas: CanvasProps): DrawingUpdate {
	return {
		update: (ctx: CanvasRenderingContext2D, width_px: number, height_px: number) => {
			ctx.strokeStyle = 'white';
			ctx.beginPath();
			const cursor_radius = 5;
			const [x_px, y_px] = to_px(canvas.pos.x_m, canvas.pos.y_m, canvas, width_px, height_px);
			ctx.moveTo(Math.min(x_px + cursor_radius, width_px), y_px);
			ctx.lineTo(Math.max(x_px - cursor_radius, 0), y_px);
			ctx.moveTo(x_px, Math.min(y_px + cursor_radius, height_px));
			ctx.lineTo(x_px, Math.max(y_px - cursor_radius, 0));
			ctx.stroke();
		},
		new_pos: canvas.pos
	};
}

export type LayoutEvent = {
	kind: "selectPart",
	newPart: keyof PartDimensions
} | {
	kind: "layoutPart",
	part: keyof PartDimensions,
	dir: Direction
} | {
	kind: "moveNextNode",
	dir: Direction
} | {
	// TODO make this an arbitrary move, n∈Z, half-units. Would solve opt, loop problems neatly.
	kind: "moveHalfPlacement",
	part: keyof PartDimensions,
	dir: Direction
} | {
	kind: "moveToPort",
	port: number
} | {
	kind: "connectToPort",
	port: number
} | {
	kind: "placeGround"
} | {
	kind: "jumpNearestNode"
};

export function renderEvents(dims: PartDimensions, eventList: LayoutEvent[], canvas: CanvasProps): [LayoutResults, string | null] {
	let selectedPart = 'a' as keyof PartDimensions;

	let nodes: NetNode[] = [];
	let netlist: NetListElement[] = [];
	let drawing_updates: DrawFunc[] = [];
	let drawing_suffix: DrawFunc[] = [];
	const ports: PortConnection[] = [null, null, null, null];
	for (const [i, event] of eventList.entries()) {
		switch (event.kind) {
			case "selectPart": {
				// If the part is valid, change our selection. If it's invalid, ignore.
				// It's not a problem until they try to use the part somehow.
				if (dims[event.newPart]) {
					selectedPart = event.newPart;
				}
				break;
			}
			case "layoutPart": {
				const part = dims[event.part];
				if (part) {
					switch (part.kind) {
						case 't': {
							const returned = draw_tline(event.part, part.dim, canvas, event.dir);
							if (returned) {
								canvas.pos = returned[0].new_pos;
								drawing_updates.push(returned[0].update);
								[netlist, nodes] = update_netlist_tline(returned[1], netlist, nodes, event.dir, i, event.part);
							} else {
								return [{
									pos: canvas.pos, 
									netlist, 
									nodes, 
									ports,
									selectedPart,
									updates: drawing_updates
								}, "Part goes outside board!"];
							}
							break;
						}
						case 'd': {
							// TODO
							break;
						}
					}
				} else {
					return [{
						pos: canvas.pos, 
						netlist, 
						nodes, 
						ports, 
						selectedPart,
						updates: drawing_updates
					}, `Invalid part: ${event.part}`];
				}
				break;
			}
			case "connectToPort": {
				let currentNode = -1;
				// TODO tolerance
				[nodes, currentNode] = getNode(nodes, canvas.pos.x_m, canvas.pos.y_m, 1e-12);
				ports[event.port] = {
					net_index: currentNode,
					source_event: i
				};
				const x_m = canvas.pos.x_m, y_m = canvas.pos.y_m;
				drawing_suffix.push((ctx, width_px, height_px) => {
					const [x_px, y_px] = to_px(x_m, y_m, canvas, width_px, height_px);
					ctx.fillStyle = 'white';
					ctx.fillText(`${event.port + 1}`, x_px, y_px);
				});
				break;
			}
			case "moveHalfPlacement": {
				const part = dims[event.part];
				if (part) {
					switch (part.kind) {
						case 't': {
							const returned = move_half_tline(part.dim, canvas, event.dir);
							if (returned) {
								canvas.pos = returned;
							} else {
								return [{
									pos: canvas.pos, 
									netlist, 
									nodes, 
									ports,
									selectedPart,
									updates: drawing_updates
								}, "Move goes outside board!"];
							}
							break;
						}
						case 'd': {
							// TODO
							break;
						}
					}
				} else {
					return [{
						pos: canvas.pos, 
						netlist, 
						nodes, 
						ports, 
						selectedPart,
						updates: drawing_updates
					}, `Invalid part: ${event.part}`];
				}
				break;
			}
			case "moveNextNode": {
				let currentNode = -1;
				// TODO tolerance
				[nodes, currentNode] = getNode(nodes, canvas.pos.x_m, canvas.pos.y_m, 1e-12);
				const target_ind = getNodeDirection(nodes[currentNode], event.dir);
				if (target_ind != null) {
					const target_node = nodes[target_ind[0]];
					canvas.pos = {
						x_m: target_node.x_m, 
						y_m: target_node.y_m
					};
				}
				break;
			}
			// TODO all the rest. But this is all I need for a branchline, I think.
		}
	}
	const returned = drawCursor(canvas);
	drawing_updates.push(returned.update);
	canvas.pos = returned.new_pos;
	return [{
		pos: canvas.pos, 
		netlist, 
		nodes, 
		ports, 
		selectedPart,
		updates: [...drawing_updates, ...drawing_suffix]
	}, null];
}

export function processKeyPress(e: React.KeyboardEvent, eventList: LayoutEvent[], dims: PartDimensions, layout: LayoutResults): LayoutEvent[] | null {
	if (e.key.toLowerCase().match(/^[a-r]$|[1-4]|^arrow/) != null) {
		console.log(`down: ${e.key} shift=${e.shiftKey} ctrl=${e.ctrlKey}`);
		e.preventDefault();
		if (e.key.substring(0, 5) === "Arrow") {
			let dir = Direction.Up;
			switch (e.key.substring(5)) {
				case "Up": dir = Direction.Up; break;
				case "Down": dir = Direction.Down; break;
				case "Left": dir = Direction.Left; break;
				case "Right": dir = Direction.Right; break;
			}
			return processArrow(dir, eventList, e.shiftKey, layout);
		} else if (e.key.match(/^[1-4]$/) != null) {
			console.log('Layout: connect to port '+ e.key);
			const port = parseInt(e.key) - 1;
			// If it's not already connected, connect.
			if (layout.ports[port] === null) {
				return [...eventList, {
					kind: 'connectToPort',
					port: port
				}];
			} else {
				const [extraNodes, currentNode] = getNode(layout.nodes, layout.pos.x_m, layout.pos.y_m, 1e-12);
				// If it's already connected and we're at that node, remove the connection.
				if (layout.ports[port].net_index === currentNode) {
					const target_ind = layout.ports[port].source_event;
					return eventList.filter((_v, i) => i !== target_ind);
				} else {
					// otherwise, yell at the user.
					console.error("Port is already joined: "+e.key);
					return null;
				}
			}
			
		}	else if (e.ctrlKey && e.key.toLowerCase() === 'e') {
			// Clear the event list.
			console.log('Layout: clearing');
			emit('part-selection', {selection: dims['a'] !== undefined ? 'a' as keyof PartsStr : undefined} as SelectionEvent);
			return [];
		} else if (e.key.toLowerCase().match(/^[a-r]$/) != null && dims[e.key.toLowerCase() as keyof PartDimensions] !== undefined) {
			console.log(`selected: ${e.key}`);
			if (e.key.toLowerCase() !== layout.selectedPart) {
				emit('part-selection', {selection: e.key.toLowerCase() as keyof PartsStr} as SelectionEvent);
				return [...eventList, {
					kind: 'selectPart',
					newPart: e.key.toLowerCase() as keyof PartDimensions
				}];
			}
		}
	}
	return null;
}

function getNodeDirection(node: NetNode, dir: Direction): [number, number | null] | null {
	switch (dir) {
		case Direction.Up: return node.up;
		case Direction.Down: return node.down;
		case Direction.Left: return node.left;
		case Direction.Right: return node.right;
	}
}

function processArrow(dir: Direction, eventList: LayoutEvent[], shiftHeld: boolean, layout: LayoutResults): null | LayoutEvent[] {
	// Get current node, if it exists.
	const [newnodes, index] = getNode(layout.nodes, layout.pos.x_m, layout.pos.y_m, 1e-12);
	// Whatever it is. If it's created, so be it. It'll give the right answer for our purposes.
	// All we care about is if there is another node next to it or a part connecting.
	const node = newnodes[index];
	const node_dir = getNodeDirection(node, dir);
	if (shiftHeld) {
		// Either a move-half or a delete.
		// Check: is there a part connecting in the direction?
		if (node_dir !== null && node_dir[1] !== null) {
			// It's a delete. If this was the last event, delete it outright. If it wasn't,
			// replace the event that created the part with two move-half events.
			const target_event_ind = layout.netlist[node_dir[1]].source_event;
			const target_event = eventList[target_event_ind];
			if (target_event.kind !== 'layoutPart') {
				return null;
			}
			// If last, delete outright.
			if (target_event_ind === eventList.length - 1) {
				return eventList.filter((_v, i) => i !== target_event_ind);
			}
			// Otherwise, replace with moves.
			const half_move: LayoutEvent = {
				kind: "moveHalfPlacement",
				dir: target_event.dir,
				part: target_event.part
			};
			return eventList.flatMap((val, i) => {
				if (i === target_event_ind) {
					return [{...half_move}, {...half_move}];
				} else {
					return val;
				}
			});
		} else {
			// half move.
			return [...eventList, {
				kind: 'moveHalfPlacement',
				part: layout.selectedPart,
				dir
			}];
		}
	} else {
		if (node_dir === null) {
			const newEvent: LayoutEvent = {
				kind: "layoutPart",
				part: layout.selectedPart,
				dir
			};
			return [...eventList, newEvent];
		} else {
			// There is a node above us. Move there.
			const newEvent: LayoutEvent = {
				kind: "moveNextNode",
				dir
			};
			return [...eventList, newEvent];
		}
	}
	return null;
}