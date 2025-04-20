from graphviz import Digraph

"""
def draw_module_block(module_name, inputs, outputs):
    dot = Digraph(format='png')
    dot.attr(rankdir='LR')  # Left-to-right layout

    # Create the module block as a record
    input_ports = ' | '.join(f'<in{i}>{name}' for i, name in enumerate(inputs))
    output_ports = ' | '.join(f'<out{i}>{name}' for i, name in enumerate(outputs))

    label = f'{{{{ {input_ports} }} | {module_name} | {{ {output_ports} }}}}'
    dot.node('module', label=label, shape='record', style='filled', fillcolor='lightgray')

    # External input/output nodes
    for i, name in enumerate(inputs):
        dot.node(f'in_{i}', name, shape='circle', style='filled', fillcolor='lightblue')
        dot.edge(f'in_{i}', f'module:in{i}')

    for i, name in enumerate(outputs):
        dot.node(f'out_{i}', name, shape='circle', style='filled', fillcolor='lightgreen')
        dot.edge(f'module:out{i}', f'out_{i}')

    return dot"""

"""
def draw_module_block(module_name, inputs, outputs):
    dot = Digraph(format='png')
    dot.attr(rankdir='LR')  # Left-to-right layout

    # Create the module block as a record
    input_ports = ' | '.join(f'<in{i}>{name}' for i, name in enumerate(inputs))
    output_ports = ' | '.join(f'<out{i}>{name}' for i, name in enumerate(outputs))

    label = f'{{{{ {input_ports} }} | {module_name} | {{ {output_ports} }}}}'
    dot.node('module', label=label, shape='record', style='filled', fillcolor='lightgray')

    return dot


# Example usage
inputs = ['a', 'b', 'sel']
outputs = ['y']
module_name = 'Mux2to1'

graph = draw_module_block(module_name, inputs, outputs)
graph.render('module_block.svg')
"""

from graphviz import Digraph

def add_module(dot, module_id, module_name, inputs, outputs):
    input_ports = ' | '.join(f'<in{i}>{name}' for i, name in enumerate(inputs))
    output_ports = ' | '.join(f'<out{i}>{name}' for i, name in enumerate(outputs))
    label = f'{{{{ {input_ports} }} | {module_name} | {{ {output_ports} }}}}'
    dot.node(module_id, label=label, shape='record', style='filled', fillcolor='lightgray')

# Create the graph
dot = Digraph(format='png')
dot.attr(rankdir='LR')  # Left to right

# Add two modules
add_module(dot, 'mux1', 'Mux2to1', ['a', 'b', 'sel'], ['y'])
add_module(dot, 'mux2', 'Mux2to1', ['x', 'y', 'sel2'], ['z'])

# Connect mux1's output 'y' to mux2's input 'y'
dot.edge('mux1:out0', 'mux2:in1', label='signal_y')  # mux1's output y to mux2's second input (index 1)

# Render the diagram
dot.render('connected_modules.svg', view=False)
