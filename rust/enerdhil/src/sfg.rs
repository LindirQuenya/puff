use std::{
    collections::{HashMap, HashSet},
    mem,
};

use bimap::BiHashMap;
use num::complex::Complex64;
use petgraph::Graph;
use rand::{random, thread_rng, Rng};

use crate::parts::{open::OpenProps, short::ShortProps, tee::TeeProps, Component};

pub struct NetlistElement {
    component: Component,
    port_nets: Vec<usize>,
}

pub struct ComponentPort {
    component_ind: usize,
    /// warning: zero-based!
    port_num: usize,
}

/// Add appropriate virtual components to transform this into a connection list.
/// note: ports should already be in the netlist as 1z grounded lumped elements.
pub fn netlist_to_connections(
    list: Vec<NetlistElement>,
    grounds: HashSet<usize>,
) -> (
    HashMap<usize, [ComponentPort; 2]>,
    Vec<(Component, usize)>,
    BiHashMap<usize, usize>,
) {
    // Translation from net numbers to node numbers.
    let mut net_to_node = BiHashMap::<usize, usize>::new();
    let mut next_node: usize = 0;
    // Numbers distinct components unambiguously. Also include port counts.
    let mut components = Vec::<(Component, usize)>::new();
    // Nodes that currently lack a second connection.
    let mut single_nodes = HashMap::<usize, ComponentPort>::new();
    // Maps node numbers to associated connections.
    let mut connections = HashMap::<usize, [ComponentPort; 2]>::new();
    for comp in list {
        let component_ind = components.len();
        components.push((comp.component.clone(), comp.port_nets.len()));
        for (port_num, net) in comp.port_nets.iter().enumerate() {
            let port = ComponentPort {
                component_ind,
                port_num,
            };
            if grounds.contains(net) {
                // Don't bother with translation, we have an isolated one-port.
                let short_ind = components.len();
                components.push((Component::Short(ShortProps::new()), 1));
                connections.insert(
                    next_node,
                    [
                        port,
                        ComponentPort {
                            component_ind: short_ind,
                            port_num: 0,
                        },
                    ],
                );
                next_node += 1;
                // Skip the rest of the interation.
                continue;
            }
            // Try to translate the net to a node number.
            let node = match net_to_node.get_by_left(net) {
                Some(node) => *node,
                None => {
                    let node = next_node;
                    next_node += 1;
                    net_to_node.insert(*net, node);
                    node
                }
            };
            if let Some(otherport) = single_nodes.remove(&node) {
                // Connect up the single node with our new port.
                connections.insert(node, [otherport, port]);
            } else if let Some(pair) = connections.get_mut(&node) {
                // Insert a tee network.
                let tee_ind = components.len();
                components.push((Component::Tee(TeeProps::new()), 3));
                let prev = mem::replace(
                    &mut pair[1],
                    ComponentPort {
                        component_ind: tee_ind,
                        port_num: 0,
                    },
                );
                connections.insert(
                    next_node,
                    [
                        prev,
                        ComponentPort {
                            component_ind: tee_ind,
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
        let open_ind = components.len();
        components.push((Component::Open(OpenProps::new()), 1));
        connections.insert(
            node,
            [
                port,
                ComponentPort {
                    component_ind: open_ind,
                    port_num: 0,
                },
            ],
        );
    }
    (connections, components, net_to_node)
}

type SFGNode = (usize, bool);
pub struct SignalFlowGraph {
    graph: Graph<SFGNode, Complex64>,
    cycles: Vec<Vec<SFGNode>>,
}

impl SignalFlowGraph {
    pub fn new(connections: HashMap<usize, [ComponentPort; 2]>) -> Self {
        todo!();
    }
}
