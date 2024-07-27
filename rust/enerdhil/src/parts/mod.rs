use lumped::LumpedProps;
use open::OpenProps;
use short::ShortProps;
use tee::TeeProps;
use tline::TLineProps;

pub mod lumped;
pub mod open;
pub mod short;
pub mod tee;
pub mod tline;

#[derive(Clone)]
pub enum Component {
    TLine(TLineProps),
    Open(OpenProps),
    Short(ShortProps),
    Tee(TeeProps),
    Lumped(LumpedProps),
}
