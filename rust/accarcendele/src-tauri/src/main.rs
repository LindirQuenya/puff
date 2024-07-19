// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

/// Various types that will be sent to/from TypeScript
mod tstypes;

use std::collections::HashMap;

use enerdhil::{
    sim::{LengthCorrectable, SimProps, SimType},
    tline::{TLineDimensions, TLineError, TLineProps},
    Component,
};
use parking_lot::{Mutex, RwLock};
use tauri::State;
use tstypes::TLine;

// Deadlock prevention: listed in acquisition order.
struct SimSettings(RwLock<SimProps>);
struct PartMap(Mutex<HashMap<char, Component>>);

#[tauri::command]
fn add_transmission_line(
    index: char,
    linedesc: TLine,
    parts: State<PartMap>,
    simstate: State<SimSettings>,
) -> Result<TLineDimensions, String> {
    let (line, corr) = {
        let sim = simstate.0.read();
        let zed = linedesc.impedance.to_ohms(sim.z0);
        let line =
            TLineProps::new(zed, linedesc.length.into(), false, &sim).map_err(|e| e.to_string())?;
        let corr = line.to_mm(&linedesc.correction.into(), &sim);
        (line, corr)
    };
    let mut dimensions = line.get_dimensions().to_owned();
    dimensions.p_len += corr;
    {
        let mut map = parts.0.lock();
        map.insert(index, Component::TLine(line));
    }
    Ok(dimensions)
}

fn main() {
    let props = SimProps {
        mode: SimType::Microstrip,
        design_freq: 3e9,
        surface_roughness: 2.0,
        conductivity: 5.8e7,
        z0: 50.0,
        mu0: 1.25663706212e-6,
        eps0: 8.8541878128e-12,
        epsilon_r: 10.2,
        height: 1.27,
        loss_tangent: 0.02,
        metal_thickness: 0.035,
    };
    tauri::Builder::default()
        .manage(PartMap(Mutex::new(HashMap::new())))
        .manage(SimSettings(RwLock::new(props)))
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![add_transmission_line])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
