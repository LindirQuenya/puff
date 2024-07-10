use std::f64::consts::PI;

use crate::sim::SimProps;

/// Function used to calculate Cohn's "k" factor for stripline
/// width formulas.  See equation 3.6, page 13 of the Puff Manual.
///
/// This was named kkk in the original pascal source.
pub(crate) fn cohn_k(x: f64) -> f64 {
    if x > 1.0 {
        let expx = (PI * x).exp();
        (1.0 - ((expx - 2.0) / (expx + 2.0)).powi(4)).sqrt()
    } else {
        let expx = (PI / x).exp();
        ((expx - 2.0) / (expx + 2.0)).powi(2)
    }
}
///  Calculates Z_o of microstrip using
/// Hammerstad and Jensen model.
///
/// Used by super_microstrip and super_cl_microstrip
/// This value must be divided by sqrt(ere) before use.
pub(crate) fn hammerstad_z(u: f64) -> f64 {
    let f = 6.0 + (2. * PI - 6.0) * (-1.0 * (0.7528 * (30.666 / u).ln()).exp()).exp();
    60. * (f / u + (1.0 + (2. / u).powi(2)).sqrt()).ln()
}

/// Used to compute dielectric losses for
/// microstrip tlines and clines.
pub(crate) fn ms_alpha_d(ere_in: f64, sim: &SimProps) -> f64 {
    if sim.epsilon_r != 1.0 {
        PI * sim.epsilon_r * (ere_in - 1.0) / (ere_in.sqrt() * (sim.epsilon_r - 1.0))
            * sim.loss_tangent
            / sim.lambda_fd_mm()
    } else {
        PI * sim.epsilon_r.sqrt() * sim.loss_tangent / sim.lambda_fd_mm()
    }
}
/// Computes microstrip alpha due to conductor loss.
/// Uses effective width calculations, returns Np/mm.
/// See Gupta, Garg, and Bahl pp 91-92.
///
/// W_in is uncorrected (actual) width, Z_0_in is
/// previously calculated Z.
pub(crate) fn ms_alpha_c(w_in: f64, z0_in: f64, er_e: f64, sim: &SimProps) -> f64 {
    if sim.metal_thickness > 0.0 {
        // In the pascal source, there was a complicated if/else.
        // I think it simplifies down to this.
        // Ugh, I can't use cmp::min here. floating-point moment.
        let b_fac = sim.height.min(2. * PI * w_in);
        let we_over_h = (PI * w_in
            + 1.25 * sim.metal_thickness * (1.0 + (2. * b_fac / sim.metal_thickness).ln()))
            / (PI * sim.height);
        let a_fac = 1.0 + (1.0 + 1.25 * (2. * b_fac / sim.metal_thickness).ln() / PI) / we_over_h;
        // Previously a condition on w_over_h, changed for readability.
        let w_h_ratio = if w_in < sim.height {
            (32.0 - we_over_h.powi(2)) / (32.0 + we_over_h.powi(2)) / (2. * PI * z0_in)
        } else {
            // TODO: replace with exact versions of these constants?
            (0.667 * we_over_h / (we_over_h + 1.444) + we_over_h) * z0_in * er_e
                / (120. * PI).powi(2)
        };
        a_fac * w_h_ratio * sim.rs_at_fd() / sim.height
    } else {
        0.0
    }
}

pub(crate) fn disperse_f(er1: f64, er2: f64, f_eo: f64) -> f64 {
    er1 - (er1 - er2) / (1.0 + f_eo)
}
