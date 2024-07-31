use num::complex::Complex64;

use crate::sim::NPort;

#[derive(Clone, Copy, Default)]
#[cfg_attr(debug_assertions, derive(Debug))]
pub struct MatchProps;

impl MatchProps {
    pub fn new() -> Self {
        MatchProps {}
    }
}

impl NPort<1> for MatchProps {
    fn simulate(&self, _freq: f64, _sim: &crate::sim::SimProps) -> [[Complex64; 1]; 1] {
        [[Complex64::ZERO; 1]; 1]
    }
}
