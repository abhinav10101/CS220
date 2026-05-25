`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/29/2026 06:37:06 PM
// Design Name: 
// Module Name: Testbench
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


`timescale 1ns / 1ps

module Testbench();
    reg clk, reset;
    reg [7:0] ins_addr;
    reg [31:0] ins;
    reg done_storing;
    reg copied_io_regs;
    reg [31:0] input_value;
    reg input_value_valid;
    
    wire done, io_stall, waiting_for_input;
    wire [31:0] out_reg1, out_reg2, out_reg3, out_reg4, total_cycles, proc_cycles;
    wire [2:0] io_reg_index_out;

    Computer7 comp(
        .reset(reset), .ins_addr(ins_addr), .ins(ins), .clk(clk),
        .done_storing(done_storing), .copied_io_regs(copied_io_regs),
        .input_value(input_value), .input_value_valid(input_value_valid),
        .done(done), .out_reg1(out_reg1), .out_reg2(out_reg2),
        .out_reg3(out_reg3), .out_reg4(out_reg4),
        .total_cycles(total_cycles), .proc_cycles(proc_cycles),
        .io_stall(io_stall), .io_reg_index_out(io_reg_index_out),
        .waiting_for_input(waiting_for_input)
    );

    initial begin
        clk = 0; forever #5 clk = ~clk;
    end

    initial begin
        reset = 1; done_storing = 0; copied_io_regs = 0;
        input_value = 0; input_value_valid = 0;
        #20 reset = 0;
        
        // 0: LUI $1, 0x1234      -> 3c011234
        ins_addr = 0; ins = 32'h3c011234; #10;
        // 1: ORI $1, $1, 0x5678  -> 34215678 (Register 1 now holds 0x12345678)
        ins_addr = 1; ins = 32'h34215678; #10;
        
        // 2: SW $1, 512($0)      -> ac010200 (Stores 0x12345678 at Byte Addr 512 / Word Addr 128)
        ins_addr = 2; ins = 32'hac010200; #10;
        
        // 3: LB $2, 513($0)      -> 80020201 (Loads byte at offset 1 from word. Since Big-Endian, 513 corresponds to 0x34)
        ins_addr = 3; ins = 32'h80020201; #10;
        
        // 4: ADDI $3, $0, 1004   -> 200303ec (Print Syscall ID)
        ins_addr = 4; ins = 32'h200303ec; #10;
        // 5: SYSCALL $3, $2      -> 0062000c (Print contents of $2)
        ins_addr = 5; ins = 32'h0062000c; #10;
        
        // 6: ADDI $3, $0, 1001   -> 200303e9 (Exit Syscall ID)
        ins_addr = 6; ins = 32'h200303e9; #10;
        // 7: SYSCALL $3, $0      -> 0060000c (Exit)
        ins_addr = 7; ins = 32'h0060000c; #10;

        done_storing = 1;
        

        // Wait for exit stall
        wait(done);
        $display("==================================================");
        $display("Loaded Byte value (Expected 0x34 or 52 in dec): %d", out_reg1);
        $display("Execution Finished. Cycles: %d", proc_cycles);
        $display("==================================================");
        $finish;
    end
endmodule