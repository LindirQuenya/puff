use std::{
    collections::{HashMap, HashSet},
    slice::Iter,
};

use graph_cycles::Cycles;
use itertools::Itertools;
use num::complex::{Complex64, ComplexFloat};
use petgraph::{algo::all_simple_paths, graph::NodeIndex, Graph};

use crate::{
    netlist::{ComponentPort, NetlistElement},
    parts::Component,
    sim::SimProps,
};

#[derive(Clone)]
#[cfg_attr(debug_assertions, derive(Debug))]
pub struct SFGCycles {
    paths: Vec<Vec<NodeIndex>>,
    /// First element of each is the indices of the paths contained,
    /// second element is the nodes contained.
    orders: Vec<Vec<(HashSet<usize>, HashSet<NodeIndex>)>>,
}

#[derive(Clone)]
#[cfg_attr(debug_assertions, derive(Debug))]
pub struct SignalFlowGraph {
    graph: Graph<(), Complex64>,
    port_to_index: HashMap<ComponentPort, [NodeIndex; 2]>,
    cycles: Option<SFGCycles>,
    cycle_weights: Option<Vec<Vec<Complex64>>>,
    cycles_out_of_date: bool,
}

impl SignalFlowGraph {
    pub fn new(connections: &HashMap<usize, [ComponentPort; 2]>) -> Self {
        let mut graph =
            Graph::<(), Complex64>::with_capacity(connections.len(), 3 * connections.len());
        let mut port_to_index = HashMap::with_capacity(2 * connections.len());
        for pair in connections.values().into_iter() {
            let a_ind = graph.add_node(());
            let b_ind = graph.add_node(());
            port_to_index.insert(pair[0].clone(), [a_ind, b_ind]);
            port_to_index.insert(pair[1].clone(), [b_ind, a_ind]);
        }
        SignalFlowGraph {
            graph,
            port_to_index,
            cycles: None,
            cycle_weights: None,
            cycles_out_of_date: false,
        }
    }
    // TODO this method could be optimized to death: results could be cached, double lookups avoided, etc.
    fn populate_component(
        &mut self,
        ind: usize,
        is_virtual: bool,
        comp: &Component,
        freq: f64,
        sim: &SimProps,
    ) {
        let sparams = comp.simulate(freq, sim);
        let nports = comp.get_port_num();
        for i in 0..nports {
            for j in 0..nports {
                let a_i = ComponentPort {
                    component_ind: ind,
                    is_virtual,
                    port_num: i,
                };
                let b_j = ComponentPort {
                    component_ind: ind,
                    is_virtual,
                    port_num: j,
                };
                // TODO result this
                let a_idx = self.port_to_index.get(&a_i).unwrap()[0];
                let b_idx = self.port_to_index.get(&b_j).unwrap()[1];
                let existed = self.graph.find_edge(a_idx, b_idx).is_some();
                let edge_idx = self.graph.update_edge(a_idx, b_idx, sparams[i][j]);
                // new: remove zero edges
                if sparams[i][j].abs() == 0.0 {
                    self.graph.remove_edge(edge_idx);
                    if existed {
                        self.cycles_out_of_date = true;
                    }
                } else if !existed {
                    self.cycles_out_of_date = true;
                }
            }
        }
    }
    fn populate_virtual_inner(
        &mut self,
        freq: f64,
        virtual_components: &[Component],
        sim: &SimProps,
    ) {
        for (ind, comp) in virtual_components.iter().enumerate() {
            self.populate_component(ind, true, comp, freq, sim);
        }
    }
    pub fn populate_virtual(
        &mut self,
        freq: f64,
        virtual_components: &[Component],
        sim: &SimProps,
    ) {
        self.populate_virtual_inner(freq, virtual_components, sim);
        self.cache_cycles();
        self.cache_cycle_weights();
    }
    fn populate_components_inner(
        &mut self,
        freq: f64,
        components: &[NetlistElement],
        sim: &SimProps,
    ) {
        for (ind, comp) in components.iter().enumerate() {
            self.populate_component(ind, false, &comp.component, freq, sim);
        }
    }
    pub fn populate_components(
        &mut self,
        freq: f64,
        components: &[NetlistElement],
        sim: &SimProps,
    ) {
        self.populate_components_inner(freq, components, sim);
        self.cache_cycles();
        self.cache_cycle_weights();
    }
    pub fn populate(
        &mut self,
        freq: f64,
        components: &[NetlistElement],
        virtual_components: &[Component],
        sim: &SimProps,
    ) {
        self.populate_components_inner(freq, components, sim);
        self.populate_virtual_inner(freq, virtual_components, sim);
        self.cache_cycles();
        self.cache_cycle_weights();
    }
    pub fn calculate_cycles(&self) -> SFGCycles {
        let cycles = self.graph.cycles();
        let cycle_contents: Vec<HashSet<NodeIndex>> = cycles
            .iter()
            .map(|cycle| HashSet::from_iter(cycle.iter().cloned()))
            .collect();
        SFGCycles {
            paths: cycles,
            orders: Self::get_orders(&cycle_contents),
        }
    }
    fn cache_cycles(&mut self) {
        if self.cycles_out_of_date {
            self.cycles = Some(self.calculate_cycles());
            self.cycles_out_of_date = false;
        }
    }
    pub fn path_gain(&self, path: Iter<NodeIndex>) -> Complex64 {
        // TODO maybe optimize this to not require copying for cycles? Surely there's a way.
        // I think it might be possible to abstract over the circular window and non-circular window methods?
        path.tuple_windows::<(_, _)>()
            .map(|(lastnode, node)| {
                self.graph
                    .edges_connecting(*lastnode, *node)
                    .next()
                    .unwrap()
                    .weight()
            })
            .product()
    }
    pub fn calculate_cycle_weights(&self, cycles: &SFGCycles) -> Vec<Vec<Complex64>> {
        let firstord_weights: Vec<Complex64> = cycles
            .paths
            .iter()
            .map(|cycle| {
                self.path_gain(
                    cycle
                        .iter()
                        .chain(cycle.iter().take(1))
                        .copied()
                        .collect::<Vec<_>>()
                        .iter(),
                )
            })
            .collect();
        cycles
            .orders
            .iter()
            .map(|order| {
                order
                    .iter()
                    .map(|l| l.0.iter().map(|i| firstord_weights[*i]).product())
                    .collect()
            })
            .collect()
    }
    fn cache_cycle_weights(&mut self) {
        let cycles = match &self.cycles {
            Some(c) => c,
            None => &self.calculate_cycles(),
        };
        self.cycle_weights = Some(self.calculate_cycle_weights(cycles));
    }
    fn get_orders(
        cycle_contents: &[HashSet<NodeIndex>],
    ) -> Vec<Vec<(HashSet<usize>, HashSet<NodeIndex>)>> {
        let mut orders: Vec<Vec<(HashSet<usize>, HashSet<NodeIndex>)>> = Vec::new();
        orders.push(
            cycle_contents
                .iter()
                .cloned()
                .enumerate()
                .map(|(i, el)| {
                    let mut hs = HashSet::new();
                    hs.insert(i);
                    (hs, el)
                })
                .collect(),
        );
        loop {
            let mut neworder: Vec<(HashSet<usize>, HashSet<NodeIndex>)> = Vec::new();
            let mut seen_loops_sorted: HashSet<Vec<usize>> = HashSet::new();
            for l in orders.last().unwrap() {
                for (i, el) in cycle_contents.iter().enumerate() {
                    if !l.0.contains(&i) && l.1.is_disjoint(el) {
                        let mut loops = l.0.clone();
                        loops.insert(i);
                        // Prevent duplicate loops.
                        let loops_sorted = loops.iter().copied().sorted().collect();
                        if !seen_loops_sorted.contains(&loops_sorted) {
                            let mut contents = l.1.clone();
                            contents.extend(el);
                            seen_loops_sorted.insert(loops_sorted);
                            neworder.push((loops, contents));
                        }
                    }
                }
            }
            if neworder.is_empty() {
                break;
            }
            orders.push(neworder);
        }
        orders
    }
    fn nonintersecting_graph_det(
        path: &HashSet<NodeIndex>,
        cycles: &SFGCycles,
        weights: &[Vec<Complex64>],
    ) -> Complex64 {
        cycles
            .orders
            .iter()
            .enumerate()
            .map(|(n, order_loops)| {
                // Plus one because first iteration should be negated.
                (-Complex64::ONE).powi(n as i32 + 1)
                    * order_loops
                        .iter()
                        .enumerate()
                        .map(|(i, order_loop)| {
                            if order_loop.1.is_disjoint(path) {
                                weights[n][i]
                            } else {
                                Complex64::ZERO
                            }
                        })
                        .sum::<Complex64>()
            })
            .sum::<Complex64>()
            + Complex64::ONE
    }
    pub fn masons_rule(&self, from: ComponentPort, to: ComponentPort, flip_a_b: bool) -> Complex64 {
        // TODO result this
        let mut from_idx = self.port_to_index.get(&from).unwrap()[0];
        let mut to_idx = self.port_to_index.get(&to).unwrap()[1];
        if flip_a_b {
            (from_idx, to_idx) = (to_idx, from_idx);
        }
        let cycles = match &self.cycles {
            Some(c) => c,
            None => &self.calculate_cycles(),
        };
        let cycle_weights = match &self.cycle_weights {
            Some(w) => w,
            None => &self.calculate_cycle_weights(cycles),
        };
        let gain: Complex64 = all_simple_paths::<Vec<_>, _>(&self.graph, from_idx, to_idx, 0, None)
            .map(|path| {
                self.path_gain(path.iter())
                    * Self::nonintersecting_graph_det(
                        &HashSet::from_iter(path.iter().cloned()),
                        cycles,
                        cycle_weights,
                    )
            })
            .sum();
        gain / Self::nonintersecting_graph_det(&HashSet::new(), cycles, cycle_weights)
    }
}

#[cfg(test)]
mod tests {
    use std::fs::File;

    use num::{complex::ComplexFloat, Bounded};
    use ordered_float::OrderedFloat;
    use rayon::iter::{IntoParallelIterator, ParallelIterator};

    use crate::{
        netlist::netlist_to_connections,
        parts::{lumped::LumpedProps, lumpedmatch::MatchProps, tee::TeeProps, tline::TLineProps},
        sim::{LengthSpec, SimType},
    };

    use super::*;
    const SIM: SimProps = SimProps {
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

    #[test]
    /// RF ground at design frequency, using an explicit lumped element rather than a match.
    fn tline_virtual_short() {
        let line = TLineProps::new(SIM.z0, LengthSpec::Degrees(90.), false, &SIM).unwrap();
        let l50 = LumpedProps::new(1., 0., 0.);
        let list = [
            NetlistElement {
                component: Component::Lumped(l50),
                port_nets: vec![0, 1],
            },
            NetlistElement {
                component: Component::TLine(line),
                port_nets: vec![1, 2],
            },
        ];
        let grounds = HashSet::from_iter(0..=0);
        let (conn, virt_comp) = netlist_to_connections(&list, &grounds);
        let mut sfg = SignalFlowGraph::new(&conn);
        sfg.populate(SIM.design_freq, &list, &virt_comp, &SIM);
        let port1 = ComponentPort {
            component_ind: 0,
            is_virtual: false,
            port_num: 1,
        };
        let s11 = sfg.masons_rule(port1, port1, true);
        assert!((Complex64::new(-1.0, 0.0) - s11).abs() < 1e-12);
    }

    #[test]
    /// Branchline coupler segment: even-even mode.
    fn branchline_ee() {
        let z0line = TLineProps::new(SIM.z0, LengthSpec::Degrees(45.), false, &SIM).unwrap();
        let thickline =
            TLineProps::new(SIM.z0 / (2.0.sqrt()), LengthSpec::Degrees(45.), false, &SIM).unwrap();
        let l50 = MatchProps::default();
        let list = [
            NetlistElement {
                component: Component::Match(l50),
                port_nets: vec![1],
            },
            NetlistElement {
                component: Component::TLine(z0line),
                port_nets: vec![1, 2],
            },
            NetlistElement {
                component: Component::TLine(thickline),
                port_nets: vec![1, 3],
            },
        ];
        let grounds: HashSet<usize> = HashSet::new();
        let (conn, virt_comp) = netlist_to_connections(&list, &grounds);
        let mut sfg = SignalFlowGraph::new(&conn);
        sfg.populate(SIM.design_freq, &list, &virt_comp, &SIM);
        let port0 = ComponentPort {
            component_ind: 0,
            is_virtual: false,
            port_num: 0,
        };
        let s11 = sfg.masons_rule(port0, port0, true);
        let expected = Complex64::from_polar(1., -135f64.to_radians());
        assert!((s11 - expected).abs() < 1e-12);
    }

    #[test]
    /// Full branchline coupler at design frequency
    fn branchline_coupler_fd() {
        let z0line = TLineProps::new(SIM.z0, LengthSpec::Degrees(90.), false, &SIM).unwrap();
        let thickline =
            TLineProps::new(SIM.z0 / (2.0.sqrt()), LengthSpec::Degrees(90.), false, &SIM).unwrap();
        let l50 = MatchProps::default();
        let list = [
            NetlistElement {
                component: Component::Match(l50),
                port_nets: vec![1],
            },
            NetlistElement {
                component: Component::Match(l50),
                port_nets: vec![2],
            },
            NetlistElement {
                component: Component::Match(l50),
                port_nets: vec![3],
            },
            NetlistElement {
                component: Component::Match(l50),
                port_nets: vec![4],
            },
            NetlistElement {
                component: Component::TLine(z0line),
                port_nets: vec![1, 2],
            },
            NetlistElement {
                component: Component::TLine(z0line),
                port_nets: vec![3, 4],
            },
            NetlistElement {
                component: Component::TLine(thickline),
                port_nets: vec![1, 3],
            },
            NetlistElement {
                component: Component::TLine(thickline),
                port_nets: vec![2, 4],
            },
        ];
        let grounds: HashSet<usize> = HashSet::new();
        let (conn, virt_comp) = netlist_to_connections(&list, &grounds);
        let mut sfg = SignalFlowGraph::new(&conn);
        sfg.populate(SIM.design_freq, &list, &virt_comp, &SIM);
        let ports = [
            ComponentPort {
                component_ind: 0,
                is_virtual: false,
                port_num: 0,
            },
            ComponentPort {
                component_ind: 1,
                is_virtual: false,
                port_num: 0,
            },
            ComponentPort {
                component_ind: 2,
                is_virtual: false,
                port_num: 0,
            },
            ComponentPort {
                component_ind: 3,
                is_virtual: false,
                port_num: 0,
            },
        ];
        let half_90 = Complex64::from_polar(2.0.sqrt().recip(), -90f64.to_radians());
        let half_180 = Complex64::from_polar(2.0.sqrt().recip(), 180f64.to_radians());
        let zero = Complex64::ZERO;
        let expected = [
            [zero, zero, half_90, half_180],
            [zero, zero, half_180, half_90],
            [half_90, half_180, zero, zero],
            [half_180, half_90, zero, zero],
        ];
        let sparams: Vec<Vec<Complex64>> = ports
            .iter()
            .map(|porta| {
                ports
                    .iter()
                    .map(|portb| sfg.masons_rule(*portb, *porta, true))
                    .collect()
            })
            .collect();
        let maxerr = expected
            .iter()
            .enumerate()
            .map(|(i, row)| {
                row.iter()
                    .enumerate()
                    .map(|(j, val)| OrderedFloat((sparams[i][j] - val).abs()))
                    .max()
                    .unwrap_or(OrderedFloat::max_value())
            })
            .max()
            .unwrap_or(OrderedFloat::max_value());
        assert!(maxerr.into_inner() < 1e-12);
    }

    #[test]
    fn branchline_equiv_zerofreq() {
        let l50 = MatchProps::default();
        let tee = TeeProps::default();
        let list = [
            NetlistElement {
                component: Component::Match(l50),
                port_nets: vec![1],
            },
            NetlistElement {
                component: Component::Match(l50),
                port_nets: vec![2],
            },
            NetlistElement {
                component: Component::Match(l50),
                port_nets: vec![3],
            },
            NetlistElement {
                component: Component::Match(l50),
                port_nets: vec![4],
            },
            NetlistElement {
                component: Component::Tee(tee),
                port_nets: vec![1, 5, 6],
            },
            NetlistElement {
                component: Component::Tee(tee),
                port_nets: vec![2, 5, 7],
            },
            NetlistElement {
                component: Component::Tee(tee),
                port_nets: vec![3, 8, 6],
            },
            NetlistElement {
                component: Component::Tee(tee),
                port_nets: vec![4, 7, 8],
            },
        ];
        let ports = [
            ComponentPort {
                component_ind: 0,
                is_virtual: false,
                port_num: 0,
            },
            ComponentPort {
                component_ind: 1,
                is_virtual: false,
                port_num: 0,
            },
            ComponentPort {
                component_ind: 2,
                is_virtual: false,
                port_num: 0,
            },
            ComponentPort {
                component_ind: 3,
                is_virtual: false,
                port_num: 0,
            },
        ];
        let grounds: HashSet<usize> = HashSet::new();
        let (conn, virt_comp) = netlist_to_connections(&list, &grounds);
        let mut sfg = SignalFlowGraph::new(&conn);
        sfg.populate(0.0, &list, &virt_comp, &SIM);
        //let dot = petgraph::dot::Dot::new(&sfg.graph);
        //println!("{:?}", dot);
        //println!("{:#?}", sfg);
        let expected = [
            [-0.5, 0.5, 0.5, 0.5],
            [0.5, -0.5, 0.5, 0.5],
            [0.5, 0.5, -0.5, 0.5],
            [0.5, 0.5, 0.5, -0.5],
        ];
        let sparams: Vec<Vec<Complex64>> = ports
            .iter()
            .map(|porta| {
                ports
                    .iter()
                    .map(|portb| sfg.masons_rule(*portb, *porta, true))
                    .collect()
            })
            .collect();
        //println!("{sparams:#?}");

        let maxerr = expected
            .iter()
            .enumerate()
            .map(|(i, row)| {
                row.iter()
                    .enumerate()
                    .map(|(j, val)| OrderedFloat((sparams[i][j] - val).abs()))
                    .max()
                    .unwrap_or(OrderedFloat::max_value())
            })
            .max()
            .unwrap_or(OrderedFloat::max_value());
        assert!(maxerr.into_inner() < 1e-12);
    }

    #[test]
    /// Full branchline coupler - frequency sweep
    fn branchline_coupler_sweep() {
        let z0line = TLineProps::new(SIM.z0, LengthSpec::Degrees(90.), false, &SIM).unwrap();
        let thickline =
            TLineProps::new(SIM.z0 / (2.0.sqrt()), LengthSpec::Degrees(90.), false, &SIM).unwrap();
        let l50 = MatchProps::default();
        let list = [
            NetlistElement {
                component: Component::Match(l50),
                port_nets: vec![1],
            },
            NetlistElement {
                component: Component::Match(l50),
                port_nets: vec![2],
            },
            NetlistElement {
                component: Component::Match(l50),
                port_nets: vec![3],
            },
            NetlistElement {
                component: Component::Match(l50),
                port_nets: vec![4],
            },
            NetlistElement {
                component: Component::TLine(z0line),
                port_nets: vec![1, 2],
            },
            NetlistElement {
                component: Component::TLine(z0line),
                port_nets: vec![3, 4],
            },
            NetlistElement {
                component: Component::TLine(thickline),
                port_nets: vec![1, 3],
            },
            NetlistElement {
                component: Component::TLine(thickline),
                port_nets: vec![2, 4],
            },
        ];
        let grounds: HashSet<usize> = HashSet::new();
        let (conn, virt_comp) = netlist_to_connections(&list, &grounds);
        let mut sfg = SignalFlowGraph::new(&conn);
        let ports = [
            ComponentPort {
                component_ind: 0,
                is_virtual: false,
                port_num: 0,
            },
            ComponentPort {
                component_ind: 1,
                is_virtual: false,
                port_num: 0,
            },
            ComponentPort {
                component_ind: 2,
                is_virtual: false,
                port_num: 0,
            },
            ComponentPort {
                component_ind: 3,
                is_virtual: false,
                port_num: 0,
            },
        ];
        let min = 0.0;
        let max = 2. * SIM.design_freq;
        let n = 201;
        let step = (max - min) / (n - 1) as f64;
        let mut sparams: HashMap<OrderedFloat<f64>, Vec<Vec<Complex64>>> = HashMap::new();
        // Virtual components don't change with frequency.
        sfg.populate(SIM.design_freq / 2.0, &list, &virt_comp, &SIM);
        (0..n)
            .into_par_iter()
            .map(|i| {
                // TODO: figure out why my SFG solver explodes at DC.
                let freq = 1e-6 + i as f64 * step;
                let mut cloned = sfg.clone();
                cloned.populate_components(freq, &list, &SIM);
                (
                    OrderedFloat(freq),
                    ports
                        .iter()
                        .map(|porta| {
                            ports
                                .iter()
                                .map(|portb| cloned.masons_rule(*portb, *porta, true))
                                .collect::<Vec<_>>()
                        })
                        .collect::<Vec<_>>(),
                )
            })
            .collect::<Vec<_>>()
            .into_iter()
            .fold(None, |_, (f, par)| sparams.insert(f, par));
        let file =
            File::create("test/data/sfg/branchline.json").expect("Failed to open test data file.");
        serde_json::to_writer_pretty(file, &sparams).expect("Unable to serialize s-parameters.");
    }
}
