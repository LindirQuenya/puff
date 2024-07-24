use std::collections::HashMap;

use crate::parts::Component;

pub struct NetlistElement {
	component: Component,
	nets: Vec<usize>,
}

pub fn parse_netlist(list: Vec<NetlistElement>, grounds: Vec<usize>) {
}