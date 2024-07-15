use std::{borrow::Borrow, fmt::Display, thread::Scope};

use dioxus::prelude::*;
use once_cell::sync::Lazy;
use regex::Regex;

static POS_FLOAT: Lazy<Regex> =
    Lazy::new(|| Regex::new(r"^(\+?(?:(?:\d+(?:\.\d*)?)|(?:\.\d+)))\s*([fpnumkMGTP]?)$").unwrap());

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
    /// Board size
    s: String,
    /// Port spacing
    c: String,
    mode: RenderMode,
}

#[derive(Clone, Copy, PartialEq)]
pub enum RenderMode {
    Microstrip,
    Stripline,
    MSManhattan,
    SLManhattan,
}

impl RenderMode {
    fn rotate(&self) -> Self {
        match *self {
            Self::Microstrip => Self::Stripline,
            Self::Stripline => Self::MSManhattan,
            Self::MSManhattan => Self::SLManhattan,
            Self::SLManhattan => Self::Microstrip,
        }
    }
}

impl Display for RenderMode {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match *self {
            Self::Microstrip => write!(f, "Microstrip"),
            Self::Stripline => write!(f, "Stripline"),
            Self::MSManhattan => write!(f, "MicrostripMH"),
            Self::SLManhattan => write!(f, "StriplineMH"),
        }
    }
}

/// Only works for ids that don't have " in them. Please make your ids nice.
fn finish_validation(id: &str, success: bool) {
    eval(&r#"finishValidation("myid", bool)"#.replace("bool", &success.to_string()).replace("myid", id));
}

pub fn ConfigWindow() -> Element {
    let mut props = use_signal(|| ConfigProps {
        zd: "50.000 ".to_string(),
        fd: "3.000G".to_string(),
        er: "10.200 ".to_string(),
        h: "1.270m".to_string(),
        s: "20.000m".to_string(),
        c: "16.000m".to_string(),

        mode: RenderMode::Microstrip,
    });

    rsx! {
		div { id: "config", class: "textelem row", onblur: |e| {
			tracing::debug!("{e:?}");
		},
			table {
				onkeydown: move |e| {
				    match e.key() {
				        Key::Tab => {
				            props.write().mode = props().mode.rotate();
				        }
				        _ => {}
				    }
				},
				class: "configtable",
				tbody {
					tr {
						th { "zd" }
						th {
							input {
								id: "zd",
								class: "configin",
								value: "{props().zd}",
								oninput: move |e| {
								    props.write().zd = e.data().value();
								},
								onblur: move |e| {
								    let valid = POS_FLOAT.is_match(&props().zd);
								    finish_validation("zd", valid);
									if !valid {
										e.stop_propagation();
									}
								}
							}
						}
						td { class: "configunit",
							a { "Ω" }
						}
					}
					tr {
						th { "fd" }
						th {
							input {
								id: "fd",
								class: "configin",
								value: "{props().fd}",
								oninput: move |e| {
								    props.write().fd = e.data().value();
								},
								onblur: move |e| {
								    let valid = POS_FLOAT.is_match(&props().fd);
								    finish_validation("fd", valid);
									if !valid {
										e.stop_propagation();
									}
								}
							}
						}
						td { class: "configunit",
							a { "Hz" }
						}
					}
					tr {
						th { "er" }
						th {
							input {
								id: "er",
								class: "configin",
								value: "{props().er}",
								oninput: move |e| {
								    props.write().er = e.data().value();
								},
								onblur: move |e| {
								    let valid = POS_FLOAT.is_match(&props().er);
								    finish_validation("er", valid);
									if !valid {
										e.stop_propagation();
									}
								}
							}
						}
						td { class: "configunit",
							a { "" }
						}
					}
					tr {
						th { "h" }
						th {
							input {
								id: "h",
								class: "configin",
								value: "{props().h}",
								oninput: move |e| {
								    props.write().h = e.data().value();
								},
								onblur: move |e| {
								    let valid = POS_FLOAT.is_match(&props().h);
								    finish_validation("h", valid);
									if !valid {
										e.stop_propagation();
									}
								}
							}
						}
						td { class: "configunit",
							a { "m" }
						}
					}
					tr {
						th { "s" }
						th {
							input {
								id: "s",
								class: "configin",
								value: "{props().s}",
								oninput: move |e| {
								    props.write().s = e.data().value();
								},
								onblur: move |e| {
								    let valid = POS_FLOAT.is_match(&props().s);
								    finish_validation("s", valid);
									if !valid {
										e.stop_propagation();
									}
								}
							}
						}
						td { class: "configunit",
							a { "m" }
						}
					}
					tr {
						th { "c" }
						th {
							input {
								id: "c",
								class: "configin",
								value: "{props().c}",
								oninput: move |e| {
								    props.write().c = e.data().value();
								},
								onblur: move |e| {
								    let valid = POS_FLOAT.is_match(&props().c);
								    finish_validation("c", valid);
									if !valid {
										e.stop_propagation();
									}
								}
							}
						}
						td { class: "configunit",
							a { "m" }
						}
					}
					tr {
						th { "Tab" }
						th {
							input {
								id: "mode",
								class: "configin",
								readonly: true,
								value: "{props().mode}"
							}
						}
						td { class: "configunit",
							a { "" }
						}
					}
				}
			}
		}
		script { r#type: "text/javascript",
			r##"{{let script=document.querySelector("#jslib");
			script.addEventListener("load", () => {{console.log();preventTabs(["zd", "fd", "er", "h", "s", "c"], "keydown")}});
		    }}"##
		}

    }
}
