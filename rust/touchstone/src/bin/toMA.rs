use std::{
    env::args,
    fs::File,
    io::{BufReader, Write},
    path::PathBuf,
};

use touchstone::{file_extension_guess_nports, options::NumberFormat, parser};

pub fn main() {
    let input_path = PathBuf::from(args().nth(1).expect("No input file path provided."));
    let output_path = PathBuf::from(args().nth(2).expect("No output file path provided."));
    let nports = match args()
        .nth(3)
        .map(|n| n.parse::<usize>().expect("Invalid number of ports"))
    {
        Some(n) => n,
        None => input_path
            .extension()
            .and_then(|ext| file_extension_guess_nports(ext.to_str()?))
            .expect("Cannot guess number of ports, please specify (argument 3)."),
    };
    let in_file = File::open(input_path).expect("Unable to open input file.");
    let mut out_file = File::create(output_path).expect("Unable to open output file.");
    let mut parsed_file =
        parser::parse_file(BufReader::new(in_file), nports).expect("File parsing failed.");
    parsed_file.options.number_format = NumberFormat::MagnitudeAngle;
    write!(out_file, "{}", parsed_file).expect("Writing failed.");
}
