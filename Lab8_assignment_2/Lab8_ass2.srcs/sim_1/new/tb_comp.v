`timescale 1ns / 1ps

`include "defs.vh"

module tb_Lab8_Assignment2;

    // Inputs

    reg clk;

    reg reset;

    reg [7:0] ins_addr;

    reg [31:0] ins;

    reg done_storing;

    reg copied_io_regs;

    // Lab 9 additions (tied off for Lab 8)

    reg [31:0] input_value;

    reg input_value_valid;

    // Outputs

    wire done;

    wire [31:0] out_reg1, out_reg2, out_reg3, out_reg4;

    wire [31:0] total_cycles, proc_cycles;

    wire io_stall;

    wire [2:0] io_reg_index_out;

    wire waiting_for_input;

    // Instantiate your Lab 9 Computer

    Computer uut (

        .reset(reset),

        .ins_addr(ins_addr),

        .ins(ins),

        .clk(clk),

        .done_storing(done_storing),

        .copied_io_regs(copied_io_regs),

        .input_value(input_value),

        .input_value_valid(input_value_valid),

        .done(done),

        .out_reg1(out_reg1),

        .out_reg2(out_reg2),

        .out_reg3(out_reg3),

        .out_reg4(out_reg4),

        .total_cycles(total_cycles),

        .proc_cycles(proc_cycles),

        .io_stall(io_stall),

        .io_reg_index_out(io_reg_index_out),

        .waiting_for_input(waiting_for_input)

    );

    // Clock generation

    initial begin

        clk = 0;

        forever #5 clk = ~clk;

    end

    integer print_count = 1;

    initial begin

        // 1. Initialize Inputs

        reset = 1;

        ins_addr = 0;

        ins = 0;

        done_storing = 0;

        copied_io_regs = 0;

        input_value = 0;

        input_value_valid = 0;

        #20 reset = 0;

        // 2. Load the C Program into Memory

        // C Code:

        // int i=0, x=10, N=30;

        // for (i=0; i<N; i++) {

        // if ((i & 0x1) == 0) { x += f(x,i); print x; }

        // else { x -= f(x,i); print x; }

        // } exit();

        // int f(int a, int b) { return a+b; }

        // --- Initialization ---

        // 0: addi $2, $0, 10 (x = 10)

        ins_addr = 8'd0; ins = 32'h2002000a; #10;

        // 1: addi $3, $0, 0 (i = 0)

        ins_addr = 8'd1; ins = 32'h20030000; #10;

        // 2: addi $4, $0, 30 (N = 30)

        ins_addr = 8'd2; ins = 32'h2004001e; #10;

        // --- Loop Condition ---

        // 3: slt $5, $3, $4 ($5 = (i < N))

        ins_addr = 8'd3; ins = 32'h0064282a; #10;

        // 4: beq $5, $0, 18 (if $5 == 0, jump to exit at PC = 4+18 = 22)

        ins_addr = 8'd4; ins = 32'h10a00012; #10;

        // --- If/Else Check ---

        // 5: andi $5, $3, 1 ($5 = i & 1)

        ins_addr = 8'd5; ins = 32'h30650001; #10;

        // 6: bne $5, $0, 8 (if $5 != 0, jump to else at PC = 6+8 = 14)

        ins_addr = 8'd6; ins = 32'h14a00008; #10;

        // --- Then Block ((i & 1) == 0) ---

        // 7: add $6, $2, $0 (arg a = x)

        ins_addr = 8'd7; ins = 32'h00403020; #10;

        // 8: add $7, $3, $0 (arg b = i)

        ins_addr = 8'd8; ins = 32'h00603820; #10;

        // 9: jal 24 (call f(a,b), target = 24)

        ins_addr = 8'd9; ins = 32'h0c000018; #10;

        // 10: add $2, $2, $8 (x += f(x,i))

        ins_addr = 8'd10; ins = 32'h00481020; #10;

        // 11: addi $1, $0, 1004 (syscall ID for print)

        ins_addr = 8'd11; ins = 32'h200103ec; #10;

        // 12: syscall $1, $2 (print x)

        ins_addr = 8'd12; ins = 32'h0022000c; #10;

        // 13: j 20 (jump to loop increment)

        ins_addr = 8'd13; ins = 32'h08000014; #10;

        // --- Else Block ---

        // 14: add $6, $2, $0 (arg a = x)

        ins_addr = 8'd14; ins = 32'h00403020; #10;

        // 15: add $7, $3, $0 (arg b = i)

        ins_addr = 8'd15; ins = 32'h00603820; #10;

        // 16: jal 24 (call f(a,b), target = 24)

        ins_addr = 8'd16; ins = 32'h0c000018; #10;

        // 17: sub $2, $2, $8 (x -= f(x,i))

        ins_addr = 8'd17; ins = 32'h00481022; #10;

        // 18: addi $1, $0, 1004 (syscall ID for print)

        ins_addr = 8'd18; ins = 32'h200103ec; #10;

        // 19: syscall $1, $2 (print x)

        ins_addr = 8'd19; ins = 32'h0022000c; #10;

        // --- Loop Increment ---

        // 20: addi $3, $3, 1 (i++)

        ins_addr = 8'd20; ins = 32'h20630001; #10;

        // 21: j 3 (jump to loop condition)

        ins_addr = 8'd21; ins = 32'h08000003; #10;

        // --- Exit ---

        // 22: addi $1, $0, 1001 (syscall ID for exit)

        ins_addr = 8'd22; ins = 32'h200103e9; #10;

        // 23: syscall $1, $0 (exit)

        ins_addr = 8'd23; ins = 32'h0020000c; #10;

        // --- Function f(a, b) ---

        // 24: add $8, $6, $7 (return a + b)

        ins_addr = 8'd24; ins = 32'h00c74020; #10;

        // 25: jr $31 (return to caller)

        ins_addr = 8'd25; ins = 32'h03e00008; #10;

        done_storing = 1;

        $display("--- Program Loaded. Starting Execution ---");

    end

    // 3. Environment Handshake (Handles Unlimited Prints)

    always @(posedge clk) begin

        if (done_storing && !done) begin

            if (io_stall && !copied_io_regs) begin

                $display("[%0t] TB: Register full! Flushing 4 prints:", $time);

                $display(" Print %d: %d", print_count, out_reg1);

                $display(" Print %d: %d", print_count+1, out_reg2);

                $display(" Print %d: %d", print_count+2, out_reg3);

                $display(" Print %d: %d", print_count+3, out_reg4);

                print_count <= print_count + 4;

                copied_io_regs <= 1'b1; // Tell CPU to resume

            end else if (!io_stall && copied_io_regs) begin

                copied_io_regs <= 1'b0; // Drop signal once CPU unstalls

            end

        end

    end

    // 4. End of Simulation

    always @(posedge clk) begin

        if (done) begin

            $display("--- Execution Complete ---");

            // Flush remaining prints left in the buffer

            if (io_reg_index_out > 0) $display(" Print %d: %d", print_count, out_reg1);

            if (io_reg_index_out > 1) $display(" Print %d: %d", print_count+1, out_reg2);

            if (io_reg_index_out > 2) $display(" Print %d: %d", print_count+2, out_reg3);

            if (io_reg_index_out > 3) $display(" Print %d: %d", print_count+3, out_reg4);

            $display("Total Cycles: %d", total_cycles);

            $display("Processor Cycles: %d", proc_cycles);

            $finish;

        end

    end

endmodule