`timescale 1ns / 1ps

module tb_vector_accel_core();
    reg clk;
    reg [8:0] index;
    reg [31:0] value;
    reg vector_id;
    reg input_done;
    reg start_arm;
    reg stop_arm;

    wire [31:0] reduction_result;
    wire done;
    wire [31:0] arm_cycles;

    // Instantiate DUT [cite: 469, 470]
    vector_add dut (
        .clk(clk),
        .index(index),
        .value(value),
        .vector_id(vector_id),
        .input_done(input_done),
        .start_arm(start_arm),
        .stop_arm(stop_arm),
        .reduction_result(reduction_result),
        .done(done),
        .arm_cycles(arm_cycles)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    integer i;
    integer val_in0, val_in1;
    integer expected_arm_result;

    initial begin
        // Initialize Inputs [cite: 129]
        index = 0;
        value = 0;
        vector_id = 0;
        input_done = 0;
        start_arm = 0;
        stop_arm = 0;
        expected_arm_result = 0;

        #100;
        
        // Feed vector 0 and vector 1 [cite: 136]
        for (i = 0; i < 512; i = i + 1) begin
            // Generate random values between -5 and 4 [cite: 138, 145]
            val_in0 = 1;
            val_in1 = 2;
            
            // Calculate expected ARM result 
            expected_arm_result = expected_arm_result + val_in0 + val_in1;

            // Send vector 0 element
            vector_id = 0;
            index = i;
            value = val_in0;
            #10;
            
            // Send vector 1 element
            vector_id = 1;
            value = val_in1;
            #10;
        end

        // Start computation [cite: 149]
        input_done = 1;
        #10;
        input_done = 0;

        // Wait for FPGA to finish [cite: 155]
        wait(done == 1'b1);
        #10;
        
        $display("FPGA out: %d", reduction_result);
        $display("ARM out: %d", expected_arm_result);
        
        if (reduction_result == expected_arm_result)
            $display("Test Passed: Results match!");
        else
            $display("Test Failed: Results do not match.");

        $finish;
    end
endmodule