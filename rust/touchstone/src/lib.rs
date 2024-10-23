use std::num::ParseFloatError;

use num::complex::Complex64;
use options::FormatOptions;
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
