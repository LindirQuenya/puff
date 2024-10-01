use std::{
    env::args,
    fs::File,
    io::{BufReader, Write},
    path::PathBuf,
};

use touchstone::{options::NumberFormat, parser};

pub fn main() {
    let input_path = args().nth(1).expect("No input file path provided.");
    let output_path = args().nth(2).expect("No output file path provided.");
    let in_file = File::open(PathBuf::from(input_path)).expect("Unable to open input file.");
    let mut out_file =
        File::create(PathBuf::from(output_path)).expect("Unable to open output file.");
    let mut parsed_file =
        parser::parse_file(BufReader::new(in_file)).expect("File parsing failed.");
    parsed_file.options.number_format = NumberFormat::RealImaginary;
    write!(out_file, "{}", parsed_file).expect("Writing failed.");
}
