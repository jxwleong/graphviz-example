#!/bin/bash

this_script_path=$(readlink -f "$0")

levels_up=2
root_dir="$this_script_path"
for ((i = 0; i < levels_up; i++)); do
    root_dir=$(dirname "$root_dir")
done


perl $root_dir/src/test_perl_verilog_netlist.pl  -top /home/jason/graphviz-example/examples/riscv_cpu_example/CPU.v -f $root_dir/examples/riscv_cpu_example/riscv.vc +define+FOO=bar
python3 $root_dir/src/test_graphviz.py --input_file $root_dir/src/CPU.json