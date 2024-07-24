use tee::TeeProps;
use tline::TLineProps;

pub mod tline;
pub mod tee;

pub enum Component {
    TLine(TLineProps),
    Tee(TeeProps),
}