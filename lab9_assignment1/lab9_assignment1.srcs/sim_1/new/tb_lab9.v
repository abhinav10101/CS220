`timescale 1ns / 1ps
`include "defs.vh"

module tb_Assignment1;

    // Inputs to Computer
    reg clk;
    reg reset;
    reg [7:0] ins_addr;
    reg [31:0] ins;
    reg done_storing;
    reg copied_io_regs;
    reg [31:0] input_value;
    reg input_value_valid;

    // Outputs from Computer
    wire done;
    wire [31:0] out_reg1, out_reg2, out_reg3, out_reg4;
    wire [31:0] total_cycles, proc_cycles;
    wire io_stall;
    wire [2:0] io_reg_index_out;
    wire waiting_for_input;

    // Instantiate the Computer module
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

    integer input_counter = 0;

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

        // 2. Load the Program into Memory
        // C Code:
        // int x, y, z;
        // input x; 
        // input y; 
        // z = x + y; 
        // print z; 
        // exit();

        // 0: addi $1, $0, 1003  ($1 = SYS_read)
        ins_addr = 8'd0; ins = 32'h200103eb; #10;
        
        // 1: syscall $1, $2     (x = input, stored in $2)
        ins_addr = 8'd1; ins = 32'h0020100c; #10;
        
        // 2: syscall $1, $3     (y = input, stored in $3)
        // Note: $1 still holds 1003, no need to reload it
        ins_addr = 8'd2; ins = 32'h0020180c; #10;
        
        // 3: add $4, $2, $3     (z = x + y)
        ins_addr = 8'd3; ins = 32'h00432020; #10;
        
        // 4: addi $1, $0, 1004  ($1 = SYS_write)
        ins_addr = 8'd4; ins = 32'h200103ec; #10;
        
        // 5: syscall $1, $4     (print $4)
        ins_addr = 8'd5; ins = 32'h0024000c; #10;
        
        // 6: addi $1, $0, 1001  ($1 = SYS_exit)
        ins_addr = 8'd6; ins = 32'h200103e9; #10;
        
        // 7: syscall $1, $0     (exit)
        ins_addr = 8'd7; ins = 32'h0020000c; #10;

        // Signal that program loading is complete
        done_storing = 1;
        $display("--- Program Loaded. Starting Execution ---");
    end

    // 3. Environment Handshake Logic (Runs concurrently with the clock)
    always @(posedge clk) begin
        if (done_storing && !done) begin
            
            // --- INPUT HANDSHAKE (SYS_read) ---
            if (waiting_for_input && !input_value_valid) begin
                if (input_counter == 0) begin
                    input_value <= 32'd15; // Set x = 15 [cite: 57]
                    $display("[%0t] TB: Providing first input (x) = 15", $time);
                end else begin
                    input_value <= 32'd25; // Set y = 25 [cite: 57]
                    $display("[%0t] TB: Providing second input (y) = 25", $time);
                end
                input_value_valid <= 1'b1; // Signal valid data [cite: 57]
            end else if (!waiting_for_input && input_value_valid) begin
                input_value_valid <= 1'b0; // Processor resumed, drop signal [cite: 58]
                input_counter <= input_counter + 1;
            end
            
            // --- OUTPUT HANDSHAKE (SYS_write) ---
            if (io_stall && !copied_io_regs) begin
                $display("[%0t] TB: Output received (z) = %d", $time, out_reg1);
                copied_io_regs <= 1'b1;
            end else if (!io_stall && copied_io_regs) begin
                copied_io_regs <= 1'b0;
            end
        end
    end

    // 4. End of Simulation
   always @(posedge clk) begin
        if (done) begin
            $display("--- Execution Complete ---");
            
            // NEW: Flush and print any outputs left in the buffer!
            if (io_reg_index_out > 0) begin
                $display("TB: Buffered Output received (z) = %d", out_reg1);
            end
            
            $display("Total Cycles: %d", total_cycles);
            $display("Processor Cycles: %d", proc_cycles);
            $finish;
        end
    end
endmodule