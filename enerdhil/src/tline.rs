use std::f64::consts::PI;
use thiserror::Error;

use num::complex::{Complex64, ComplexFloat};

use crate::util::cohn_k;

pub struct TLineProps {
    zed: f64,
    /// In radians
    e_len: f64,
    /// Redundant with e_len, todo remove.
    wavelengths: f64,
    /// In mm
    p_len: f64,
    super_line: bool,
    alpha_d: f64,
    alpha_c: f64,
}

impl TLineProps {
    pub fn from_mm(zed: f64, len_mm: f64, sim: &SimProps) -> Result<Self, TLineError> {
        let width = width_tline(zed, sim)?;
        let ere = match sim.mode {
            SimType::Microstrip => {
                (sim.epsilon_r + 1.0) / 2.0
                    + (sim.epsilon_r - 1.0) / 2.0 / (1.0 + 10.0 * sim.height / width).sqrt()
            }
            SimType::Stripline => sim.epsilon_r,
        };
        let fs_wlen = sim.lambda_fd_mm();
        let wavelengths = len_mm * ere.sqrt() / fs_wlen;
        Ok(TLineProps {
            zed,
            e_len: 2.0 * PI * wavelengths,
            wavelengths,
            p_len: len_mm,
            super_line: false,
            alpha_d: 0.0,
            alpha_c: 0.0,
        })
    }
}

impl TwoPort for TLineProps {
    fn simulate(&self, freq: f64, sim: &SimProps) -> [Complex64; 4] {
        tline_sim(freq, self, sim)
    }
}

pub trait TwoPort {
    fn simulate(&self, freq: f64, sim: &SimProps) -> [Complex64; 4];
}

pub enum SimType {
    Microstrip,
    Stripline,
}

pub struct SimProps {
    mode: SimType,
    /// Hertz
    design_freq: f64,
    /// Micrometers
    surface_roughness: f64,
    /// mhos/meter
    conductivity: f64,
    /// Maybe generalize to complex? Maybe later.
    z0: f64,
    /// TODO: global const for free-space parameters?
    mu0: f64,
    eps0: f64,
    /// Relative permittivity of board dielectric.
    epsilon_r: f64,
    /// Dielectric height, mm
    height: f64,
}

impl SimProps {
    /// Gives the free-space wavelength in mm.
    fn lambda_fd_mm(&self) -> f64 {
        let a = ((self.mu0 * self.eps0).sqrt() * self.design_freq).recip() * 1000.0;
        a
    }
}

/// TODO check if this is really necessary.
fn recip_finite(x: Complex64) -> Complex64 {
    if x.abs() != 0.0 {
        x.recip()
    } else {
        Complex64::ZERO
    }
}

fn tline_sim(freq: f64, line: &TLineProps, sim: &SimProps) -> [Complex64; 4] {
    // Normalized frequency
    let gamma = freq / sim.design_freq;
    if line.super_line {
        todo!("Dispersive tlines");
    }
    let beta_l = line.e_len * gamma;
    let alpha_tl =
        (line.alpha_d * gamma + rough_alpha(line.alpha_c, freq, sim) * gamma.sqrt()) * line.p_len;
    let exp = Complex64::new(alpha_tl, beta_l);
    // I'm 90% sure this is correct. TODO check by hand again.
    let sh = exp.sinh();
    let ch = exp.cosh();
    let zd = line.zed / sim.z0;
    // s11, s12, s21, s22
    let mut s_params = [Complex64::ZERO; 4];
    let rds = recip_finite(2.0 * zd * ch + (1.0 + zd.powi(2)) * sh);
    s_params[0] = (zd.powi(2) - 1.0) * sh * rds;
    s_params[3] = s_params[0]; // s22 = s11
    s_params[1] = 2.0 * zd * rds;
    s_params[2] = s_params[1]; // s21 = s12

    // The pascal program included a long bit that seemed to turn the s-params into a linked list. I think I won't.
    s_params
}

fn rough_alpha(alpha: f64, freq: f64, sim: &SimProps) -> f64 {
    if freq > 0.0 && sim.surface_roughness > 0.0 {
        let skin_depth = 1e6 / (PI * freq * sim.mu0 * sim.conductivity).sqrt();
        let angle_arg = 1.4 * (sim.surface_roughness / skin_depth).powi(2);
        alpha * (1.0 + 2.0 * angle_arg.atan() / PI)
    } else {
        alpha
    }
}

/// Function for calculating width in mils of microstrip
/// and stripline transmission lines.  See Puff manual
/// pages 20-22 for details.
///
/// Microstrip models are from Owens:
///     Radio and Elect Eng, 46, pp 360-364, 1976.
/// Stripline models are from  Cohn:
///     MTT-3 pp19-126, March 1955.
/// See also Gupta, Garg, Chadha:
///     CAD of Microwave Circuits Artech House, 1981.
///
/// Originally named widtht().
fn width_tline(zed: f64, sim: &SimProps) -> Result<f64, TLineError> {
    // TODO: make your own error kind for high-Z error.
    match sim.mode {
        SimType::Stripline => {
            let x = zed * sim.epsilon_r.sqrt() / (30.0 * PI);
            if PI * x > 87.0 {
                Err(TLineError::ImpedanceTooHigh)
            } else {
                Ok(sim.height * 2.0 * cohn_k(x).atanh() / PI)
            }
        }
        SimType::Microstrip => {
            if zed > 44.0 - 2.0 * sim.epsilon_r {
                let er_p1_x2 = 2.0 * (sim.epsilon_r + 1.0);
                let hp = (zed / 120.0) * er_p1_x2.sqrt()
                    + (sim.epsilon_r - 1.0) * ((PI / 2.0).ln() + (4.0 / PI).ln() / sim.epsilon_r)
                        / er_p1_x2;
                if hp > 87.0 {
                    // e^87 = 6e+37
                    Err(TLineError::ImpedanceTooHigh)
                } else {
                    let exp_hp = hp.exp();
                    Ok(8.0 * sim.height / (exp_hp - 2.0 / exp_hp))
                }
            } else {
                let de = 60.0 * PI.powi(2) / (zed * sim.epsilon_r.sqrt());
                Ok(sim.height
                    * (2.0 / PI * ((de - 1.0) - (2.0 * de - 1.0).ln())
                        + (sim.epsilon_r - 1.0)
                            * ((de - 1.0).ln() + 0.293 - 0.517 / sim.epsilon_r)
                            / (PI * sim.epsilon_r)))
            }
        }
    }
}

#[derive(Error, Debug)]
pub enum TLineError {
    #[error("line impedance too high for numerical stability")]
    ImpedanceTooHigh,
}

#[cfg(test)]
mod tests {
    use std::fs::File;

    use super::*;
    use serde_json;

    #[test]
    fn write_json_data() {
        let min = 0.0;
        let max = 10.0E9;
        let n = 201;
        let step = (max - min) / (n-1) as f64;
        let mut sparams: Vec<[Complex64; 4]> = Vec::new();
        let sim = SimProps {
            mode: SimType::Microstrip,
            design_freq: 3e9,
            surface_roughness: 2.0,
            conductivity: 5.8e7,
            z0: 50.0,
            mu0: 1.25663706212e-6,
            eps0: 8.8541878128e-12,
            epsilon_r: 10.2,
            height: 1.27,
        };
        let line = TLineProps::from_mm(25.0, 12.0, &sim).expect("Hard-coded tline should work.");
        for i in 0..n {
            sparams.push(line.simulate(i as f64 * step, &sim));
        }
        let file = File::create("test/data/25ohm.json").expect("Failed to open test data file.");
        serde_json::to_writer_pretty(file, &sparams).expect("Unable to serialize s-parameters.");
    }
}
