use num::complex::Complex64;

pub trait TwoPort {
    fn simulate(&self, freq: f64, sim: &SimProps) -> [Complex64; 4];
}

pub enum SimType {
    Microstrip,
    Stripline,
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
}

impl SimProps {
    /// Gives the free-space wavelength in mm.
    pub fn lambda_fd_mm(&self) -> f64 {
        let a = ((self.mu0 * self.eps0).sqrt() * self.design_freq).recip() * 1000.0;
        a
    }
}