import graphviz
import re
import json


filepath = r"/home/jason/graphviz-example/modules_all.json"

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

# Add nodes with size and font size based on number of inputs/outputs
for module in data:
    n_inputs = len(module.get("input", []))
    n_outputs = len(module.get("output", []))
    min_width = 1.5
    min_height = 0.7
    min_fontsize = 12
    width = min_width + 0.3 * max(n_inputs, n_outputs)
    height = min_height + 0.2 * (n_inputs + n_outputs)
    fontsize = min_fontsize + 2 * max(n_inputs, n_outputs)
    dot.node(
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
    # Replace all non-alphanumeric characters with underscores
    return re.sub(r'[^A-Za-z0-9_]', '_', name)

# Add edges with label: "source_instance.source_pin | net_name | target_instance.target_pin"
for module in data:
    target_instance = module["instance"]
    for inp in module.get("input", []):
        net = inp.get("net")
        target_pin = inp.get("pin", "")
         # Check if net is a constant (no source)
        if net and net not in net_sources and not inp.get("connection"):
            const_node_name = f"CONST_{sanitize_node_name(net)}"
            if const_node_name not in constant_nodes:
                dot.node(
                    const_node_name,
                    label=net,  # Just the number or value
                    shape='ellipse',
                    style='filled',
                    fillcolor='#fff2cc',
                    fontsize='14'
                )
                constant_nodes.add(const_node_name)
            pin_name = f'{net} -> {target_instance}.{inp.get("pin")}'  # or whatever your pin name variable is
            dot.edge(
                const_node_name,
                target_instance,
                label=pin_name
                #taillabel=pin_name,
                #labeldistance='2'
             )
            
        elif net and net in net_sources:
            source_instance, source_pin = net_sources[net]
            #label = f"{source_instance}.{source_pin} | {net} | {target_instance}.{target_pin}"
            label = f"{source_instance}.{source_pin} -> {target_instance}.{target_pin}"
            dot.edge(source_instance, target_instance, label=label)
        elif "connection" in inp and inp["connection"]:
            m = re.match(r"(\w+)\.(\w+)", inp["connection"])
            if m:
                source_instance, source_pin = m.groups()
                #label = f"{source_instance}.{source_pin} | {inp.get('net', '')} | {target_instance}.{inp.get('pin', '')}"
                label = f"{source_instance}.{source_pin} -> {target_instance}.{inp.get('pin', '')}"
                dot.edge(source_instance, target_instance, label=label)
            else:
                dot.edge(inp["connection"], target_instance, label=inp.get("net", ""))

print(dot.source)
# Render and view (optional)
dot.render()
