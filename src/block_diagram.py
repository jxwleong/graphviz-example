from graphviz import Digraph

dot = Digraph('two_blocks')
dot.attr(rankdir='LR')
dot.attr('node', shape='box', width='2', height='3', fixedsize='true')
dot.attr(forcelabels='true')
dot.attr(splines='ortho')

dot.node('A', label='CPU 1')
dot.node('B', label='CPU 2')
dot.node('C', label='Memory')

dot.edge('A', 'B', dir='none', label='Connection 1')
dot.edge('A', 'B', dir='none', label='Connection 2')
dot.edge('A', 'B', dir='none', label='Connection 3')

dot.edge('B', 'C', dir='none', label='AXI')
dot.edge('A', 'C', dir='none', label='AXI')

dot.render('block_diagram', format='png')