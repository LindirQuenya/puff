use std::{
    collections::{HashMap, HashSet},
    mem,
};


use crate::parts::{open::OpenProps, short::ShortProps, tee::TeeProps, Component};

pub struct NetlistElement {
    pub component: Component,
    pub port_nets: Vec<usize>,
}

#[derive(PartialEq, Eq, Clone, Hash)]
pub struct ComponentPort {
    /// The index of the component this references in the appropriate list,
    /// corresponding to the value of `is_virtual`.
    pub component_ind: usize,
    /// Whether the component index refers to the virtual (generated) list
    /// or the user-supplied (physical) list.
    pub is_virtual: bool,
    /// warning: zero-based!
    pub port_num: usize,
}

/// Add appropriate virtual components to transform this into a connection list.
/// note: ports should already be in the netlist as 1z grounded lumped elements.
// TODO maybe refactor, this is kinda long.
pub fn netlist_to_connections(
    list: &[NetlistElement],
    grounds: &HashSet<usize>,
) -> (HashMap<usize, [ComponentPort; 2]>, Vec<Component>) {
    // Translation from net numbers to node numbers.
    let mut net_to_node = HashMap::<usize, usize>::new();
    let mut next_node: usize = 0;
    // Numbers virtual components unambiguously.
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
    (connections, virtual_components)
}
