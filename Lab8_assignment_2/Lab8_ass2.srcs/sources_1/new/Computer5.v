`timescale 1ns/1ps
`include "defs.vh"

module Computer(
    input         reset,
    input  [7:0]  ins_addr,
    input  [31:0] ins,
    input         clk,
    input         done_storing,
    input         copied_io_regs,
    output reg    done,
    output [31:0] out_reg1,
    output [31:0] out_reg2,
    output [31:0] out_reg3,
    output [31:0] out_reg4,
    output [31:0] total_cycles,
    output [31:0] proc_cycles,
    output        io_stall,
    output [2:0]  io_reg_index_out
);
    wire [7:0]  pc;
    wire [31:0] ins_fetched;
    wire        ins_mem_command;
    reg  [31:0] counter_total;
    reg  [31:0] counter_proc;
    wire        halt;
    wire        io_stall_wire;
    
    assign io_stall = io_stall_wire;

    Memory mem(
        ~reset & ~done_storing, clk, ins_mem_command,
        done_storing ? pc : ins_addr, ins, ins_fetched
    );

    Processor5 proc(
        .clk              (clk),
        .halt             (halt),
        .reset            (~done_storing),
        .pc               (pc),
        .ins              (ins_fetched),
        .io_reg1          (out_reg1),
        .io_reg2          (out_reg2),
        .io_reg3          (out_reg3),
        .io_reg4          (out_reg4),
        .copied_io_regs   (copied_io_regs),
        .io_stall         (io_stall_wire),
        .io_reg_index_out (io_reg_index_out)
    );

    assign total_cycles    = counter_total;
    assign proc_cycles     = counter_proc;
    assign ins_mem_command = done_storing ? `READ_COMMAND : `WRITE_COMMAND;

    always @(posedge clk) begin
        if (reset) begin
            counter_total <= 32'b0;
            counter_proc  <= 32'b0;
            done          <= 1'b0;
        end else begin
            done          <= done_storing & halt;
            counter_total <= counter_total + 1;
            counter_proc  <= done_storing ? (halt ? counter_proc : counter_proc + 1) : counter_proc;
        end
    end
endmodule