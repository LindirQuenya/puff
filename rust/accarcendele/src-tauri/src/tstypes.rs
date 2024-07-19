use enerdhil::sim::LengthSpec;
use serde::{Deserialize, Serialize};
use serde_repr::{Deserialize_repr, Serialize_repr};

#[derive(Serialize_repr, Deserialize_repr, Clone, Copy)]
#[repr(u8)]
pub enum ImpedanceUnit {
    Ohms,
    Siemens,
    Z0,
    Y0,
}

#[derive(Serialize, Deserialize, Clone, Copy)]
pub struct Impedance {
    value: f64,
    units: ImpedanceUnit,
}

#[derive(Serialize_repr, Deserialize_repr, Clone, Copy)]
#[repr(u8)]
pub enum LengthUnit {
    Degrees,
    Meters,
    SubstrateHeights,
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
