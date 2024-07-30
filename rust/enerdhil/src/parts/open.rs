use num::complex::Complex64;

use crate::sim::NPort;

#[derive(Clone, Copy, Default)]
#[cfg_attr(debug_assertions, derive(Debug))]
pub struct OpenProps;

impl OpenProps {
    pub fn new() -> Self {
        OpenProps {}
    }
}

impl NPort<1> for OpenProps {
    fn simulate(&self, _freq: f64, _sim: &crate::sim::SimProps) -> [[Complex64; 1]; 1] {
        [[Complex64::ONE; 1]; 1]
    }
}
