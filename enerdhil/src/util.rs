use std::f64::consts::PI;

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
