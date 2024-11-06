use std::path::PathBuf;

use enerdhil::{parts::tline::TLineDimensions, sim::LengthSpec};
use serde::{Deserialize, Serialize};
use serde_repr::{Deserialize_repr, Serialize_repr};

#[derive(Serialize_repr, Deserialize_repr, Clone, Copy)]
#[repr(u8)]
pub enum ImpedanceUnit {
    Ohms = 0,
    Siemens = 1,
    Z0 = 2,
    Y0 = 3,
}

#[derive(Serialize, Deserialize, Clone, Copy)]
pub struct Impedance {
    value: f64,
    units: ImpedanceUnit,
}

#[derive(Serialize_repr, Deserialize_repr, Clone, Copy)]
#[repr(u8)]
pub enum LengthUnit {
    Degrees = 0,
    Meters = 1,
    SubstrateHeights = 2,
}

#[derive(Serialize, Deserialize, Clone, Copy)]
pub struct Length {
    value: f64,
    units: LengthUnit,
}

#[derive(Serialize, Deserialize, Clone, Copy)]
pub struct TLine {
    pub impedance: Impedance,
    pub length: Length,
    pub correction: Length,
}

#[derive(Serialize, Deserialize, Clone, Copy)]
pub struct SparamDev {
    pub filename: PathBuf,
    pub nports: usize,
}

#[derive(Serialize, Deserialize, Clone, Copy)]
pub struct TLineDimensionsMeters {
    pub p_len: f64,
    pub p_width: f64,
}

pub struct TriangleDimensionsMeters {
    pub base: f64,
    pub height: f64,
    pub port_heights: Vec<f64>,
}

#[derive(Serialize_repr, Deserialize_repr, Clone, Copy)]
#[repr(u8)]
pub enum SimType {
    Microstrip = 0,
    Stripline = 1,
    MicrostripMH = 2,
    StriplineMH = 3,
}

#[derive(Serialize, Deserialize, Clone, Copy)]
pub struct ConfigUpdate {
    /// Ohms
    pub zd: f64,
    /// Hz
    pub fd: f64,
    /// Unitless
    pub er: f64,
    /// Meters
    pub h: f64,
    /// Meters
    pub s: f64,
    /// Meters, TODO: unused
    pub c: f64,
    pub mode: SimType,
}

impl Into<LengthSpec> for Length {
    fn into(self) -> LengthSpec {
        match self.units {
            LengthUnit::Degrees => LengthSpec::Degrees(self.value),
            LengthUnit::SubstrateHeights => LengthSpec::SubstrateHeights(self.value),
            LengthUnit::Meters => LengthSpec::Millimeters(self.value * 1000.),
        }
    }
}

impl Impedance {
    pub fn to_ohms(&self, z0: f64) -> f64 {
        match self.units {
            ImpedanceUnit::Ohms => self.value,
            ImpedanceUnit::Siemens => self.value.recip(),
            ImpedanceUnit::Z0 => self.value * z0,
            ImpedanceUnit::Y0 => self.value.recip() * z0,
        }
    }
}

impl Into<TLineDimensionsMeters> for TLineDimensions {
    fn into(self) -> TLineDimensionsMeters {
        TLineDimensionsMeters {
            p_len: self.p_len / 1000.,
            p_width: self.p_width / 1000.,
        }
    }
}
