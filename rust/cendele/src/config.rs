use std::{borrow::Borrow, thread::Scope};

use dioxus::prelude::*;
use once_cell::sync::Lazy;
use regex::Regex;

static POS_FLOAT: Lazy<Regex> = Lazy::new(|| Regex::new(r"^(\+?(?:(?:\d+(?:\.\d*)?)|(?:\.\d+)))([fpnumkMGTP]?)$").unwrap());

#[derive(PartialEq, Clone, Props)]
pub struct ConfigProps {
	/// Port impedance
	zd: String,
	/// Design frequency
	fd: String,
	/// Dielectric relative permittivity
	er: String,
	/// Dielectric height
	h: String,
	/// Port spacing
	s: String,
	microstrip: bool,
	manhattan: bool,
}

fn on_key_down(e: Event<KeyboardData>) {
	match e.key() {
		Key::ArrowDown => {
			
		},
		Key::ArrowUp => {

		}
		_ => {}
	}
}

fn validate_pos_float_with_prefix(s: &str) -> bool {
	
	tracing::debug!(s);
	RE.is_match(s)
}

/// Only works for ids that don't have " in them. Please make your ids nice.
fn finish_validation(id: &str, success: bool) {
	eval(&r#"finishValidation("myid", bool)"#.replace("bool", &success.to_string()).replace("myid", id));
}


pub fn ConfigWindow() -> Element {
	let mut props = use_signal(|| ConfigProps {zd: "10".to_string(),
	fd: "10".to_string(),
	er: "10.2".to_string(),
	h: "1.27".to_string(),
	s: "12".to_string(),
	microstrip: true,
	manhattan: false});

	rsx! {
		div { id: "config", class: "textelem row",
            table { onkeydown: on_key_down, 
				class: "configtable", tbody {
				tr {
					th { "zd" }
					th { input {id: "zd", class: "configin", value: "{props().zd}" } }
					td {class: "configunit", a { "Ω" } }
				}
				tr {
					th { "fd" }
					th { input {id: "fd", class: "configin", value: "{props().fd}", onblur: |e| {
						tracing::debug!("{e:?}");
						let validation = finish_validation("fd",false);
					}} }
					td {class: "configunit", a { "Hz" } }
				}
			}}
        }
	}
}
