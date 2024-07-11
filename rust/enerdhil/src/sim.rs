use std::f64::consts::PI;

use num::complex::Complex64;

pub trait TwoPort {
    fn simulate(&self, freq: f64, sim: &SimProps) -> [Complex64; 4];
}

pub enum SimType {
    Microstrip,
    Stripline,
}

pub trait LengthCorrectable {
    fn to_mm(&self, len: &LengthSpec, sim: &SimProps) -> f64;
}

pub enum LengthSpec {
    // TODO: maybe change to radians?
    Degrees(f64),
    Millimeters(f64),
    SubstrateHeights(f64),
}

pub struct SimProps {
    pub mode: SimType,
    /// Hertz
    pub design_freq: f64,
    /// Micrometers
    pub surface_roughness: f64,
    /// mhos/meter
    pub conductivity: f64,
    /// Maybe generalize to complex? Maybe later.
    pub z0: f64,
    /// TODO: global const for free-space parameters?
    pub mu0: f64,
    pub eps0: f64,
    /// Relative permittivity of board dielectric.
    pub epsilon_r: f64,
    /// Dielectric height, mm
    pub height: f64,
    /// e.g. 0.02 for FR4.
    pub loss_tangent: f64,
    /// millimeters
    pub metal_thickness: f64,
}

impl SimProps {
    /// The free-space wavelength in mm.
    pub fn lambda_fd_mm(&self) -> f64 {
        self.c_mm() / self.design_freq
    }
    /// The speed of light in mm/s.
    pub fn c_mm(&self) -> f64 {
        1000. / (self.mu0 * self.eps0).sqrt()
    }
    /// The sheet resistance of the metal at the design frequency.
    pub fn rs_at_fd(&self) -> f64 {
        (PI * self.design_freq * self.mu0 / self.conductivity).sqrt()
    }
}
