use std::io::BufRead;

use num::complex::Complex64;

use crate::{
    options::{FormatOptions, NumberFormat},
    DataEntry, ParseSnPError, SnPFile,
};

pub struct ParsedData {
    freq: f64,
    parsed_floats: Vec<f64>,
}

pub fn interpret(parsed: ParsedData, options: &FormatOptions) -> DataEntry {
    let data: Vec<Complex64> = parsed
        .parsed_floats
        .chunks_exact(2)
        .map(|pair| match options.number_format {
            NumberFormat::RealImaginary => Complex64::new(pair[0], pair[1]),
            NumberFormat::MagnitudeAngle => Complex64::from_polar(pair[0], pair[1].to_radians()),
            NumberFormat::DecibelAngle => {
                Complex64::from_polar(10f64.powf(pair[0] / 20.0), pair[1].to_radians())
            }
        })
        .collect();
    DataEntry {
        freq: parsed.freq * Into::<f64>::into(options.freq_prefix),
        data,
    }
}

enum ChunkType {
    Options(FormatOptions),
    Data(f64),
}

fn to_chunks(line: &str) -> Result<Vec<ChunkType>, ParseSnPError> {
    let trimmed = line.trim();
    match trimmed.chars().nth(1) {
        // If it has only one non-space character, I'll consider it blank.
        None => Ok(Vec::new()),
        // Otherwise, let's check the starting character.
        Some(_) => match trimmed.chars().next() {
            None => Ok(Vec::new()),
            // Option lines start with '#'
            Some('#') => Ok(vec![ChunkType::Options(trimmed.parse()?)]),
            // And comments start with '!'
            Some('!') => Ok(Vec::new()),
            // The rest is data.
            _ => chunk_data_line(trimmed),
        },
    }
}

fn chunk_data_line(line: &str) -> Result<Vec<ChunkType>, ParseSnPError> {
    let mut commentsplit = line.trim().split('!');
    let datasplit = match commentsplit.next() {
        Some(c) => c.split_whitespace(),
        // Empty line.
        None => {
            return Ok(Vec::new());
        }
    };
    let floats: Result<Vec<_>, _> = datasplit
        .map(|elem| elem.parse::<f64>().map(ChunkType::Data))
        .collect();
    Ok(floats?)
}

pub fn parse_file(file: impl BufRead, nports: usize) -> Result<SnPFile, ParseSnPError> {
    let mut options: Option<FormatOptions> = None;
    let mut freq: Vec<f64> = Vec::new();
    let mut data: Vec<Vec<Complex64>> = Vec::new();
    let mut float_count = 0;
    let mut temp_freq = 0.0;
    let mut float_vec: Vec<f64> = vec![0.0; 2 * nports.pow(2)];
    for line_data in file
        .lines()
        .map(|line| to_chunks(&line.expect("Broken input stream?")))
    {
        for chunk in line_data? {
            match chunk {
                ChunkType::Options(opt) => {
                    if options.is_none() {
                        options = Some(opt);
                    }
                }
                ChunkType::Data(f) => {
                    if float_count == 0 {
                        temp_freq = f
                    } else {
                        float_vec[float_count - 1] = f;
                    }
                    float_count += 1;
                    if float_count == 2 * nports.pow(2) + 1 {
                        float_count = 0;
                        let entry = interpret(
                            ParsedData {
                                freq: temp_freq,
                                parsed_floats: float_vec.clone(),
                            },
                            &options.ok_or(ParseSnPError::DataBeforeOptions)?,
                        );
                        freq.push(entry.freq);

                        if data.is_empty() {
                            data = vec![Vec::new(); entry.data.len()];
                        }
                        if data.len() != entry.data.len() {
                            return Err(ParseSnPError::InconsistentNumParams);
                        }
                        for i in 0..entry.data.len() {
                            data[i].push(entry.data[i]);
                        }
                    }
                }
            }
        }
    }
    Ok(SnPFile {
        options: options.ok_or(ParseSnPError::EmptyFile)?,
        freq,
        data,
    })
}
