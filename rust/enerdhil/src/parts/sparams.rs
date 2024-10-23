use std::{collections::BTreeMap, ops::Bound};

use itertools::Itertools;
use num::complex::Complex64;
use ordered_float::OrderedFloat;

#[derive(Clone, Default)]
#[cfg_attr(debug_assertions, derive(Debug))]
pub struct SparamDevice {
	params: BTreeMap<OrderedFloat<f64>, Vec<Vec<Complex64>>>,
    nports: usize,
}

impl SparamDevice {
    pub fn new(params: BTreeMap<OrderedFloat<f64>, Vec<Vec<Complex64>>>) -> Self {
        let nports = params.first_key_value().map_or_else(|| 0, |kv| {
            kv.1.len()
        });
        SparamDevice { params, nports}
    }

    pub fn get_port_num(&self) -> usize {
        return self.nports;
    }

    pub fn simulate(&self, freq: f64, _sim: &crate::sim::SimProps) -> Vec<Vec<Complex64>> {
        let n = self.get_port_num();
        let zeros = vec![vec![Complex64::ZERO; n]; n];

		let cursor = self.params.upper_bound(Bound::Included(&OrderedFloat(freq)));
        // If we're out of range, return all zeros.
        let before = match cursor.peek_prev() {
            Some(s) => s,
            None => {return zeros;}
        };
        let after = match cursor.peek_next() {
            Some(s) => s,
            None => {return zeros;}
        };

        before.1.iter().zip(after.1.iter()).map(|columns|
            columns.0.iter().zip(columns.1.iter()).map(|pair| 
                // Linear interpolation
                pair.0+(freq-**before.0)*(pair.1-pair.0)/ *(*after.0-*before.0)
            ).collect_vec()
        ).collect_vec()
    }
}