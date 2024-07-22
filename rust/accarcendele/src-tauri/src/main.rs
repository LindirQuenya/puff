// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

/// Various types that will be sent to/from TypeScript
mod tstypes;

use std::collections::HashMap;

use enerdhil::{
    constraint::{validate, Constraints},
    sim::{LengthCorrectable, SimProps, SimType},
    tline::TLineProps,
    Component, Dimensions,
};
use parking_lot::{Mutex, RwLock};
use tauri::{Emitter, Manager, State, Window};
use tstypes::{ConfigUpdate, TLine, TLineDimensionsMeters};

struct Config {
    sim: SimProps,
    constr: Constraints,
    manhattan: bool,
}

// Deadlock prevention: listed in acquisition order.
struct SimSettings(RwLock<Config>);
struct PartMap(Mutex<HashMap<char, Component>>);

#[tauri::command]
fn add_transmission_line(
    index: char,
    linedesc: TLine,
    parts: State<PartMap>,
    simstate: State<SimSettings>,
) -> Result<TLineDimensionsMeters, String> {
    let (line, dimensions) = {
        let sim = &simstate.0.read();
        let zed = linedesc.impedance.to_ohms(sim.sim.z0);
        let line = TLineProps::new(zed, linedesc.length.into(), false, &sim.sim)
            .map_err(|e| e.to_string())?;
        let corr = line.to_mm(&linedesc.correction.into(), &sim.sim);
        let mut dimensions = line.get_dimensions().to_owned();
        dimensions.p_len += corr;
        if sim.manhattan {
            dimensions.p_len = 0.1 * sim.constr.board_dim.0;
            dimensions.p_width = 0.05 * sim.constr.board_dim.0;
        } else {
            validate(&Dimensions::TLine(dimensions.clone()), &sim.constr)
                .map_err(|e| e.to_string())?;
        }
        (line, dimensions)
    };
    {
        let mut map = parts.0.lock();
        map.insert(index, Component::TLine(line));
    }
    Ok(dimensions.into())
}

#[tauri::command]
fn update_config(newconf: ConfigUpdate, simstate: State<SimSettings>, window: Window) {
    let mut conf = simstate.0.write();
    conf.sim.z0 = newconf.zd;
    conf.sim.design_freq = newconf.fd;
    conf.sim.epsilon_r = newconf.er;
    conf.sim.height = newconf.h * 1000.;
    (conf.sim.mode, conf.manhattan) = match newconf.mode {
        tstypes::SimType::Microstrip => (SimType::Microstrip, false),
        tstypes::SimType::MicrostripMH => (SimType::Microstrip, true),
        tstypes::SimType::Stripline => (SimType::Stripline, false),
        tstypes::SimType::StriplineMH => (SimType::Stripline, true),
    };
    conf.constr.board_dim = (newconf.s * 1000., newconf.s * 1000.);
    let _ = window.emit("config-update", ()).map_err(|e| eprintln!("{}", e.to_string()));
}

fn main() {
    let sim = SimProps {
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
    let config = Config {
        sim,
        constr: Constraints {
            circuit_resolution: 10e-3,
            board_dim: (12.0, 12.0),
        },
        manhattan: false,
    };
    tauri::Builder::default()
        .manage(PartMap(Mutex::new(HashMap::new())))
        .manage(SimSettings(RwLock::new(config)))
        .setup(|app| {
            #[cfg(debug_assertions)]
            app.get_webview_window("main").unwrap().open_devtools();
            Ok(())
        })
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            add_transmission_line,
            update_config
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
