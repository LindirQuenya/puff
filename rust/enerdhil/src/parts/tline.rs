#[cfg(feature = "serde")]
use serde::{Deserialize, Serialize};
use std::f64::consts::{E, PI};
use thiserror::Error;

use num::complex::{Complex64, ComplexFloat};

use crate::sim::*;
use crate::util::{cohn_k, disperse_f, hammerstad_z, ms_alpha_c, ms_alpha_d};

#[derive(Clone, Copy)]
#[cfg_attr(debug_assertions, derive(Debug))]
pub struct TLineProps {
    zed: f64,
    /// In radians
    e_len: f64,
    /// Redundant with e_len, todo remove.
    wavelengths: f64,
    dim: TLineDimensions,
    super_line: bool,
    alpha_d: f64,
    alpha_c: f64,
    /// For super lines, f=0 (???)
    zed_e0: f64,
    zed_s_e0: f64,
    e_eff_e0: f64,
}

#[derive(Clone, Copy)]
#[cfg_attr(debug_assertions, derive(Debug))]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct TLineDimensions {
    /// In mm
    pub p_len: f64,
    /// In mm
    pub p_width: f64,
}

impl TLineProps {
    // TODO move the error possibility to constraints. Maybe add internal flag, and trip validation if true?
    pub fn new(zed: f64, len: LengthSpec, adv: bool, sim: &SimProps) -> Result<Self, TLineError> {
        let width = width_tline(zed, sim)?;
        let ere = match sim.mode {
            SimType::Microstrip => {
                (sim.epsilon_r + 1.0) / 2.0
                    + (sim.epsilon_r - 1.0) / 2.0 / (1.0 + 10.0 * sim.height / width).sqrt()
            }
            SimType::Stripline => sim.epsilon_r,
        };
        let (len_mm, wavelengths) = match len {
            LengthSpec::Degrees(deg) => (sim.lambda_fd_mm() * deg / 360. / ere.sqrt(), deg / 360.),
            LengthSpec::Millimeters(mm) => (mm, mm * ere.sqrt() / sim.lambda_fd_mm()),
            LengthSpec::SubstrateHeights(h) => (
                h * sim.height,
                h * sim.height * ere.sqrt() / sim.lambda_fd_mm(),
            ),
        };
        let mut line = TLineProps {
            zed,
            e_len: 2.0 * PI * wavelengths,
            wavelengths,
            dim: TLineDimensions {
                p_len: len_mm,
                p_width: width,
            },
            super_line: false,
            alpha_d: 0.0,
            alpha_c: 0.0,
            // unused by non-super routines.
            zed_e0: 0.0,
            zed_s_e0: 0.0,
            e_eff_e0: 0.0,
        };
        if adv {
            if width / sim.height < 0.0001 {
                return Err(TLineError::SuperTooThin);
            }
            match sim.mode {
                SimType::Stripline => line.super_stripline(sim),
                SimType::Microstrip => line.super_microstrip(sim),
            }
        }
        Ok(line)
    }

    /** Re-analyze microstrip parameters using the W/h
    derived from static calculation.
    Uses Hammerstad and Jensen (1980 MTT-S) models
    for Z0 and e_eff (see Itoh's IEEE book).

    Affects:  self.zed,  (new value from W/h)
        self.e_eff_e0   (e_eff value at f=0)
        self.alpha_c,  (value at fd)
        self.alpha_d   (value at fd)
        self.zed_e0,   (new f=0 value from W/h)
        self.wavelength  (new value from lngth0)
    */
    fn super_microstrip(&mut self, sim: &SimProps) {
        fn a(u: f64) -> f64 {
            1.0 + ((u.powi(4) + (u / 52.).powi(2)) / (u.powi(4) + 0.432)).ln() / 49.
                + (u / 18.1).powi(3).ln_1p() / 18.7
        }
        fn e_e(u: f64, b: f64, er: f64) -> f64 {
            (er + 1.0) / 2. + ((er - 1.0) / 2.) * (1.0 + 10. / u).powf(-a(u) * b)
        }
        let u_in = self.dim.p_width / sim.height;
        let b = 0.564 * ((sim.epsilon_r - 0.9) / (sim.epsilon_r + 3.0)).powf(0.053);
        let t_n = sim.metal_thickness / sim.height;
        let (mut delta_ul, mut delta_ur) = (0.0, 0.0);
        if t_n > 0.0 {
            delta_ul = (t_n / PI)
                * ((4. * E)
                    / (t_n
                        * ((6.517 * u_in).sqrt().cosh() / (6.517 * u_in).sqrt().sinh()).powi(2)))
                .ln_1p();
            delta_ur = 0.5 * (1.0 + 1.0 / (sim.epsilon_r - 1.0).sqrt().cosh()) * delta_ul;
        }
        let ul = u_in + delta_ul;
        let ur = u_in + delta_ur;
        let z0 = hammerstad_z(ur) / e_e(ur, b, sim.epsilon_r).sqrt();
        let e_eff = e_e(ur, b, sim.epsilon_r) * (hammerstad_z(ul) / hammerstad_z(ur)).powi(2);

        /*For ms_dispersion, compute value for zed_S_e0 from
        equivalent zero thickness stripline with b=2h.
        Double the value obtained from the formulas with b=2h.
        Use super_stripline formulas with t=0, b=2*h */
        let b_t_w = 2. / u_in;
        let a_fac = ((4. * b_t_w / PI)
            * ((8. * b_t_w / PI) + ((8. * b_t_w / PI).powi(2) + 6.27).sqrt()))
        .ln_1p();
        let z0_t = 60. * a_fac / sim.epsilon_r.sqrt();

        self.alpha_c = ms_alpha_c(self.dim.p_width, z0, e_eff, sim);
        self.alpha_d = ms_alpha_d(e_eff, sim);
        self.zed = z0;
        self.zed_e0 = z0;
        self.zed_s_e0 = z0_t;
        self.e_eff_e0 = e_eff;
        self.wavelengths = self.dim.p_len * e_eff.sqrt() / sim.lambda_fd_mm();
        self.e_len = 2. * PI * self.wavelengths;
        self.super_line = true;
    }

    /** Re-analyze stripline parameters using W/h
    from static calculation, adding in the effects
    of finite strip thickness. Re-calculates Z0.
    Computes stripline alpha due to conductor loss.
    See Gupta, Garg, and Chadha pp 59-60.

    Affects:  self.zed,
          self.alpha_c,
          self.alpha_d */
    fn super_stripline(&mut self, sim: &SimProps) {
        if sim.metal_thickness > 0.0 {
            let w = self.dim.p_width;
            let b = sim.height;
            // Equation (3.41b)
            let x = sim.metal_thickness / b;
            // Calculation of Z_0 with finite thickness metal
            // (3.41b)
            let m = 2. / (1.0 + 2. * x / (3. * (1.0 - x)));
            // (3.41a)
            let delta_w_b_t = x
                * (1.0
                    - 0.5
                        * ((x / (2.0 - x)).powi(2) + (0.0796 * x / ((w / b) + 1.1 * x)).powf(m))
                            .ln())
                / (PI * (1.0 - x));
            // (3.40)
            let w_over_b_t = (w / (b - sim.metal_thickness)) + delta_w_b_t;
            let w_prime = (b - sim.metal_thickness) * w_over_b_t;
            let b_t_w = w_over_b_t.recip();
            // a_fac is different from the pascal by a factor of pi.
            // This is a chunk of (3.39), because it's reused in (3.48).
            let a_fac = ((4. * b_t_w / PI)
                * ((8. * b_t_w / PI) + ((8. * b_t_w / PI).powi(2) + 6.27).sqrt()))
            .ln_1p();
            // (3.39)
            let z0_t = 30. * a_fac / sim.epsilon_r.sqrt();
            // Calculation of alpha_c
            // (3.49)
            let q_fac = (1.0 + 6.27 * (PI * w_over_b_t / 8.).powi(2)).sqrt();
            // Note: this is missing a epsilon_r.sqrt() factor that cancels with a term in alpha_c (3.47).
            // (3.48)
            // TODO confirm the 0.303/q_fac.
            let partial_z_w = 30.0
                * (3.135 / q_fac
                    - (1. + q_fac - 0.303 / q_fac) * (8.0 / (PI * w_over_b_t)).powi(2))
                / (a_fac.exp() * w_prime);
            // (3.47)
            let log_term = 1. + 2. * w_over_b_t - (3. * x / (2. - x) + (x / (2. - x)).ln()) / PI;
            // TODO check that this really should be a minus.
            self.alpha_c = -sim.rs_at_fd() * partial_z_w * log_term / (120. * PI * z0_t);
        }
        self.super_line = true;
        self.alpha_d = PI * sim.epsilon_r.sqrt() * sim.loss_tangent / sim.lambda_fd_mm();
    }

    /** Calculate effective dielectric constant and Z
    as a function of frequency for microstrip.

    Input values from super_microstrip are:
        self.zed_e0   := advanced model for zed at f=0
        self.e_eff_e0 := new ere at f=0
        self.lngth0   := lngth in mm

    Requires W/h from static calculation, epsilon(0)
    from supermicrostrip calculation, and
    frequency normalized to board thickness.

    Uses M. Kirschning and R.H. Jansen ere model
    from Electronics Letters, vol. 18, pp. 272-273,
    March, 1982. See also H. Atwater and York
    and Compton papers.

    Uses Hammerstad and Jensen formula for frequency
    dependence of Z0. */
    fn zed_elen(&self, freq: f64, sim: &SimProps) -> (f64, f64) {
        if matches!(sim.mode, SimType::Stripline) || !self.super_line {
            return (self.zed, self.e_len);
        }
        // F4 = f*h in units of GHz-cm (freq normalized to board thickness)
        let f4 = sim.height * freq / 1e10;
        if f4 > 25.0 {
            // Unstable, substitute asymptotic values
            (
                self.zed_s_e0,
                2. * PI * self.dim.p_len * sim.epsilon_r.sqrt() / sim.lambda_fd_mm(),
            )
        } else if f4 > 0.0 {
            let u_in = self.dim.p_width / sim.height;
            let p1 = 0.27488 + (0.6315 + 0.525 / (1.0 + 0.157 * f4).powi(20)) * u_in
                - 0.065683 * (-8.7513 * u_in).exp();
            let p2 = 0.33622 * (1.0 - (-0.03442 * sim.epsilon_r).exp());
            let p3 = 0.0363 * (-4.6 * u_in).exp() * -(-1.0 * (f4 / 3.87).powf(4.97)).exp_m1();
            let p4 = 1.0 + 2.751 * (-1.0 * (sim.epsilon_r / 15.916).powi(8)).exp_m1();
            let p = p1 * p2 * ((0.1844 + p3 * p4) * 10. * f4).powf(1.5763);
            let ere_f = disperse_f(sim.epsilon_r, self.e_eff_e0, p);
            (
                disperse_f(self.zed_s_e0, self.zed_e0, p),
                2. * PI * self.dim.p_len * ere_f.sqrt() / sim.lambda_fd_mm(),
            )
        } else {
            (
                self.zed_e0,
                2. * PI * self.dim.p_len * self.e_eff_e0.sqrt() / sim.lambda_fd_mm(),
            )
        }
    }

    pub fn get_dimensions(&self) -> &TLineDimensions {
        &self.dim
    }
}

impl NPort<2> for TLineProps {
    fn simulate(&self, freq: f64, sim: &SimProps) -> [[Complex64; 2]; 2] {
        tline_sim(freq, self, sim)
    }
}

impl LengthCorrectable for TLineProps {
    fn to_mm(&self, len: &LengthSpec, sim: &SimProps) -> f64 {
        match len {
            LengthSpec::Millimeters(mm) => *mm,
            LengthSpec::SubstrateHeights(h) => h * sim.height,
            LengthSpec::Degrees(deg) => self.dim.p_len * deg / (180. * self.e_len / PI),
        }
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

fn tline_sim(freq: f64, line: &TLineProps, sim: &SimProps) -> [[Complex64; 2]; 2] {
    // Normalized frequency
    let gamma = freq / sim.design_freq;
    let (zed, e_len) = line.zed_elen(freq, sim);
    let beta_l = e_len * gamma;
    let alpha_tl = (line.alpha_d * gamma + rough_alpha(line.alpha_c, freq, sim) * gamma.sqrt())
        * line.dim.p_len;
    let exp = Complex64::new(alpha_tl, beta_l);
    // I'm 90% sure this is correct. TODO check by hand again.
    let sh = exp.sinh();
    let ch = exp.cosh();
    let zd = zed / sim.z0;
    // [[s11, s12], [s21, s22]]
    let mut s_params = [[Complex64::ZERO; 2]; 2];
    let rds = recip_finite(2.0 * zd * ch + (1.0 + zd.powi(2)) * sh);
    s_params[0][0] = (zd.powi(2) - 1.0) * sh * rds;
    s_params[1][1] = s_params[0][0]; // s22 = s11
    s_params[0][1] = 2.0 * zd * rds;
    s_params[1][0] = s_params[0][1]; // s21 = s12

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
///     (https://doi.org/10.1049/ree.1976.0058)
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
    #[error("line is too thin for complex (super) model")]
    SuperTooThin,
}

#[cfg(test)]
mod tests {
    use std::{collections::HashMap, fs::File};

    use super::*;
    use ordered_float::OrderedFloat;
    use serde_json;

    #[test]
    fn write_json_25ohm() {
        let min = 0.0;
        let max = 10.0E9;
        let n = 201;
        let step = (max - min) / (n - 1) as f64;
        let mut sparams: HashMap<OrderedFloat<f64>, [[Complex64; 2]; 2]> = HashMap::new();
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
            loss_tangent: 0.02,
            metal_thickness: 0.035,
        };
        let line = TLineProps::new(25.0, LengthSpec::Millimeters(12.0), false, &sim)
            .expect("Hard-coded tline should work.");
        for i in 0..n {
            let freq = i as f64 * step;
            sparams.insert(OrderedFloat(freq), line.simulate(freq, &sim));
        }
        let file =
            File::create("test/data/tline/25ohm.json").expect("Failed to open test data file.");
        serde_json::to_writer_pretty(file, &sparams).expect("Unable to serialize s-parameters.");
    }
    #[test]
    fn write_json_s25ohm() {
        let min = 0.0;
        let max = 10.0E9;
        let n = 201;
        let step = (max - min) / (n - 1) as f64;
        let mut sparams: HashMap<OrderedFloat<f64>, [[Complex64; 2]; 2]> = HashMap::new();
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
            loss_tangent: 0.02,
            metal_thickness: 0.035,
        };
        let line = TLineProps::new(25.0, LengthSpec::Millimeters(12.0), true, &sim)
            .expect("Hard-coded tline should work.");
        for i in 0..n {
            let freq = i as f64 * step;
            sparams.insert(OrderedFloat(freq), line.simulate(freq, &sim));
        }
        let file =
            File::create("test/data/tline/s25ohm.json").expect("Failed to open test data file.");
        serde_json::to_writer_pretty(file, &sparams).expect("Unable to serialize s-parameters.");
    }
}
