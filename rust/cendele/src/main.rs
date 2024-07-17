#![allow(non_snake_case)]

use config::ParsedConfigProps;
use dioxus::prelude::*;
use tracing::Level;

mod config;

fn main() {
    // Init logger
    dioxus_logger::init(Level::DEBUG).expect("failed to init logger");

    dioxus::launch(App);
}

#[component]
fn App() -> Element {
    let context = use_context_provider(|| Signal::new(ParsedConfigProps {
        zd: 50.,
        fd: 3e9,
        er: 10.2,
        h: 1.27e-3,
        s: 20e-3,
        c: 16e-3,
        mode: config::RenderMode::Microstrip,
    }));

    rsx! {
        link { rel: "stylesheet", href: "main.css" }
        script { id: "jslib", src: "ui.js" }
        div { id: "mainrow", class: "row",
            div { id: "textcol", class: "column",
                div { id: "plotconfig", class: "textelem row",
                    a { "F2" }
                }
                div { id: "message", class: "textelem row",
                    a { "message" }
                }
                div { id: "parts", class: "textelem row",
                    table {
                        tbody {
                            for i in 'a'..='r' {
                                tr {
                                    th { "{i}" }
                                    th {
                                        input { id: "part{i}" }
                                    }
                                }
                            }
                        }
                    }
                }
                config::ConfigWindow {}
            }
            div { id: "graphcol", class: "column",
                div { id: "layoutsmithrow", class: "row",
                    div { id: "layout",
                        a { "layout" }
                    }
                    div { id: "smith",
                        a { "smith" }
                    }
                }
                div { id: "plot",
                    a { "plot" }
                }
            }
        }

    }
}
