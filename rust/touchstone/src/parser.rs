use std::{io::BufRead, str::FromStr};

use num::{complex::Complex64, Integer};

use crate::{
    options::{FormatOptions, NumberFormat},
    DataEntry, ParseSnPError, SnPFile,
};

pub struct ParsedData {
    freq: f64,
    parsed_floats: Vec<f64>,
    comment: Option<String>,
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
        comment: parsed.comment,
    }
}

// TODO multi-line parsing for >2 port?
pub fn parse_data_line(line: &str) -> Result<Option<ParsedData>, ParseSnPError> {
    let mut commentsplit = line.trim().split('!');
    let mut datasplit = match commentsplit.next() {
        Some(c) => c.split_whitespace(),
        // Empty line.
        None => {
            return Ok(None);
        }
    };
    let comment = commentsplit.next().map(|s| s.to_owned());
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
        comment,
    }))
}

pub enum LineType {
    Blank,
    Comment(String),
    Options(FormatOptions),
    Data(ParsedData),
}

impl FromStr for LineType {
    type Err = ParseSnPError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
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
                Some('!') => Ok(Self::Comment(trimmed[1..].to_owned())),
                // The rest is data.
                _ => match parse_data_line(trimmed)? {
                    None => Ok(Self::Blank),
                    Some(d) => Ok(Self::Data(d)),
                },
            },
        }
    }
}

pub fn parse_file<T>(file: T) -> Result<SnPFile, ParseSnPError>
where
    T: BufRead,
{
    let mut options: Option<FormatOptions> = None;
    let mut comments: Vec<Option<String>> = Vec::new();
    let mut freq: Vec<f64> = Vec::new();
    let mut data: Vec<Vec<Complex64>> = Vec::new();

    for line in file.lines().map(|l| l.unwrap()) {
        match line.parse::<LineType>()? {
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
