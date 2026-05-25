`timescale 1ns / 1ps

module vector_add (
    input wire clk,
    input wire [8:0] index,       
    input wire [31:0] value,      
    input wire vector_id,         
    input wire input_done,        
    input wire start_arm,         
    input wire stop_arm,          
    
    output wire [31:0] reduction_result, 
    output reg done = 0,                    
    output reg [31:0] arm_cycles = 0        
);

    reg [31:0] v0 [0:511];
    reg [31:0] v1 [0:511];
    reg [31:0] v2 [0:511]; 

    reg [3:0] state = 0;
    
    assign reduction_result = v2[0];

    always @(posedge clk) begin
        if (state == 0) begin
            done <= 0;
            if (vector_id == 0) v0[index] <= value;
            else v1[index] <= value;
            
            if (input_done) state <= 1;
        end
        else if (state >= 1 && state <= 10) begin
            state <= state + 1; 
        end
        else if (state == 11) begin
            done <= 1;
            if (start_arm && !stop_arm) arm_cycles <= arm_cycles + 1;
        end
    end

    genvar i;
    generate 
        // Single always block per index to prevent Multiple Driver Errors
        for (i = 0; i < 512; i = i + 1) begin: v2_update_logic
            always @(posedge clk) begin
                if (state == 1) begin
                    v2[i] <= v0[i] + v1[i];
                end
                else if (state == 2 && i < 256) begin
                    v2[i] <= v2[i+i] + v2[i+i+1];
                end
                else if (state == 3 && i < 128) begin
                    v2[i] <= v2[i+i] + v2[i+i+1];
                end
                else if (state == 4 && i < 64) begin
                    v2[i] <= v2[i+i] + v2[i+i+1];
                end
                else if (state == 5 && i < 32) begin
                    v2[i] <= v2[i+i] + v2[i+i+1];
                end
                else if (state == 6 && i < 16) begin
                    v2[i] <= v2[i+i] + v2[i+i+1];
                end
                else if (state == 7 && i < 8) begin
                    v2[i] <= v2[i+i] + v2[i+i+1];
                end
                else if (state == 8 && i < 4) begin
                    v2[i] <= v2[i+i] + v2[i+i+1];
                end
                else if (state == 9 && i < 2) begin
                    v2[i] <= v2[i+i] + v2[i+i+1];
                end
                else if (state == 10 && i == 0) begin
                    v2[i] <= v2[0] + v2[1];
                end
            end
        end
    endgenerate

endmodule