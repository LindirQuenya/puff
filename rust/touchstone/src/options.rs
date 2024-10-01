use std::{fmt::Display, str::FromStr};

use lazy_static::lazy_static;
use regex::Regex;

use crate::ParseSnPError;

#[derive(PartialEq, Clone, Copy, Debug)]
pub enum FrequencyScale {
    GigaHz,
    MegaHz,
    KiloHz,
    Hz,
}

#[derive(PartialEq, Clone, Copy, Debug)]
pub enum ParameterType {
    Scattering,
    Admittance,
    Impedance,
    HybridH,
    HybridG,
}

#[derive(PartialEq, Clone, Copy, Debug)]
pub enum NumberFormat {
    RealImaginary,
    MagnitudeAngle,
    /// 20log_10|magnitude|, angle.
    DecibelAngle,
}

impl Display for ParameterType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}",
            match self {
                Self::Scattering => "S",
                Self::Admittance => "Y",
                Self::Impedance => "Z",
                Self::HybridH => "H",
                Self::HybridG => "G",
            }
        )
    }
}

impl FromStr for ParameterType {
    type Err = ParseSnPError;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_uppercase().as_str() {
            "S" => Ok(Self::Scattering),
            "Y" => Ok(Self::Admittance),
            "Z" => Ok(Self::Impedance),
            "H" => Ok(Self::HybridH),
            "G" => Ok(Self::HybridG),
            _ => Err(ParseSnPError::MalformedOptions),
        }
    }
}

impl Display for NumberFormat {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}",
            match self {
                Self::RealImaginary => "RI",
                Self::MagnitudeAngle => "MA",
                Self::DecibelAngle => "DB",
            }
        )
    }
}

impl FromStr for NumberFormat {
    type Err = ParseSnPError;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_uppercase().as_str() {
            "RI" => Ok(Self::RealImaginary),
            "MA" => Ok(Self::MagnitudeAngle),
            "DB" => Ok(Self::DecibelAngle),
            _ => Err(ParseSnPError::MalformedOptions),
        }
    }
}

impl Display for FrequencyScale {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}",
            match self {
                Self::GigaHz => "GHz",
                Self::MegaHz => "MHz",
                Self::KiloHz => "kHz",
                Self::Hz => "Hz",
            }
        )
    }
}

impl FromStr for FrequencyScale {
    type Err = ParseSnPError;
    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_uppercase().as_str() {
            "GHZ" => Ok(Self::GigaHz),
            "MHZ" => Ok(Self::MegaHz),
            "KHZ" => Ok(Self::KiloHz),
            "HZ" => Ok(Self::Hz),
            _ => Err(ParseSnPError::MalformedOptions),
        }
    }
}

impl From<FrequencyScale> for f64 {
    fn from(val: FrequencyScale) -> Self {
        match val {
            FrequencyScale::GigaHz => 1e9,
            FrequencyScale::MegaHz => 1e6,
            FrequencyScale::KiloHz => 1e3,
            FrequencyScale::Hz => 1.0,
        }
    }
}

#[derive(PartialEq, Clone, Copy, Debug)]
pub struct FormatOptions {
    pub freq_prefix: FrequencyScale,
    pub parameter: ParameterType,
    pub number_format: NumberFormat,
    pub port_impedance: f64,
}

impl Default for FormatOptions {
    fn default() -> Self {
        Self {
            freq_prefix: FrequencyScale::GigaHz,
            parameter: ParameterType::Scattering,
            number_format: NumberFormat::MagnitudeAngle,
            port_impedance: 50.0,
        }
    }
}

impl FromStr for FormatOptions {
    type Err = ParseSnPError;
    fn from_str(line: &str) -> Result<Self, Self::Err> {
        lazy_static! {
            // TODO: it'd be really nice if we could use fancy-regex for the look-arounds.
            //static ref RE_WHITESPACE: Regex = Regex::new(r"(?i)\s+").expect("Regex failed to compile?");
            static ref RE_OPTION: Regex =
                Regex::new(r"(?i)(?:\s|#)(?:([kMG]?Hz)|([SYZHG])|(DB|MA|RI)|(?:R\s+([\d\.]+)))")
                    .expect("Regex failed to compile?");
        }
        let trimmed = line.trim();
        if trimmed.chars().nth(0).ok_or(ParseSnPError::EmptyOptions)? != '#'
            || trimmed.contains('\n')
        {
            return Err(ParseSnPError::MalformedOptions);
        }
        let mut options = Self::default();
        for cap in RE_OPTION.captures_iter(trimmed) {
            // My icky manual version of lookahead.
            let chunk = cap.get(0).unwrap();
            // Either we're at the end of the line, or there is whitespace after this option.
            if chunk.end() == trimmed.len()
                || trimmed[chunk.end()..]
                    .chars()
                    .nth(0)
                    .unwrap_or(' ')
                    .is_whitespace()
            {
                if let Some(m) = cap.get(1) {
                    options.freq_prefix = m.as_str().parse()?;
                } else if let Some(m) = cap.get(2) {
                    options.parameter = m.as_str().parse()?;
                } else if let Some(m) = cap.get(3) {
                    options.number_format = m.as_str().parse()?;
                } else if let Some(m) = cap.get(4) {
                    options.port_impedance = m.as_str().parse()?;
                }
            } else {
                // TODO maybe remove this, and just ignore bad chunks?
                // return Err(ParseSnPError::MalformedOptions);
            }
        }
        Ok(options)
    }
}

impl Display for FormatOptions {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "# {} {} {} R {}",
            self.freq_prefix, self.parameter, self.number_format, self.port_impedance
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_standard_options() {
        let expected = FormatOptions {
            freq_prefix: FrequencyScale::GigaHz,
            parameter: ParameterType::Scattering,
            number_format: NumberFormat::RealImaginary,
            port_impedance: 50.0,
        };
        let line = "# GHz S RI R 50\n";
        let parsed = FormatOptions::from_str(line).unwrap();
        assert_eq!(parsed, expected);
    }
    #[test]
    fn parse_lc_rearranged_options() {
        let expected = FormatOptions {
            freq_prefix: FrequencyScale::MegaHz,
            parameter: ParameterType::Impedance,
            number_format: NumberFormat::MagnitudeAngle,
            port_impedance: 12.5,
        };
        let line = "# ma r 12.5 z mhz \n";
        let parsed = FormatOptions::from_str(line).unwrap();
        assert_eq!(parsed, expected);
    }

    #[test]
    fn parse_no_hashtag() {
        let line = " ma r 12.5 z mhz \n";
        assert!(FormatOptions::from_str(line).is_err());
    }
}
