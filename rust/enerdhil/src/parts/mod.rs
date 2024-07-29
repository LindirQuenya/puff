use lumped::LumpedProps;
use num::complex::Complex64;
use open::OpenProps;
use short::ShortProps;
use tee::TeeProps;
use tline::TLineProps;

use crate::sim::NPort;

pub mod lumped;
pub mod open;
pub mod short;
pub mod tee;
pub mod tline;

// TODO: right now this cannot be extended with custom components by the user.
// We should allow them to define their own components and use them.
// Maybe this means dyn trait objects are necessary?
#[derive(Clone)]
pub enum Component {
    TLine(TLineProps),
    Open(OpenProps),
    Short(ShortProps),
    Tee(TeeProps),
    Lumped(LumpedProps),
}

impl Component {
    pub fn simulate(&self, freq: f64, sim: &crate::sim::SimProps) -> Vec<Vec<Complex64>> {
        match self {
            Component::TLine(t) => t
                .simulate(freq, sim)
                .into_iter()
                .map(|e| e.to_vec())
                .collect(),
            Component::Open(o) => o
                .simulate(freq, sim)
                .into_iter()
                .map(|e| e.to_vec())
                .collect(),
            Component::Short(s) => s
                .simulate(freq, sim)
                .into_iter()
                .map(|e| e.to_vec())
                .collect(),
            Component::Tee(t) => t
                .simulate(freq, sim)
                .into_iter()
                .map(|e| e.to_vec())
                .collect(),
            Component::Lumped(l) => l
                .simulate(freq, sim)
                .into_iter()
                .map(|e| e.to_vec())
                .collect(),
        }
    }
    pub fn get_port_num(&self) -> usize {
        match self {
            Component::TLine(t) => t.get_port_num(),
            Component::Open(o) => o.get_port_num(),
            Component::Short(s) => s.get_port_num(),
            Component::Tee(t) => t.get_port_num(),
            Component::Lumped(l) => l.get_port_num(),
        }
    }
}
