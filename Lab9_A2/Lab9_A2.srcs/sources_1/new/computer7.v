`timescale 1ns / 1ps
`include "defs.vh"

module Computer7(
    input         reset,
    input  [7:0]  ins_addr,
    input  [31:0] ins,
    input         clk,
    input         done_storing,
    input         copied_io_regs,
    input  [31:0] input_value,
    input         input_value_valid,
    output reg    done,
    output [31:0] out_reg1,
    output [31:0] out_reg2,
    output [31:0] out_reg3,
    output [31:0] out_reg4,
    output [31:0] total_cycles,
    output [31:0] proc_cycles,
    output        io_stall,
    output [2:0]  io_reg_index_out,
    output        waiting_for_input 
);

    wire [7:0]  pc;
    wire [31:0] ins_fetched;
    reg  [31:0] counter_total;
    reg  [31:0] counter_proc;
    
    wire        halt;
    wire        io_stall_wire;
    
    assign io_stall = io_stall_wire;

    // --- Assignment 2 Memory Wires ---
    wire [7:0]  data_addr;
    wire        data_addr_valid;
    wire [1:0]  data_mem_command;
    wire [31:0] store_value;
    wire [31:0] load_value;
    
    // --- Multiplex Memory Array ---
    wire [7:0]  mem_addr = data_addr_valid ? data_addr : (done_storing ? pc : ins_addr);
    wire [1:0]  mem_cmd  = data_addr_valid ? data_mem_command : (done_storing ? `READ_COMMAND : `WRITE_COMMAND);
    wire [31:0] mem_in   = data_addr_valid ? store_value : ins;
    
    // --- FIX: Allow memory writes during execution if the processor commands a store ---
    wire is_processor_store = data_addr_valid && (data_mem_command == `WRITE_COMMAND || data_mem_command == `SUBWORD_WRITE_COMMAND);
    wire mem_we = ~reset && (~done_storing || is_processor_store);

    Memory2 mem(
        .write_enable(mem_we), 
        .clk(clk), 
        .command(mem_cmd),
        .address(mem_addr), 
        .word_in(mem_in), 
        .word_out(load_value)
    );
    
    assign ins_fetched = load_value;

    Processor7 proc(
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
        .input_value      (input_value),
        .input_value_valid(input_value_valid),
        .io_stall         (io_stall_wire),
        .io_reg_index_out (io_reg_index_out),
        .waiting_for_input(waiting_for_input),
        // --- Assignment 2 ---
        .data_addr        (data_addr),
        .data_addr_valid  (data_addr_valid),
        .data_mem_command (data_mem_command),
        .store_value      (store_value),
        .load_value       (load_value)
    );
    
    assign total_cycles    = counter_total;
    assign proc_cycles     = counter_proc;

    always @(posedge clk) begin
        if (reset) begin
            counter_total <= 32'b0;
            counter_proc  <= 32'b0;
            done          <= 1'b0;
        end else begin
            done          <= done_storing & halt;
            
            // Total cycles always ticks up to measure real-world time passed
            counter_total <= counter_total + 1;
            
            // TIMING FIX: Only increment computation cycles if NOT halted and NOT waiting for human/UART input
            if (done_storing && !halt && !waiting_for_input && !io_stall_wire) begin
                counter_proc <= counter_proc + 1;
            end
        end
    end
endmodule