`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/19/2026 02:17:14 PM
// Design Name: 
// Module Name: fulladder_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fulladder_tb;
    reg a, b, c;
    wire sum, cout;
    TopDesign_wrapper uut(a, b, c, cout, sum); // Check the order
    initial begin
        #80
        $finish;
    end
    initial begin
        a=0; b=0; c=0;
        #15
        a=1; b=0; c=1;
        #15
        a=1; b=1; c=0;
        #15
        a=1; b=1; c=1;
    end
    always @(sum or cout) begin
        $display("<%d> a=%b, b=%b, cin=%b, sum=%b, cout=%b\n", $time, a, b, c, sum, cout);
    end
endmodule
