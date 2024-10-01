use std::fmt::Display;

use num::complex::ComplexFloat;

use crate::{options::NumberFormat, SnPFile};

impl Display for SnPFile {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        writeln!(f, "{}", self.options)?;
        for (i, freq) in self.freq.iter().enumerate() {
            write!(f, "{}", freq / Into::<f64>::into(self.options.freq_prefix))?;
            for param in &self.data {
                let x = param[i];
                let (x1, x2) = match self.options.number_format {
                    NumberFormat::DecibelAngle => (20.0 * x.abs().log10(), x.arg().to_degrees()),
                    NumberFormat::MagnitudeAngle => (x.abs(), x.arg().to_degrees()),
                    NumberFormat::RealImaginary => (x.re(), x.im()),
                };
                write!(f, " {} {}", x1, x2)?;
            }
            if let Some(comment) = &self.comments[i] {
                write!(f, " !{}", comment)?;
            }
            writeln!(f)?;
        }
        Ok(())
    }
}
