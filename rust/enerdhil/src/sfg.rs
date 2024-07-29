use std::{
    collections::{HashMap, HashSet},
    mem,
};

use graph_cycles::Cycles;
use num::complex::Complex64;
use petgraph::{algo::all_simple_paths, graph::NodeIndex, Graph};

use crate::{
    netlist::{ComponentPort, NetlistElement},
    parts::{open::OpenProps, short::ShortProps, tee::TeeProps, Component},
    sim::SimProps,
};

#[cfg(debug_assertions)]
struct SFGNode {
    num: usize,
    into_port: bool,
}
#[cfg(not(debug_assertions))]
struct SFGNode {}

pub struct SFGCycles {
    paths: Vec<Vec<NodeIndex>>,
    /// First element of each is the indices of the paths contained,
    /// second element is the nodes contained.
    orders: Vec<Vec<(HashSet<usize>, HashSet<NodeIndex>)>>,
}

pub struct SignalFlowGraph {
    graph: Graph<SFGNode, Complex64>,
    port_to_index: HashMap<ComponentPort, [NodeIndex; 2]>,
    cycles: Option<SFGCycles>,
    cycle_weights: Option<Vec<Vec<Complex64>>>,
}

impl SignalFlowGraph {
    pub fn new(connections: &HashMap<usize, [ComponentPort; 2]>) -> Self {
        let mut graph =
            Graph::<SFGNode, Complex64>::with_capacity(connections.len(), 3 * connections.len());
        let mut port_to_index = HashMap::with_capacity(2 * connections.len());
        for (node, pair) in connections.iter() {
            #[cfg(debug_assertions)]
            let a_ind = graph.add_node(SFGNode {
                num: *node,
                into_port: true,
            });
            #[cfg(not(debug_assertions))]
            let a_ind = graph.add_node(SFGNode {});
            #[cfg(debug_assertions)]
            let b_ind = graph.add_node(SFGNode {
                num: *node,
                into_port: false,
            });
            #[cfg(not(debug_assertions))]
            let b_ind = graph.add_node(SFGNode {});
            port_to_index.insert(pair[0].clone(), [a_ind, b_ind]);
            port_to_index.insert(pair[1].clone(), [a_ind, b_ind]);
        }
        SignalFlowGraph {
            graph,
            port_to_index,
            cycles: None,
            cycle_weights: None,
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
                self.graph.update_edge(a_idx, b_idx, sparams[i][j]);
            }
        }
    }
    pub fn populate_virtual(
        &mut self,
        freq: f64,
        virtual_components: &Vec<Component>,
        sim: &SimProps,
    ) {
        for (ind, comp) in virtual_components.iter().enumerate() {
            self.populate_component(ind, true, comp, freq, sim);
        }
    }
    pub fn populate_components(
        &mut self,
        freq: f64,
        components: &Vec<NetlistElement>,
        sim: &SimProps,
    ) {
        for (ind, comp) in components.iter().enumerate() {
            self.populate_component(ind, false, &comp.component, freq, sim);
        }
    }
    pub fn populate(
        &mut self,
        freq: f64,
        components: &Vec<NetlistElement>,
        virtual_components: &Vec<Component>,
        sim: &SimProps,
    ) {
        self.populate_components(freq, components, sim);
        self.populate_virtual(freq, virtual_components, sim);
    }
    pub fn calculate_cycles(&self) -> SFGCycles {
        let cycles = self.graph.cycles();
        let cycle_contents = cycles
            .iter()
            .map(|cycle| HashSet::from_iter(cycle.iter().cloned()))
            .collect();
        SFGCycles {
            paths: cycles,
            orders: Self::get_orders(&cycle_contents),
        }
    }
    pub fn cache_cycles(&mut self) {
        self.cycles = Some(self.calculate_cycles());
    }
    fn path_gain(&self, path: &Vec<NodeIndex>) -> Complex64 {
        path.iter()
            .fold(
                (Complex64::ONE, None),
                |last: (Complex64, Option<NodeIndex>), node| match last.1 {
                    Some(lastnode) => (
                        last.0
                            * self
                                .graph
                                .edges_connecting(lastnode, *node)
                                .next()
                                .unwrap()
                                .weight(),
                        Some(*node),
                    ),
                    None => (last.0, Some(*node)),
                },
            )
            .0
    }
    fn calculate_cycle_weights(&self, cycles: &SFGCycles) -> Vec<Vec<Complex64>> {
        let firstord_weights: Vec<Complex64> = cycles
            .paths
            .iter()
            .map(|cycle| self.path_gain(cycle))
            .collect();
        cycles
            .orders
            .iter()
            .map(|order| {
                order
                    .iter()
                    .map(|l| {
                        l.0.iter()
                            .fold(Complex64::ONE, |acc, i| acc * firstord_weights[*i])
                    })
                    .collect()
            })
            .collect()
    }
    pub fn cache_cycle_weights(&mut self) {
        let cycles = match &self.cycles {
            Some(c) => c,
            None => &self.calculate_cycles(),
        };
        self.cycle_weights = Some(self.calculate_cycle_weights(&cycles));
    }
    fn get_orders(
        cycle_contents: &Vec<HashSet<NodeIndex>>,
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
            for l in orders.last().unwrap() {
                for (i, el) in cycle_contents.iter().enumerate() {
                    if !l.0.contains(&i) && l.1.is_disjoint(el) {
                        let mut loops = l.0.clone();
                        loops.insert(i);
                        let mut contents = l.1.clone();
                        contents.extend(el);
                        neworder.push((loops, contents));
                    }
                }
            }
            if neworder.len() == 0 {
                break;
            }
        }
        orders
    }
    fn nonintersecting_graph_det(
        path: &HashSet<NodeIndex>,
        cycles: &SFGCycles,
        weights: &Vec<Vec<Complex64>>,
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
    pub fn masons_rule(&self, from: ComponentPort, to: ComponentPort) -> Complex64 {
        // TODO result this
        let from_idx = self.port_to_index.get(&from).unwrap()[0];
        let to_idx = self.port_to_index.get(&to).unwrap()[1];
        let cycles = match &self.cycles {
            Some(c) => c,
            None => &self.calculate_cycles(),
        };
        let cycle_weights = match &self.cycle_weights {
            Some(w) => w,
            None => &self.calculate_cycle_weights(&cycles),
        };
        let gain: Complex64 = all_simple_paths::<Vec<_>, _>(&self.graph, from_idx, to_idx, 0, None)
            .map(|path| {
                self.path_gain(&path)
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
