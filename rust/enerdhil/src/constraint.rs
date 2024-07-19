#[cfg(feature = "serde")]
use serde::{Deserialize, Serialize};
use thiserror::Error;

use crate::{tline::TLineProps, Component};

#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct Constraints {
    /// Manufacturing resolution, in mm.
    pub circuit_resolution: f64,
    /// Board dimensions, to check fit. Orientation is arbitrary.
    pub board_dim: (f64, f64),
}

#[derive(Error, Debug)]
pub enum ValidationError {
    #[error("dimensions are below circuit resolution")]
    BelowCircuitResolution,
    #[error("dimensions are larger than the board")]
    AboveBoardDimensions,
}

pub fn validate(comp: &Component, constr: &Constraints) -> Result<(), ValidationError> {
    match comp {
        Component::TLine(line) => validate_tline(line, constr),
    }
}

fn validate_tline(line: &TLineProps, constr: &Constraints) -> Result<(), ValidationError> {
    let dim = line.get_dimensions();
    let min_dim = dim.p_len.min(dim.p_width);
    let max_dim = dim.p_len.max(dim.p_width);
    if min_dim < constr.circuit_resolution {
        return Err(ValidationError::BelowCircuitResolution);
    }
    let min_board_dim = constr.board_dim.0.min(constr.board_dim.1);
    let max_board_dim = constr.board_dim.0.max(constr.board_dim.1);
    if max_dim > max_board_dim || min_dim > min_board_dim {
        return Err(ValidationError::AboveBoardDimensions);
    }
    Ok(())
}
