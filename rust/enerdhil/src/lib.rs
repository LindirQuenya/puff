use tline::TLineProps;

pub mod constraint;
pub mod sim;
pub mod tline;
pub(crate) mod util;

pub fn add(left: usize, right: usize) -> usize {
    left + right
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

pub enum Component {
    TLine(TLineProps),
}
