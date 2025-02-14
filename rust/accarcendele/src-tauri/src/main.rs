// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

/// Various types that will be sent to/from TypeScript
mod tstypes;

use std::{
    collections::{HashMap, HashSet},
    fs::File,
    io::BufReader,
};

use enerdhil::{
    constraint::{validate, Constraints},
    netlist::{netlist_to_connections, ComponentPort, NetlistElement},
    parts::{lumpedmatch::MatchProps, sparams::SparamDevice, tline::TLineProps, Component},
    sfg::SignalFlowGraph,
    sim::{LengthCorrectable, SimProps, SimType},
    Dimensions,
};
use parking_lot::{Mutex, RwLock};
use num::complex::Complex64;
use tauri::{Emitter, Manager, State, Window};
use tstypes::{
    ConfigUpdate, SparamDev, TLine, TLineDimensionsMeters, TSNetlistElement,
    TriangleDimensionsMeters,
};

struct Config {
    sim: SimProps,
    constr: Constraints,
    manhattan: bool,
}

// Deadlock prevention: listed in acquisition order.
struct SimSettings(RwLock<Config>);
struct PartMap(Mutex<HashMap<char, Component>>);
struct SFG(
    Mutex<
        Option<(
            SignalFlowGraph,
            Vec<NetlistElement>,
            Vec<Component>,
            Vec<Option<ComponentPort>>,
        )>,
    >,
);

#[tauri::command]
fn add_transmission_line(
    index: char,
    desc: TLine,
    parts: State<PartMap>,
    simstate: State<SimSettings>,
) -> Result<TLineDimensionsMeters, String> {
    let (line, dimensions) = {
        let sim = &simstate.0.read();
        let zed = desc.impedance.to_ohms(sim.sim.z0);
        let line =
            TLineProps::new(zed, desc.length.into(), false, &sim.sim).map_err(|e| e.to_string())?;
        let corr = line.to_mm(&desc.correction.into(), &sim.sim);
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
fn add_sparam_device(
    index: char,
    desc: SparamDev,
    parts: State<PartMap>,
    simstate: State<SimSettings>,
) -> Result<TriangleDimensionsMeters, String> {
    let f = match File::open(desc.filename) {
        Ok(f) => f,
        Err(e) => {
            return Err(e.to_string());
        }
    };
    let sparams = touchstone::parser::parse_file(BufReader::new(f), desc.nports)
        .map_err(|e| e.to_string())?;
    let device = SparamDevice::new(sparams.params);
    {
        let mut map = parts.0.lock();
        map.insert(index, Component::SParams(device));
    }
    let base = 0.05 * (desc.nports + 1) as f64 * simstate.0.read().constr.board_dim.0;
    let height = 3f64.sqrt() * base / 2.0;
    Ok(TriangleDimensionsMeters {
        base,
        height,
        port_heights: (0..desc.nports)
            .map(|n| (n as f64 + 1.0) * height / (desc.nports as f64 + 1.0))
            .collect(),
    })
}

#[tauri::command]
fn update_config(newconf: ConfigUpdate, simstate: State<SimSettings>, window: Window) {
    #[cfg(debug_assertions)]
    dbg!(newconf);

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
    let _ = window
        .emit("config-update", newconf)
        .map_err(|e| eprintln!("{}", e.to_string()));
}

#[tauri::command]
fn parse_layout(
    netlist: Vec<TSNetlistElement>,
    port_netlist_ind: Vec<Option<usize>>,
    grounds: Vec<usize>,
    sfg: State<SFG>,
    parts: State<PartMap>,
) -> Result<Vec<usize>, String> {
    //dbg!(&netlist);
    let mut processed_netlist: Vec<NetlistElement> = Vec::new();
    let parts_map = parts.0.lock();
    for elem in netlist {
        processed_netlist.push(NetlistElement {
            component: parts_map.get(&elem.part).ok_or("Invalid part?")?.clone(),
            port_nets: elem.port_nets.clone(),
        });
    }
    //dbg!(&processed_netlist);
    let (conn, virt_comp) =
        netlist_to_connections(&processed_netlist, &HashSet::from_iter(grounds));
    //dbg!(&conn);
    //dbg!(&virt_comp);
    let mut sfg_state = sfg.0.lock();
    let port_components = port_netlist_ind
        .into_iter()
        .map(|index_opt| {
            index_opt.map(|ind| ComponentPort {
                component_ind: ind,
                is_virtual: false,
                port_num: 0,
            })
        })
        .collect::<Vec<Option<ComponentPort>>>();
    //dbg!(&port_components);
    let avail_port_nums = port_components
        .iter()
        .enumerate()
        .filter_map(|(i, opt)| opt.and(Some(i)))
        .collect();
    *sfg_state = Some((
        SignalFlowGraph::new(&conn),
        processed_netlist,
        virt_comp,
        port_components,
    ));
    Ok(avail_port_nums)
}

#[tauri::command]
async fn frequency_sweep(freqs: Vec<f64>, s_to_from: Vec<[usize; 2]>, sfg: State<'_, SFG>, simstate: State<'_, SimSettings>) -> Result<Vec<Vec<Complex64>>,String> {
    let config = simstate.0.read();
    let mut sfgstate = sfg.0.lock();
    let mut sparams = vec![Vec::new(); s_to_from.len()];
    if sfgstate.is_none() || freqs.len() == 0 {
        return Ok(sparams);
    }
    let (graph, netlist, virt_comp, ports) = sfgstate.as_mut().unwrap();
    for [a, b] in &s_to_from {
        if ports[*a].is_none() || ports[*b].is_none() {
            return Err(format!("Bad port pair [{}, {}]", a, b));
        }
    }
    graph.populate(freqs[0], &netlist, &virt_comp, &config.sim);
    for f in freqs {
        graph.populate_components(f, &netlist, &config.sim);
        for (i, param) in s_to_from.iter().map(|[a, b]| graph.masons_rule(ports[*b].unwrap(), ports[*a].unwrap(), true)).enumerate() {
            sparams[i].push(param);
        }
    }
    Ok(sparams)
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
    let mut parts = HashMap::new();
    // Super secret internal elements, inaccessible to the user. 'z' is a matched termination.
    parts.insert('z', Component::Match(MatchProps::default()));
    tauri::Builder::default()
        .manage(PartMap(Mutex::new(parts)))
        .manage(SimSettings(RwLock::new(config)))
        .manage(SFG(Mutex::new(None)))
        .setup(|app| {
//            #[cfg(debug_assertions)]
//            app.get_webview_window("main").unwrap().open_devtools();
            Ok(())
        })
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            add_transmission_line,
            update_config,
            parse_layout,
            add_sparam_device,
            frequency_sweep
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
