import { PhysicalCoordinates } from "../types";

export interface Render {
  board_size: PhysicalCoordinates;
  init(): void;
  draw_box(
    pos: PhysicalCoordinates,
    dim: PhysicalCoordinates,
    fillStyle: string,
  ): void;
  draw_ports(
    from: PhysicalCoordinates[],
    to: (PhysicalCoordinates | null)[],
    z0Width: number,
  ): void;
  preview_text(pos: PhysicalCoordinates, text: string, fillStyle: string): void;
  preview_cursor(pos: PhysicalCoordinates): void;
}
