use std::num::ParseFloatError;

use lazy_static::lazy_static;
use num::complex::Complex64;
use options::FormatOptions;
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
    #[error("missing angle/imaginary; odd number of data columns")]
    OddDataColumns,
    #[error("data lines before options line")]
    DataBeforeOptions,
    #[error("inconsistent number of parameters")]
    InconsistentNumParams,
    #[error("empty file")]
    EmptyFile,
}

pub struct SnPFile {
    pub options: FormatOptions,
    pub freq: Vec<f64>,
    pub data: Vec<Vec<Complex64>>,
}

pub struct DataEntry {
    freq: f64,
    data: Vec<Complex64>,
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
