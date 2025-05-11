import graphviz
import re
import json
import os

filepath = r"/home/jason/graphviz-example/CombinedCUnDP.json"
filename = os.path.splitext(os.path.basename(filepath))[0]

with open(filepath) as f:
    data = json.load(f)
    
    
net_sources = {}
for module in data:
    instance = module["instance"]
    for out in module.get("output", []):
        net = out["net"]
        pin = out["pin"]
        if net:
            net_sources[net] = (instance, pin)

dot = graphviz.Digraph('G', filename='hardware_graph.gv')
dot.attr(rankdir='LR')

with dot.subgraph(name=f'cluster_{filename}') as c:
    c.attr(label=filename, style='rounded,filled', color='#b7e1cd', fillcolor='#f4f9f4', fontsize='20', fontname='times-bold',margin='100,100')

    # Add nodes to the cluster
    for module in data:
        n_inputs = len(module.get("input", []))
        n_outputs = len(module.get("output", []))
        min_width = 1.5
        min_height = 0.7
        min_fontsize = 12
        width = min_width + 0.3 * max(n_inputs, n_outputs)
        height = min_height + 0.2 * (n_inputs + n_outputs)
        fontsize = min_fontsize + 2 * max(n_inputs, n_outputs)
        c.node(
            module["instance"],
            label=module["instance"],
            shape='box',
            width=str(width),
            height=str(height),
            fixedsize='false',
            fontsize=str(fontsize),
            fontname='times-bold',
            style='filled',      
            fillcolor='#e6f2ff'
        )

    constant_nodes = set()

    def sanitize_node_name(name):
        return re.sub(r'[^A-Za-z0-9_]', '_', name)

    # Add edges (inside the cluster)
    for module in data:
        target_instance = module["instance"]
        for inp in module.get("input", []):
            net = inp.get("net")
            target_pin = inp.get("pin", "")
            if net and net not in net_sources and not inp.get("connection"):
                const_node_name = f"CONST_{sanitize_node_name(net)}"
                if const_node_name not in constant_nodes:
                    c.node(
                        const_node_name,
                        label=net,
                        shape='ellipse',
                        style='filled',
                        fillcolor='#fff2cc',
                        fontsize='14'
                    )
                    constant_nodes.add(const_node_name)
                pin_name = f'{net} -> {target_instance}.{inp.get("pin")}'
                c.edge(
                    const_node_name,
                    target_instance,
                    label=pin_name
                )
            elif net and net in net_sources:
                source_instance, source_pin = net_sources[net]
                label = f"{source_instance}.{source_pin} -> {target_instance}.{target_pin}"
                c.edge(source_instance, target_instance, label=label)
            elif "connection" in inp and inp["connection"]:
                m = re.match(r"(\w+)\.(\w+)", inp["connection"])
                if m:
                    source_instance, source_pin = m.groups()
                    label = f"{source_instance}.{source_pin} -> {target_instance}.{inp.get('pin', '')}"
                    c.edge(source_instance, target_instance, label=label)
                else:
                    c.edge(inp["connection"], target_instance, label=inp.get("net", ""))

print(dot.source)
dot.render()