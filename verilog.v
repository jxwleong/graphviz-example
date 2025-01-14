module and_gate (
    input a, // 4-bit input 
    input b, // 8-bit input 
    output c // 12-bit output ); 
    
    assign c = a & b; 
endmodule