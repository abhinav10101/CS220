`timescale 1ns / 1ps

module tb_matrix_vec_accel_core();
    reg clk;
    reg [3:0] row_id;
    reg [3:0] col_id;
    reg [31:0] value;
    reg vector_id;
    reg input_done;
    reg [3:0] index;
    reg start_arm;
    reg stop_arm;

    wire [31:0] y_val;
    wire done;
    wire [31:0] arm_cycles;

    // Instantiate DUT [cite: 491, 492]
    matrix_vec_accel_core dut (
        .clk(clk),
        .row_id(row_id),
        .col_id(col_id),
        .value(value),
        .vector_id(vector_id),
        .input_done(input_done),
        .index(index),
        .start_arm(start_arm),
        .stop_arm(stop_arm),
        .y_val(y_val),
        .done(done),
        .arm_cycles(arm_cycles)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    integer i, k;
    integer val_in;
    
    // Arrays for ARM verification [cite: 230]
    integer matrix_M[0:15][0:15];
    integer vector_x[0:15];
    integer arm_vector_y[0:15];

    initial begin
        row_id = 0; col_id = 0; value = 0; vector_id = 0;
        input_done = 0; index = 0; start_arm = 0; stop_arm = 0;

        #100;

        // Feed Matrix M (vector_id = 0) [cite: 236, 237]
        vector_id = 0;
        for (i = 0; i < 16; i = i + 1) begin
            for (k = 0; k < 16; k = k + 1) begin
                val_in = ($random % 10) - 5; // [cite: 238]
                matrix_M[i][k] = val_in;
                
                row_id = i;
                col_id = k;
                value = val_in;
                #10;
            end
        end

        // Feed Vector x (vector_id = 1) [cite: 250, 252]
        vector_id = 1;
        for (i = 0; i < 16; i = i + 1) begin
            val_in = ($random % 10) - 5; // [cite: 255]
            vector_x[i] = val_in;
            
            row_id = i;
            value = val_in;
            #10;
        end

        // Compute expected ARM result [cite: 274, 276, 277]
        for (i = 0; i < 16; i = i + 1) begin
            arm_vector_y[i] = 0;
            for (k = 0; k < 16; k = k + 1) begin
                arm_vector_y[i] = arm_vector_y[i] + (matrix_M[i][k] * vector_x[k]);
            end
        end

        // Start FPGA computation [cite: 259]
        input_done = 1;
        #10;
        input_done = 0;

        // Wait for completion [cite: 261]
        wait(done == 1'b1);
        #10;

        $display("FPGA vs ARM Results:");
        for (i = 0; i < 16; i = i + 1) begin
            index = i;
            #10; // Wait a cycle for y_val to update based on index
            $display("Index %0d | FPGA: %0d | ARM: %0d", i, y_val, arm_vector_y[i]); // [cite: 266, 285]
        end

        $finish;
    end
endmodule