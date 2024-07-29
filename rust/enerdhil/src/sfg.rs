use std::{
    collections::{HashMap, HashSet},
    mem,
};

use bimap::BiHashMap;
use num::complex::Complex64;
use petgraph::Graph;
use rand::{random, thread_rng, Rng};

use crate::{parts::{open::OpenProps, short::ShortProps, tee::TeeProps, Component}, sim::SimProps};

pub struct NetlistElement {
    pub component: Component,
    pub port_nets: Vec<usize>,
}

#[derive(PartialEq, Eq, Clone, Hash)]
pub struct ComponentPort {
    /// The index of the component this references in the appropriate list,
    /// corresponding to the value of `is_virtual`.
    component_ind: usize,
    /// Whether the component index refers to the virtual (generated) list
    /// or the user-supplied (physical) list.
    is_virtual: bool,
    /// warning: zero-based!
    port_num: usize,
}

/// Add appropriate virtual components to transform this into a connection list.
/// note: ports should already be in the netlist as 1z grounded lumped elements.
// TODO maybe refactor, this is kinda long.
pub fn netlist_to_connections(
    list: &Vec<NetlistElement>,
    grounds: &HashSet<usize>,
) -> (
    HashMap<usize, [ComponentPort; 2]>,
    Vec<Component>,
    HashMap<usize, usize>,
) {
    // Translation from net numbers to node numbers.
    let mut net_to_node = HashMap::<usize, usize>::new();
    let mut next_node: usize = 0;
    // Numbers distinct components unambiguously. Also include port counts.
    let mut virtual_components = Vec::<Component>::new();
    // Nodes that currently lack a second connection.
    let mut single_nodes = HashMap::<usize, ComponentPort>::new();
    // Maps node numbers to associated connections.
    let mut connections = HashMap::<usize, [ComponentPort; 2]>::new();
    for (ind, comp) in list.iter().enumerate() {
        if comp.component.get_port_num() != comp.port_nets.len() {
            panic!("Incorrect port number, TODO result this.");
        }
        for (port_num, net) in comp.port_nets.iter().enumerate() {
            let port = ComponentPort {
                component_ind: ind,
                is_virtual: false,
                port_num,
            };
            if grounds.contains(net) {
                // Don't bother with translation, we have an isolated one-port.
                let short_ind = virtual_components.len();
                virtual_components.push(Component::Short(ShortProps::new()));
                connections.insert(
                    next_node,
                    [
                        port,
                        ComponentPort {
                            component_ind: short_ind,
                            is_virtual: true,
                            port_num: 0,
                        },
                    ],
                );
                next_node += 1;
                // Skip the rest of the interation.
                continue;
            }
            // Try to translate the net to a node number.
            let node = match net_to_node.get(net) {
                Some(node) => *node,
                None => {
                    let node = next_node;
                    next_node += 1;
                    net_to_node.insert(*net, node);
                    node
                }
            };
            if let Some(otherport) = single_nodes.remove(&node) {
                // If this node is single, connect it up with our new port.
                connections.insert(node, [otherport, port]);
            } else if let Some(pair) = connections.get_mut(&node) {
                // If the node is already connected, insert a tee network.
                let tee_ind = virtual_components.len();
                virtual_components.push(Component::Tee(TeeProps::new()));
                let prev = mem::replace(
                    &mut pair[1],
                    ComponentPort {
                        component_ind: tee_ind,
                        is_virtual: true,
                        port_num: 0,
                    },
                );
                connections.insert(
                    next_node,
                    [
                        prev,
                        ComponentPort {
                            component_ind: tee_ind,
                            is_virtual: true,
                            port_num: 1,
                        },
                    ],
                );
                next_node += 1;
                connections.insert(
                    next_node,
                    [
                        port,
                        ComponentPort {
                            component_ind: tee_ind,
                            is_virtual: true,
                            port_num: 2,
                        },
                    ],
                );
                next_node += 1;
            } else {
                // This node is single for the moment.
                single_nodes.insert(node, port);
            }
        }
    }
    for (node, port) in single_nodes.into_iter() {
        let open_ind = virtual_components.len();
        virtual_components.push(Component::Open(OpenProps::new()));
        connections.insert(
            node,
            [
                port,
                ComponentPort {
                    component_ind: open_ind,
                    is_virtual: true,
                    port_num: 0,
                },
            ],
        );
    }
    (connections, virtual_components, net_to_node)
}

struct SFGNode {
    num: usize,
    into_port: bool,
}

pub struct SignalFlowGraph {
    graph: Graph<SFGNode, Complex64>,
    port_to_index: HashMap<ComponentPort, [petgraph::graph::NodeIndex; 2]>,
    cycles: Option<Vec<Vec<SFGNode>>>,
}

impl SignalFlowGraph {
    pub fn new(connections: &HashMap<usize, [ComponentPort; 2]>) -> Self {
        let mut graph = Graph::<SFGNode, Complex64>::with_capacity(connections.len(), 3*connections.len());
        let mut port_to_index = HashMap::with_capacity(2*connections.len());
        for (node, pair) in connections.iter() {
            let a_ind = graph.add_node(SFGNode {
                num: *node,
                into_port: true,
            });
            let b_ind = graph.add_node(SFGNode {
                num: *node,
                into_port: false,
            });
            port_to_index.insert(pair[0].clone(), [a_ind, b_ind]);
            port_to_index.insert(pair[1].clone(), [a_ind, b_ind]);
        }
        SignalFlowGraph {
            graph,
            port_to_index,
            cycles: None,
        }
    }
    // TODO this method could be optimized to death: results could be cached, double lookups avoided, etc.
    fn populate_component(&mut self, ind: usize, is_virtual: bool, comp: &Component, freq: f64, sim: &SimProps) {
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
                let a_idx = self.port_to_index.get(&a_i).unwrap()[0];
                let b_idx = self.port_to_index.get(&b_j).unwrap()[1];
                self.graph.update_edge(a_idx, b_idx, *sparams.get(i).expect("bad s-param dim?").get(j).expect("bad s-param dim?"));
            }
        }
    }
    pub fn populate_virtual(&mut self, freq: f64, virtual_components: &Vec<Component>, sim: &SimProps) {
        for (ind, comp) in virtual_components.iter().enumerate() {
            self.populate_component(ind, true, comp, freq, sim);
        }
    }
    pub fn populate_components(&mut self, freq: f64, components: &Vec<NetlistElement>, sim: &SimProps) {
        for (ind, comp) in components.iter().enumerate() {
            self.populate_component(ind, false, &comp.component, freq, sim);
        }
    }
    pub fn populate(&mut self, freq: f64, components: &Vec<NetlistElement>, virtual_components: &Vec<Component>, sim: &SimProps) {
        self.populate_components(freq, components, sim);
        self.populate_virtual(freq, virtual_components, sim);
    }
}
