use num::complex::{Complex64, ComplexFloat};

use crate::sim::NPort;

#[derive(Clone, Copy)]
#[cfg_attr(debug_assertions, derive(Debug))]
pub struct LumpedProps {
    /// Resisitive impedance, Z0 units
    r_z: f64,
    /// Capacitive impedance (*j*z0/f), e.g. -3=>-j3z0/f
    c_z: f64,
    /// Inductive impedance (*j*z0*f), e.g. 3
    l_z: f64,
}

impl LumpedProps {
    pub fn new(r_z: f64, c_z: f64, l_z: f64) -> Self {
        LumpedProps { r_z, c_z, l_z }
    }
}

impl NPort<2> for LumpedProps {
    fn simulate(
        &self,
        freq: f64,
        _sim: &crate::sim::SimProps,
    ) -> [[num::complex::Complex64; 2]; 2] {
        let z = if freq.abs() == 0.0 && self.c_z.abs() == 0.0 {
            // To avoid a 0/0 NaN.
            Complex64::new(self.r_z, 0.0)
        } else {
            self.r_z + Complex64::i() * (self.c_z / freq + self.l_z * freq)
        };
        let mut s = [[Complex64::ZERO; 2]; 2];
        s[0][0] = (1. + 2. / z).recip();
        s[1][1] = s[0][0];
        s[0][1] = 1. - s[0][0];
        s[1][0] = s[0][1];
        s
    }
}
