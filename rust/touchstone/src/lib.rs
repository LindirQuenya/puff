use std::{collections::BTreeMap, num::ParseFloatError};

use lazy_static::lazy_static;
use num::{complex::Complex64, integer::Roots};
use options::FormatOptions;
use ordered_float::OrderedFloat;
use regex::Regex;
use thiserror::Error;

pub mod options;
pub mod parser;
pub mod writer;

#[derive(Error, Debug)]
pub enum ParseSnPError {
    #[error("float parsing error")]
    ParseFloatError(#[from] ParseFloatError),
    #[error("malformed options line")]
    MalformedOptions,
    #[error("empty options line")]
    EmptyOptions,
    #[error("data lines before options line")]
    DataBeforeOptions,
    #[error("incomplete data column or incorrect number of ports")]
    IncompleteColumnOrWrongNports,
    #[error("empty file")]
    EmptyFile,
}

pub struct SnPFile {
    pub options: FormatOptions,
    pub params: Params,
}

struct DataEntry {
    freq: f64,
    data: Vec<Complex64>,
}

pub type Params = BTreeMap<OrderedFloat<f64>, Vec<Vec<Complex64>>>;

fn into_params(data: Vec<DataEntry>) -> Params {
    let mut params = Params::new();
    for pt in data {
        let nparams = pt.data.len().sqrt();
        let mut param_array: Vec<Vec<Complex64>> = vec![vec![Complex64::ZERO; nparams]; nparams];
        for i in 0..nparams.pow(2) {
            param_array[i / nparams][i % nparams] = pt.data[i];
        }
        // S21 and S12 are swapped for two-ports and only two-ports.
        if nparams == 2 {
            let temp = param_array[0][1];
            param_array[0][1] = param_array[1][0];
            param_array[1][0] = temp;
        }
        params.insert(pt.freq.into(), param_array);
    }
    params
}

/// Extracts the N from any string ending in "sNp".
pub fn file_extension_guess_nports(extension: &str) -> Option<usize> {
    lazy_static! {
        static ref RE_SNP: Regex = Regex::new(r"(?i)s(\d+)p$").expect("Regex failed to compile?");
    }
    RE_SNP
        .captures(extension)?
        .get(1)
        .and_then(|m| m.as_str().parse().ok())
}
