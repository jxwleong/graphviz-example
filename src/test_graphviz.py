import graphviz
import re
import json
import os
import argparse

# -----------------------------
# Argument parsing
# -----------------------------
parser = argparse.ArgumentParser(description="Generate hardware graph from JSON file.")
parser.add_argument(
    "--input_file",
    required=True,
    help="Full path to the JSON file containing hardware data."
)
parser.add_argument(
    "--output_file",
    default="hardware_graph.gv",
    help="Output file name of the diagram."
)

args = parser.parse_args()

filepath = os.path.abspath(args.input_file)
filename = os.path.splitext(os.path.basename(filepath))[0]
output_filename = args.output_file
# -----------------------------
# Load JSON data
# -----------------------------
with open(filepath) as f:
    data = json.load(f)

# Map each net to its source
net_sources = {}
for module in data:
    instance = module["instance"]
    for out in module.get("output", []):
        net = out["net"]
        pin = out["pin"]
        if net:
            net_sources[net] = (instance, pin)

# -----------------------------
# Create Graphviz Digraph
# -----------------------------
dot = graphviz.Digraph('G', filename=output_filename)
dot.attr(rankdir='LR')

with dot.subgraph(name=f'cluster_{filename}') as c:
    num_nodes = len(data)
    base_margin = 0.1
    margin_per_node = 20
    margin_value = base_margin + margin_per_node * num_nodes

    base_fontsize = 20
    fontsize_per_node = 2
    fontsize_value = base_fontsize + fontsize_per_node * num_nodes

    c.attr(
        label=filename,
        style='rounded,filled',
        color='#b7e1cd',
        fillcolor='#f4f9f4',
        fontsize=str(fontsize_value),
        fontname='times-bold',
        margin=f'{margin_value},{margin_value}'
    )

    # Add nodes
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

    # Add edges
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
                elif net == "":
                    if source_instance not in constant_nodes:
                        source_instance = "UNCONNECTED"
                        c.node(
                            source_instance,
                            label="UNCONNECTED",
                            shape='ellipse',
                            style='filled',
                            fillcolor='#ffcccc',
                            fontsize='14',
                            fontcolor='#a94442'
                        )
                        constant_nodes.add(source_instance)
                    label = f"UNCONNECTED -> {target_instance}.{target_pin}"
                    c.edge(source_instance, target_instance, label=label)

# -----------------------------
# Output
# -----------------------------
output_base = os.path.join(os.path.dirname(filepath), f"{output_filename}_hardware_graph")
output_path = dot.render(output_base, format="pdf")  # or "png" if you prefer

print(dot.source)
dot.render()

print(f"Output file: {output_path}")
