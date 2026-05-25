`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/17/2026 08:24:53 PM
// Design Name: 
// Module Name: Memory
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


`include "defs.vh"

module Memory(
    input write_enable, 
    input clk, 
    input [1:0] command,   
    input [7:0] address, 
    input [31:0] word_in, 
    output [31:0] word_out
);
    reg [31:0] Mem [0:255];
    
    // Output word combinationally for loads and for read-modify-write subword stores
    assign word_out = ((command == `READ_COMMAND)) ? Mem[address] : 32'd0;

    always @ (posedge clk) begin
        if (((command == `WRITE_COMMAND)) && (write_enable == 1'b1)) begin
            Mem[address] <= word_in;
        end
    end
endmodule