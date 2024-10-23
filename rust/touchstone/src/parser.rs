use std::{io::BufRead, str::FromStr};

use num::{complex::Complex64, Integer};

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

fn to_chunks(line: &str) -> impl IntoIterator {
    
}

// TODO multi-line parsing for >2 port?
pub fn parse_data_line(line: &str, nports: usize) -> Result<Option<ParsedData>, ParseSnPError> {
    if nports > 2 {
        todo!("Support multi-line parsing");
    }
    let mut commentsplit = line.trim().split('!');
    let mut datasplit = match commentsplit.next() {
        Some(c) => c.split_whitespace(),
        // Empty line.
        None => {
            return Ok(None);
        }
    };
    let freq = match datasplit.next() {
        Some(f) => f64::from_str(f)?,
        None => {
            // Comment line that wasn't caught by a previous filter? Ignore.
            return Ok(None);
        }
    };
    let parsed_floats: Vec<f64> = datasplit
        .map(|elem| elem.parse())
        .collect::<Result<Vec<_>, _>>()?;
    if !parsed_floats.len().is_even() {
        return Err(ParseSnPError::OddDataColumns);
    }
    Ok(Some(ParsedData {
        freq,
        parsed_floats,
    }))
}

pub enum LineType {
    Blank,
    Options(FormatOptions),
    Data(ParsedData),
}

impl LineType {
    fn from_str(s: &str, rest: &mut impl BufRead, nports: usize) -> Result<Self, ParseSnPError> {
        let trimmed = s.trim();
        match trimmed.chars().nth(1) {
            // If it has only one non-space character, I'll consider it blank.
            None => Ok(Self::Blank),
            // Otherwise, let's check the starting character.
            Some(_) => match trimmed.chars().nth(0) {
                None => Ok(Self::Blank),
                // Option lines start with '#'
                Some('#') => Ok(Self::Options(trimmed.parse()?)),
                // And comments start with '!'
                Some('!') => Ok(Self::Blank),
                // The rest is data.
                _ => match parse_data_line(trimmed, rest, nports)? {
                    None => Ok(Self::Blank),
                    Some(d) => Ok(Self::Data(d)),
                },
            },
        }
    }
}

pub fn parse_file<T>(mut file: impl BufRead, nports: usize) -> Result<SnPFile, ParseSnPError>
{
    let mut options: Option<FormatOptions> = None;
    let mut comments: Vec<Option<String>> = Vec::new();
    let mut freq: Vec<f64> = Vec::new();
    let mut data: Vec<Vec<Complex64>> = Vec::new();
    let mut buf = String::new();

    while let Ok(n) = file.read_line(&mut buf) {
        if n == 0 {
            break;
        }
        match LineType::from_str(&buf, &mut file, nports)? {
            LineType::Options(opt) => {
                if options.is_none() {
                    options = Some(opt);
                }
            }
            LineType::Data(parsed) => {
                let interp = interpret(parsed, &options.ok_or(ParseSnPError::DataBeforeOptions)?);
                freq.push(interp.freq);
                comments.push(interp.comment);
                if data.is_empty() {
                    data = vec![Vec::new(); interp.data.len()];
                }
                if data.len() != interp.data.len() {
                    return Err(ParseSnPError::InconsistentNumParams);
                }
                for i in 0..interp.data.len() {
                    data[i].push(interp.data[i]);
                }
            }
            _ => {
                // Ignore.
            }
        }
    }
    Ok(SnPFile {
        options: options.ok_or(ParseSnPError::EmptyFile)?,
        freq,
        comments,
        data,
    })
}
