from graphviz import Digraph

import os
import json
import sys


ROOT_DIR = os.path.normpath(os.path.join(os.path.abspath(__file__), "..", ".."))
sys.path.insert(0, ROOT_DIR)

DIAGRAM_DIR = os.path.join(ROOT_DIR, "diagrams")

def draw_module_block(module_name, inputs, outputs):
    dot = Digraph(format='png')
    dot.attr(rankdir='LR')  # Left-to-right layout

        # Create HTML-like table for better control
    max_len = max([len(p) for p in inputs + outputs], default=10)
    center_width = 8 * max_len  # Tune this multiplier as needed

    label = f'''<
    <TABLE BORDER="1" CELLBORDER="1" CELLSPACING="0" BGCOLOR="lightgray">
        <TR>
            <TD>
                <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">
                    {''.join(f"<TR><TD PORT='in{i}'>{inp}</TD></TR>" for i, inp in enumerate(inputs))}
                </TABLE>
            </TD>
            <TD WIDTH="{center_width}"><B>{module_name}</B></TD>
            <TD>
                <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">
                    {''.join(f"<TR><TD PORT='out{i}'>{out}</TD></TR>" for i, out in enumerate(outputs))}
                </TABLE>
            </TD>
        </TR>
    </TABLE>
    >'''

    dot.node('module', label=label, shape='plaintext')

    return dot

def load_module_info_from_json(json_path):
    with open(json_path, 'r') as f:
        data = json.load(f)

    module_name = data.get("module", "UnnamedModule")
    inputs = data.get("input", [])
    outputs = data.get("output", [])

    return module_name, inputs, outputs

if __name__ == "__main__":
    # Path to your JSON file
    json_file = '/home/jason/graphviz-example/out/cpu.json'

    module_name, inputs, outputs = load_module_info_from_json(json_file)
    graph = draw_module_block(module_name, inputs, outputs)

    # Output filename (SVG)
    output_path = os.path.join(DIAGRAM_DIR, f"{module_name}_block")
    os.makedirs(output_path, exist_ok=True)
    
    diagram_path = os.path.join(output_path, f"{module_name}.png")
    graph.render(directory=output_path, filename=f"{module_name}", cleanup=True)

    print(f"Diagram generated: {diagram_path}")