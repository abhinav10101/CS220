`timescale 1ns / 1ps
`include "defs.vh"

module tb_computer;

    reg         clk;
    reg         reset;
    reg  [7:0]  ins_addr;
    reg  [31:0] ins;
    reg         done_storing;
    reg         copied_io_regs;

    wire        done;
    wire [31:0] out_reg1, out_reg2, out_reg3, out_reg4;
    wire [31:0] total_cycles, proc_cycles;
    wire        io_stall;
    wire [2:0]  io_reg_index_out;

    // Instantiate Computer
    Computer uut (
        .clk(clk),
        .reset(reset),
        .ins_addr(ins_addr),
        .ins(ins),
        .done_storing(done_storing),
        .copied_io_regs(copied_io_regs),
        .done(done),
        .out_reg1(out_reg1),
        .out_reg2(out_reg2),
        .out_reg3(out_reg3),
        .out_reg4(out_reg4),
        .total_cycles(total_cycles),
        .proc_cycles(proc_cycles),
        .io_stall(io_stall),
        .io_reg_index_out(io_reg_index_out)
    );

    always #5 clk = ~clk;

    integer print_count = 1;

    initial begin
        clk = 0;
        reset = 1;
        done_storing = 0;
        copied_io_regs = 0;
        ins_addr = 0;
        ins = 0;
        
        #20 reset = 0;

        // --- LOAD INSTRUCTIONS ---
        // Translated from the C code in the Lab Document
        load_inst(0, 32'h200103ec); // addi r1, r0, 1004 (SYS_write value)
        load_inst(1, 32'h2002fff6); // addi r2, r0, -10  (x = -10)
        load_inst(2, 32'h20420001); // addi r2, r2, 1    (x++)
        load_inst(3, 32'h0022000c); // syscall (print x) #1
        load_inst(4, 32'h00021280); // sll r2, r2, 10    (x = x << 10)
        load_inst(5, 32'h0022000c); // syscall (print x) #2
        load_inst(6, 32'h000210c3); // sra r2, r2, 3     (x = x >> 3)
        load_inst(7, 32'h0022000c); // syscall (print x) #3
        load_inst(8, 32'h2042ffff); // addi r2, r2, -1   (x--)
        load_inst(9, 32'h0022000c); // syscall (print x) #4
        load_inst(10, 32'h2043ffff); // addi r3, r2, -1  (r3 = x - 1)
        load_inst(11, 32'h00431024); // and r2, r2, r3   (x = x & (x-1))
        load_inst(12, 32'h0022000c); // syscall (print x) #5 (SHOULD STALL HERE)
        load_inst(13, 32'h20430001); // addi r3, r2, 1   (r3 = x + 1)
        load_inst(14, 32'h00431025); // or r2, r2, r3    (x = x | (x+1))
        load_inst(15, 32'h0022000c); // syscall (print x) #6
        load_inst(16, 32'h200103e9); // addi r1, r0, 1001 (SYS_exit value)
        load_inst(17, 32'h0020000c); // syscall (exit)

        #10;
        done_storing = 1;

        // --- EXECUTION & HANDSHAKING ---
        while (!done) begin
            @(posedge clk);
            
            // Environment detects stall on the 5th print
            if (io_stall) begin
                $display("\n--- IO STALL DETECTED ---");
                $display("out%0d = %0d", print_count,   $signed(out_reg1));
                $display("out%0d = %0d", print_count+1, $signed(out_reg2));
                $display("out%0d = %0d", print_count+2, $signed(out_reg3));
                $display("out%0d = %0d", print_count+3, $signed(out_reg4));
                print_count = print_count + 4;
                
                // Assert copied signal
                copied_io_regs = 1;
                
                // Wait for processor to lower io_stall
                wait(!io_stall);
                @(posedge clk);
                
                // Deassert copied signal
                copied_io_regs = 0;
            end
        end

        // --- PROGRAM DONE: CHECK RESIDUAL PRINTS ---
        $display("\n--- PROGRAM DONE ---");
        if (io_reg_index_out > 0) $display("out%0d = %0d (Residual)", print_count,   $signed(out_reg1));
        if (io_reg_index_out > 1) $display("out%0d = %0d (Residual)", print_count+1, $signed(out_reg2));
        if (io_reg_index_out > 2) $display("out%0d = %0d (Residual)", print_count+2, $signed(out_reg3));
        if (io_reg_index_out > 3) $display("out%0d = %0d (Residual)", print_count+3, $signed(out_reg4));

        $display("\nTotal Cycles: %0d | Proc Cycles: %0d", total_cycles, proc_cycles);
        $finish;
    end

    // Helper task to push instructions to memory
    task load_inst(input [7:0] addr, input [31:0] inst);
        begin
            ins_addr = addr;
            ins = inst;
            #10;
        end
    endtask

endmodule