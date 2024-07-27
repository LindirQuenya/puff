use num::complex::Complex64;

use crate::sim::OnePort;

#[derive(Clone)]
pub struct OpenProps;

impl OpenProps {
    pub fn new() -> Self {
        OpenProps {}
    }
}

impl OnePort for OpenProps {
    fn simulate(&self, _freq: f64, _sim: &crate::sim::SimProps) -> [[Complex64; 1]; 1] {
        [[Complex64::ONE; 1]; 1]
    }
}
