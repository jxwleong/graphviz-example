from verilog_parser.parser import parse_verilog as parser

verilog_file_path = 'verilog.v'

data = r"""
module blabla(
port1, 
port_2
);
    input [0:1234] abc;
    output [1:3] edfg;
    wire [1234:45] mywire;

    assign a = b;

    assign {a, b[1], c[0: 39]} = {x, y[5], z[1:40]};
    assign {a, b[1], c[0: 39]} = {x, y[5], 1'h0 };
    (* asdjfasld ajsewkea 3903na ;lds *)
    wire zero_set;
    OR _blabla_ ( .A(netname), .B (qwer) );
    OR blabla2 ( .A(netname), .B (1'b0) );

wire zero_res;
  (* src = "alu_shift.v:23" *)
  wire zero_set;
  NOT _072_ (
    .A(func_i[2]),
    .Y(_008_)
  );

endmodule
"""

data2 = r"""
module and_gate(
a, 
b
);
    
    assign c = a & b; 
endmodule
"""

ast = parser(data2)

print(ast)