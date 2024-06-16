use std::f64::consts::PI;

use num::{complex::{Complex64, ComplexFloat}, traits::ConstZero};

struct TLineProps {
    zed: f64,
    /// In radians
    e_len: f64,
    /// Redundant with e_len, todo remove.
    wavelengths: f64,
    /// In mm
    p_len: f64,
    art_corr: f64,
    dispersive: bool,
    alpha_d: f64,
    alpha_c: f64,
}

enum SimType {
    Microstrip,
    Stripline,
}

struct SimProps {
    mode: SimType,
    design_freq: f64,
    surface_roughness: f64,
    conductivity: f64,
    /// Maybe generalize to complex? Maybe later.
    z0: f64,
    /// TODO: global const?
    mu0: f64,

}

fn recip_finite(x: Complex64) -> Complex64 {
    if x.abs() != 0.0 {
        x.recip()
    } else {
        Complex64::ZERO
    }
}

fn tline_sim(freq: f64, line: TLineProps, sim: SimProps) {
    // Normalized frequency
    let gamma = freq / sim.design_freq;
    if line.dispersive {
        todo!("Dispersive tlines");
    }
    let beta_l = line.e_len*gamma;
    let alpha_tl = (line.alpha_d * gamma 
        + rough_alpha(line.alpha_c, freq, &sim)*gamma.sqrt())*line.p_len;
    let exp = Complex64::new(alpha_tl, beta_l);
    // I'm 90% sure this is correct. TODO check by hand again.
    let sh = exp.sinh();
    let ch = exp.cosh();
    let zd = line.zed / sim.z0;
    // s11, s12, s21, s22
    let s_params = [Complex64::ZERO; 4];
    let rds = recip_finite(2.0*zd*ch + (1.0+zd.powi(2))*sh);
    s_params[]
}

fn rough_alpha(alpha: f64, freq: f64, sim: &SimProps) -> f64 {
    if freq > 0.0 && sim.surface_roughness > 0.0 {
        let skin_depth = 1e6/(PI*freq*sim.mu0*sim.conductivity).sqrt();
        let angle_arg = 1.4*(sim.surface_roughness/skin_depth).powi(2);
        alpha * (1.0 + 2.0 * angle_arg.atan() / PI)
    } else {
        alpha
    }
}