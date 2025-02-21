import { PhysicalCoordinates } from "../types";
import { Render } from "./Render";

export type PixelCoordinates = {
	x_px: number;
	y_px: number;
};

export class CanvasRender implements Render {
	board_size: PhysicalCoordinates;
	canvas_size: PixelCoordinates;
	border: PixelCoordinates;
  ctx: CanvasRenderingContext2D;

	constructor(board_size: PhysicalCoordinates, canvas_size: PixelCoordinates, border: PixelCoordinates, ctx: CanvasRenderingContext2D) {
		this.board_size = board_size;
		this.canvas_size = canvas_size;
		this.border = border;
		this.ctx = ctx;
	}

	init() {
		// clear the canvas
		this.ctx.clearRect(0, 0, this.canvas_size.x_px, this.canvas_size.y_px);

		// Only if the border exists, draw border and port dots.
		if (this.hasborder()) {
			// draw the border of the drawable area.
			let topleft = this.pos_to_px({x_m: 0, y_m: 0});
			let dims = this.dim_to_px(this.board_size);
			this.ctx.strokeStyle = `rgb(0, 255, 255)`;
			// Draw just barely outside the drawable area, hence the -1, +2.
			this.ctx.strokeRect(topleft.x_px - 1, topleft.y_px - 1, dims.x_px + 2, dims.y_px + 2);
		}
	}

	hasborder(): boolean {
		return this.border.x_px != 0 || this.border.y_px != 0;
	}

	pos_to_px(pos: PhysicalCoordinates): PixelCoordinates {
		return {
			x_px: (pos.x_m * (this.canvas_size.x_px - 2 * this.border.x_px)) / this.board_size.x_m + this.border.x_px,
      y_px: (pos.y_m * (this.canvas_size.y_px - 2 * this.border.y_px)) / this.board_size.y_m + this.border.y_px
		};
	}

	dim_to_px(pos: PhysicalCoordinates): PixelCoordinates {
		return {
			x_px: (pos.x_m * (this.canvas_size.x_px - 2 * this.border.x_px)) / this.board_size.x_m,
      y_px: (pos.y_m * (this.canvas_size.y_px - 2 * this.border.y_px)) / this.board_size.y_m
		};
	}
	
	draw_box(pos: PhysicalCoordinates, dim: PhysicalCoordinates, fillStyle: string): void {
		const pos_px = this.pos_to_px(pos);
		const dim_px = this.dim_to_px(dim);

		this.ctx.fillStyle = fillStyle;
		this.ctx.fillRect(pos_px.x_px, pos_px.y_px, dim_px.x_px, dim_px.y_px);
	}

	preview_text(pos: PhysicalCoordinates, text: string, fillStyle: string): void {
		if (!this.hasborder()) {
			return;
		}
		const pos_px = this.pos_to_px(pos);

		this.ctx.font = "10px serif";
		this.ctx.fillStyle = fillStyle;
		this.ctx.fillText(text, pos_px.x_px, pos_px.y_px);
	}

	clamp(pos: PixelCoordinates): PixelCoordinates {
		return {
			x_px: Math.max(this.border.x_px, Math.min(this.canvas_size.x_px-this.border.x_px, pos.x_px)),
			y_px: Math.max(this.border.y_px, Math.min(this.canvas_size.y_px-this.border.y_px, pos.y_px))
		};
	}

	preview_cursor(pos: PhysicalCoordinates): void {
		if (!this.hasborder()) {
			return;
		}
		
		const cursor_radius = 5;
		const pos_px = this.pos_to_px(pos);

		this.ctx.strokeStyle = "white";
		this.ctx.beginPath();
		let coords = this.clamp({...pos_px, x_px: pos_px.x_px + cursor_radius});
		this.ctx.moveTo(coords.x_px, coords.y_px);
		coords = this.clamp({...pos_px, x_px: pos_px.x_px - cursor_radius});
		this.ctx.lineTo(coords.x_px, coords.y_px);
		coords = this.clamp({...pos_px, y_px: pos_px.y_px + cursor_radius});
		this.ctx.moveTo(coords.x_px, coords.y_px);
		coords = this.clamp({...pos_px, y_px: pos_px.y_px - cursor_radius});
		this.ctx.lineTo(coords.x_px, coords.y_px);
		this.ctx.stroke();
	}

	draw_ports(from: PhysicalCoordinates[], to: (PhysicalCoordinates | null)[], z0Width: number): void {
		const ports_px = from.map(this.pos_to_px);
		// Half the width of a Z0 line.
		const halfw = this.dim_to_px({x_m: z0Width, y_m: 0}).x_px;
		this.ctx.lineWidth = 1;
		this.ctx.strokeStyle = "white";
		this.ctx.fillStyle = "#808000";
		for (let p = 0; p < 4; p++) {
			if (to[p]) {
				const pos = this.pos_to_px(to[p]!);
				const port = ports_px[p];
				// The x-coordinates of the corners - upper and lower.
				const upperX = pos.x_px+halfw*Math.sign(pos.y_px-port.y_px)*Math.sign(pos.x_px-port.x_px);
				const lowerX = 2*pos.x_px-upperX;
				// Logic to make a pretty bend.
				if (port.y_px < pos.y_px && pos.y_px - port.y_px > halfw) {
				  this.ctx.lineTo(pos.x_px, port.y_px-halfw);
				  this.ctx.lineTo(upperX, port.y_px);
				} else {
				  this.ctx.lineTo(upperX, port.y_px-halfw);
				}
			  this.ctx.lineTo(upperX, pos.y_px);
			  this.ctx.lineTo(lowerX, pos.y_px);
				if (port.y_px > pos.y_px && port.y_px - pos.y_px > halfw) {
				  this.ctx.lineTo(lowerX, port.y_px);
				  this.ctx.lineTo(pos.x_px, port.y_px+halfw);
				} else {
				  this.ctx.lineTo(lowerX, port.y_px+halfw);
				}
			  this.ctx.lineTo(port.x_px, port.y_px+halfw);

				// Stroke if we're doing this for preview, or fill for export.
				if (this.hasborder()) {
					this.ctx.stroke();
				} else {
					this.ctx.fill();
				}
			}
		}
		if (this.hasborder()) {
			for (let p = 0; p < 4; p++) {
				this.ctx.font = "10px serif";
				if (to[p]) {
					this.ctx.fillStyle = "red";
				} else {
					this.ctx.fillStyle = "#808000";
				}
				const pos = ports_px[p];
				this.ctx.fillRect(pos.x_px - 2, pos.y_px - 2, 5, 5);
				this.ctx.fillText(`${p+1}`, pos.x_px - this.border.x_px*((1+p)%2-(p%2)/3), pos.y_px+5);
			}
		}
	}
}