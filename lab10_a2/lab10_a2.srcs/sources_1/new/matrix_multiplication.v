`timescale 1ns / 1ps

module matrix_vec_accel_core(
    input wire clk,
    input wire [3:0] row_id,      
    input wire [3:0] col_id,      
    input wire [31:0] value,      
    input wire vector_id,         
    input wire input_done,        
    input wire [3:0] index,       
    input wire start_arm,         
    input wire stop_arm,          
    
    output wire [31:0] y_val,      
    output reg done = 0,              
    output reg [31:0] arm_cycles = 0  
);

    reg [31:0] M [0:15][0:15]; 
    reg [31:0] x [0:15];       
    reg [31:0] y [0:15];       
    reg [31:0] v [0:15];       
    reg [31:0] w [0:15];       
    
    reg [3:0] state = 0;
    reg [4:0] current_row = 0;

    assign y_val = y[index];

    always @(posedge clk) begin
        if (state == 0) begin
            done <= 0;
            if (vector_id == 0) M[row_id][col_id] <= value;
            else x[row_id] <= value;
            
            if (input_done) state <= 1; 
        end
        else if (state == 1) begin
            state <= 2; 
        end
        else if (state >= 2 && state <= 6) begin
            state <= state + 1; 
        end
        else if (state == 7) begin
            y[current_row] <= w[0]; 
            if (current_row < 15) begin
                current_row <= current_row + 1; 
                state <= 1;
            end else begin
                state <= 8;
                done <= 1;
            end
        end
        else if (state == 8) begin
            if (start_arm && !stop_arm) arm_cycles <= arm_cycles + 1; 
        end
    end

    genvar i;
    generate
        for (i=0; i<16; i=i+1) begin: update_logic
            always @(posedge clk) begin
                // Update v array
                if (state == 1) begin
                    v[i] <= M[current_row][i]; 
                end
                
                // Update w array
                if (state == 2) begin
                    w[i] <= v[i] * x[i];
                end
                else if (state == 3 && i < 8) begin
                    w[i] <= w[i+i] + w[i+i+1];
                end
                else if (state == 4 && i < 4) begin
                    w[i] <= w[i+i] + w[i+i+1];
                end
                else if (state == 5 && i < 2) begin
                    w[i] <= w[i+i] + w[i+i+1];
                end
                else if (state == 6 && i == 0) begin
                    w[i] <= w[0] + w[1];
                end
            end
        end
    endgenerate

endmodule