module and_gate (
     a, // 4-bit input 
     b, // 8-bit input 
     c // 12-bit output 
); 
    input a, b;
    output c;
    
    assign c = a & b; 
endmodule