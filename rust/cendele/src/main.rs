#![allow(non_snake_case)]

use dioxus::prelude::*;
use tracing::Level;

mod config;

fn main() {
    // Init logger
    dioxus_logger::init(Level::INFO).expect("failed to init logger");

    dioxus::launch(App);
}

#[component]
fn App() -> Element {
    // Build cool things ✌️

    rsx! {
        link { rel: "stylesheet", href: "main.css" }
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
                                    th { input {id: "part{i}"}}
                                }
                            }
                        }
                    }
                }
                config::ConfigWindow {
                    zd: "10",
                    fd: "10",
                    er: "10.2",
                    h: "1.27",
                    s: "12",
                    microstrip: true,
                    manhattan: false,
                }
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
