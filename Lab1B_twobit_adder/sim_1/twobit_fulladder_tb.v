`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/19/2026 03:12:37 PM
// Design Name: 
// Module Name: twobit_fulladder_tb
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


module twobit_fulladder_tb;
    reg A0;
    reg A1;
    reg B0;
    reg B1;
    reg CIN;
    wire COUT;
    wire S0;
    wire S1;
    TopDesign_wrapper uut(.A0(A0),
        .A1(A1),
        .B0(B0),
        .B1(B1),
        .CIN(CIN),
        .COUT(COUT),
        .S0(S0),
        .S1(S1)); // Check the order
    initial begin
        CIN = 0;
        A1 = 0; A0 = 0; B1 = 0; B0 = 0;
        #11
        A1 = 1; A0 = 0; B1 = 0; B0 = 1;
        #11
        A1 = 1; A0 = 1;
        #11
        B1 = 1; B0 = 1;
        #11
        $finish;
    end
    always @(S0 or COUT or S1) begin
        $display("<%d> A1A0 = %b%b B1B0 = %b%b CIN = %b COUTS1S0 = %b%b%b\n", $time, A1,A0,B1,B0,CIN,COUT,S1,S0);
    end
endmodule
