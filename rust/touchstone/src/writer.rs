use std::fmt::Display;

use num::{complex::ComplexFloat, integer::Roots};

use crate::{options::NumberFormat, SnPFile};

impl Display for SnPFile {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        writeln!(f, "{}", self.options)?;
        for (freq, params) in self.params.iter() {
            write!(f, "{}", freq / Into::<f64>::into(self.options.freq_prefix))?;
            let nparams = params.len().sqrt();
            let order = if nparams == 2 {
                // 2-port columns are out of order.
                vec![0, 2, 1, 3]
            } else {
                (0..nparams.pow(2)).collect()
            };
            let mut counter = 0;
            for (row, col) in order.into_iter().map(|n| (n / nparams, n % nparams)) {
                if counter == 4 {
                    counter = 0;
                    writeln!(f)?;
                }
                let x = params[row][col];
                let (x1, x2) = match self.options.number_format {
                    NumberFormat::DecibelAngle => (20.0 * x.abs().log10(), x.arg().to_degrees()),
                    NumberFormat::MagnitudeAngle => (x.abs(), x.arg().to_degrees()),
                    NumberFormat::RealImaginary => (x.re(), x.im()),
                };
                write!(f, " {} {}", x1, x2)?;
                counter += 1;
            }
            writeln!(f)?;
        }
        Ok(())
    }
}
