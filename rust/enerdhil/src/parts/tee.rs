use num::complex::Complex64;

use crate::sim::NPort;

#[derive(Clone, Copy, Default)]
pub struct TeeProps;

impl TeeProps {
    pub fn new() -> Self {
        TeeProps {}
    }
}

impl NPort<3> for TeeProps {
    fn simulate(&self, _freq: f64, _sim: &crate::sim::SimProps) -> [[Complex64; 3]; 3] {
        let mut s = [[Complex64::new(2. / 3., 0.); 3]; 3];
        for i in 0..3 {
            s[i][i] = Complex64::new(-1. / 3., 0.);
        }
        s
    }
}
