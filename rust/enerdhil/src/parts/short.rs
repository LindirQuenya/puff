use num::complex::Complex64;

use crate::sim::OnePort;

#[derive(Clone)]
pub struct ShortProps;

impl ShortProps {
    pub fn new() -> Self {
        ShortProps {}
    }
}

impl OnePort for ShortProps {
    fn simulate(&self, _freq: f64, _sim: &crate::sim::SimProps) -> [[Complex64; 1]; 1] {
        [[-Complex64::ONE; 1]; 1]
    }
}
