use parts::tline::TLineDimensions;

pub mod constraint;
pub mod netlist;
pub mod parts;
pub mod sfg;
pub mod sim;
pub(crate) mod util;

pub fn add(left: usize, right: usize) -> usize {
    left + right
}

pub enum Dimensions {
    TLine(TLineDimensions),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = add(2, 2);
        assert_eq!(result, 4);
    }
}
