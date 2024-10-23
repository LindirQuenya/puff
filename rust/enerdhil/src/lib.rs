#![feature(btree_cursors)]
use parts::tline::TLineDimensions;

pub mod constraint;
pub mod netlist;
pub mod parts;
pub mod sfg;
pub mod sim;
pub(crate) mod util;

pub enum Dimensions {
    TLine(TLineDimensions),
}
