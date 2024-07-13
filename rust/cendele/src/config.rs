use dioxus::prelude::*;

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

pub fn ConfigWindow(props: ConfigProps) -> Element {
	rsx! {
		div { id: "config", class: "textelem row",
            table { onkeydown: on_key_down, 
				class: "configtable", tbody {
				tr {
					th { "zd" }
					th { input {id: "zd", class: "configin", "{props.zd}" } }
					td {class: "configunit", a { "Ω" } }
				}
				tr {
					th { "fd" }
					th { input {id: "fd", class: "configin", "{props.fd}" } }
					td {class: "configunit", a { "Hz" } }
				}
			}}
        }
	}
}
