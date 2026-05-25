`timescale 1ns / 1ps
`include "defs.vh"

module Processor7(
    input         clk,
    output        halt,
    input         reset,
    output reg [7:0] pc,
    input  [31:0] ins,
    output [31:0] io_reg1,
    output [31:0] io_reg2,
    output [31:0] io_reg3,
    output [31:0] io_reg4,
    input         copied_io_regs,
    input  [31:0] input_value,
    input         input_value_valid,
    output reg    io_stall,
    output [2:0]  io_reg_index_out,
    output        waiting_for_input,
    // --- Assignment 2 Memory Interface ---
    output [7:0]  data_addr,
    output        data_addr_valid,
    output [1:0]  data_mem_command,
    output [31:0] store_value,
    input  [31:0] load_value
);

    reg [1:0]  state;

    // Mask instruction during execution to kill false paths from memory
    wire [31:0] safe_ins = (state == 2'd0) ? ins : 32'd0;

    wire [5:0]  opcode       = safe_ins[31:26];
    wire [4:0]  src1_addr    = safe_ins[25:21];
    wire [4:0]  src2_addr    = safe_ins[20:16];
    wire [4:0]  shift_amount = safe_ins[10:6];
    wire [5:0]  func         = safe_ins[5:0];
    wire [15:0] imm          = safe_ins[15:0];
    wire [4:0]  dest_addr    = (opcode == `OP_JAL || (opcode == `OP_REG && func == `FUNC_JALR)) ? 5'd31 :
                               (opcode == `OP_REG) ? safe_ins[15:11] : safe_ins[20:16];

    wire [31:0] branch_offset_wire = (opcode == `OP_J || opcode == `OP_JAL) ? {6'b0, safe_ins[25:0]} : {{16{imm[15]}}, imm};
    wire [31:0] imm_ext = (opcode == `OP_ANDI || opcode == `OP_ORI || opcode == `OP_XORI) ? {16'b0, imm} : {{16{imm[15]}}, imm};

    wire [31:0] src1;
    wire [31:0] src2_rf;
    
    wire use_rf_for_src2 = (opcode == `OP_REG) || (opcode == `OP_BEQ) || (opcode == `OP_BNE) ||
                           (opcode == `OP_SB)  || (opcode == `OP_SH)  || (opcode == `OP_SW);
    wire [31:0] src2 = use_rf_for_src2 ? src2_rf : imm_ext;

    wire [31:0] dest_data;
    wire        dest_data_valid;
    wire        alu_branch_taken;

    reg [5:0]  s1_opcode;
    reg [5:0]  s1_func;
    reg [4:0]  s1_shift_amount;
    reg [31:0] s1_src1;
    reg [31:0] s1_src2;
    reg [4:0]  s1_dest_addr;
    reg [7:0]  s1_pc;             
    reg [31:0] s1_branch_offset;
    reg [4:0]  s1_rt;             

    reg [4:0]  wb_addr;
    reg [31:0] wb_data;
    reg        wb_enable;

    reg        fetched;
    reg        exit_detected;
    reg        halt_reg;
    assign     halt = halt_reg;

    reg [31:0] io_reg [0:3];
    reg [2:0]  io_reg_index;
    reg        will_stall;
    reg        prev_copied_io_regs;

    reg        waiting_for_input_reg;
    reg        sys_read_in_progress;
    reg [31:0] captured_input;
    assign     waiting_for_input = waiting_for_input_reg;

    assign io_reg1          = io_reg[0];
    assign io_reg2          = io_reg[1];
    assign io_reg3          = io_reg[2];
    assign io_reg4          = io_reg[3];
    assign io_reg_index_out = io_reg_index;

    // ==========================================
    // --- Assignment 2 Combinational Logic ---
    // ==========================================
    wire is_load  = (s1_opcode == `OP_LB) || (s1_opcode == `OP_LH) || (s1_opcode == `OP_LW) || (s1_opcode == `OP_LBU) || (s1_opcode == `OP_LHU);
    wire is_store = (s1_opcode == `OP_SB) || (s1_opcode == `OP_SH) || (s1_opcode == `OP_SW);

    wire data_addr_valid_wire = (state == 2'd1) && (is_load || is_store);
    assign data_addr_valid    = data_addr_valid_wire;
    
    // =========================================================================
    // TIMING OPTIMIZATION: Bypass the ALU for memory addresses.
    // We use a dedicated, fast adder just for memory lookups. This drops the 
    // logic levels dramatically and clears the critical path timing failure.
    // =========================================================================
    wire [31:0] fast_mem_addr = s1_src1 + s1_branch_offset;
    assign data_addr          = data_addr_valid_wire ? fast_mem_addr[9:2] : 8'd0;
    
    assign data_mem_command   = is_load ? `READ_COMMAND : (s1_opcode == `OP_SW) ? `WRITE_COMMAND : `SUBWORD_WRITE_COMMAND;

    // Use the fast adder for byte extraction as well
    wire [1:0] byte_offset = fast_mem_addr[1:0];

    reg [31:0] next_store_value;
    always @(*) begin
        next_store_value = s1_src2; 
        if (s1_opcode == `OP_SB) begin
            case (byte_offset)
                2'b00: next_store_value = {s1_src2[7:0], load_value[23:0]};
                2'b01: next_store_value = {load_value[31:24], s1_src2[7:0], load_value[15:0]};
                2'b10: next_store_value = {load_value[31:16], s1_src2[7:0], load_value[7:0]};
                2'b11: next_store_value = {load_value[31:8], s1_src2[7:0]};
            endcase
        end else if (s1_opcode == `OP_SH) begin
            case (byte_offset[1])
                1'b0: next_store_value = {s1_src2[15:0], load_value[15:0]};
                1'b1: next_store_value = {load_value[31:16], s1_src2[15:0]};
            endcase
        end
    end
    
    assign store_value = data_addr_valid_wire ? next_store_value : 32'd0;

    reg [31:0] extracted_load;
    always @(*) begin
        extracted_load = load_value; 
        if (s1_opcode == `OP_LB) begin
            case (byte_offset)
                2'b00: extracted_load = {{24{load_value[31]}}, load_value[31:24]};
                2'b01: extracted_load = {{24{load_value[23]}}, load_value[23:16]};
                2'b10: extracted_load = {{24{load_value[15]}}, load_value[15:8]};
                2'b11: extracted_load = {{24{load_value[7]}}, load_value[7:0]};
            endcase
        end else if (s1_opcode == `OP_LBU) begin
            case (byte_offset)
                2'b00: extracted_load = {24'b0, load_value[31:24]};
                2'b01: extracted_load = {24'b0, load_value[23:16]};
                2'b10: extracted_load = {24'b0, load_value[15:8]};
                2'b11: extracted_load = {24'b0, load_value[7:0]};
            endcase
        end else if (s1_opcode == `OP_LH) begin
            case (byte_offset[1])
                1'b0: extracted_load = {{16{load_value[31]}}, load_value[31:16]};
                1'b1: extracted_load = {{16{load_value[15]}}, load_value[15:0]};
            endcase
        end else if (s1_opcode == `OP_LHU) begin
            case (byte_offset[1])
                1'b0: extracted_load = {16'b0, load_value[31:16]};
                1'b1: extracted_load = {16'b0, load_value[15:0]};
            endcase
        end
    end

    RegisterFile rf (
        .read_addr1   (src1_addr),
        .read_addr2   (src2_addr),
        .read_data1   (src1),
        .read_data2   (src2_rf),
        .write_addr   (wb_addr),
        .write_data   (wb_data),
        .write_enable (wb_enable & fetched & (state == 2'd2)),
        .clk          (clk)
    );

    ALU7 alu (
        .src1         (s1_src1),
        .src2         (s1_src2),
        .shift_amount (s1_shift_amount),
        .opcode       (s1_opcode),
        .func         (s1_func),
        .pc           (s1_pc),            
        .branch_offset(s1_branch_offset), 
        .rt           (s1_rt),            
        .dest         (dest_data),
        .dest_valid   (dest_data_valid),
        .branch_taken (alu_branch_taken)  
    );

    always @(posedge clk) begin
        if (reset) begin
            pc                    <= 8'b0;
            state                 <= 2'd0;
            fetched               <= 1'b0;
            wb_enable             <= 1'b0;
            halt_reg              <= 1'b0;
            exit_detected         <= 1'b0;
            io_reg_index          <= 3'b0;
            io_stall              <= 1'b0;
            will_stall            <= 1'b0;
            prev_copied_io_regs   <= 1'b0;
            io_reg[0]             <= 32'b0;
            io_reg[1]             <= 32'b0;
            io_reg[2]             <= 32'b0;
            io_reg[3]             <= 32'b0;
            s1_opcode             <= 6'b0;
            s1_func               <= 6'b0;
            s1_shift_amount       <= 5'b0;
            s1_src1               <= 32'b0;
            s1_src2               <= 32'b0;
            s1_dest_addr          <= 5'b0;
            s1_pc                 <= 8'b0;
            s1_branch_offset      <= 32'b0;
            s1_rt                 <= 5'b0;
            wb_addr               <= 5'b0;
            wb_data               <= 32'b0;
            waiting_for_input_reg <= 1'b0;
            sys_read_in_progress  <= 1'b0;
            captured_input        <= 32'b0;
        end else begin
            fetched <= 1'b1;
            prev_copied_io_regs <= copied_io_regs;

            case (state)
                2'd0: begin
                    if (!io_stall) begin
                        s1_opcode        <= opcode;
                        s1_func          <= func;
                        s1_shift_amount  <= shift_amount;
                        s1_src1          <= src1;
                        s1_src2          <= src2;
                        s1_dest_addr     <= dest_addr;
                        s1_pc            <= pc;
                        s1_branch_offset <= branch_offset_wire;
                        s1_rt            <= src2_addr;
                        state            <= 2'd1;
                    end
                end

                2'd1: begin
                    if (is_load) wb_data <= extracted_load;
                    else         wb_data <= dest_data;
                    
                    wb_addr   <= s1_dest_addr;
                    wb_enable <= dest_data_valid;

                    if ((s1_opcode == `OP_REG) && (s1_func == `FUNC_SYSCALL)) begin
                        if (s1_src1 == `SYS_write) begin
                            if (io_reg_index == 3'd4) begin
                                will_stall <= 1'b1;
                            end else begin
                                io_reg[io_reg_index] <= s1_src2;
                                io_reg_index <= io_reg_index + 1;
                            end
                            state <= 2'd2;
                        end 
                        else if (s1_src1 == `SYS_exit) begin
                            exit_detected <= 1'b1;
                            state <= 2'd2;
                        end 
                        else if (s1_src1 == `SYS_read) begin
                            if (!sys_read_in_progress) begin
                                waiting_for_input_reg <= 1'b1;
                                sys_read_in_progress  <= 1'b1;
                            end 
                            else if (waiting_for_input_reg && input_value_valid) begin
                                waiting_for_input_reg <= 1'b0;
                                captured_input        <= input_value;
                            end 
                            else if (!waiting_for_input_reg && !input_value_valid) begin
                                sys_read_in_progress  <= 1'b0;
                                wb_data               <= captured_input;
                                wb_addr               <= s1_dest_addr;
                                wb_enable             <= 1'b1;
                                state                 <= 2'd2;
                            end
                        end
                        else begin
                            state <= 2'd2;
                        end
                    end else begin
                        state <= 2'd2;
                    end
                end

                2'd2: begin
                    if (will_stall) begin
                        io_stall   <= 1'b1;
                        will_stall <= 1'b0;
                    end

                    if (exit_detected) begin
                        halt_reg      <= 1'b1;
                        exit_detected <= 1'b0;
                    end

                    if (!halt_reg && !exit_detected && !will_stall && !io_stall) begin
                        if (alu_branch_taken) begin
                            if (s1_opcode == `OP_JAL)
                                pc <= s1_branch_offset[7:0];
                            else if (s1_opcode == `OP_REG && s1_func == `FUNC_JALR)
                                pc <= s1_src1[7:0];
                            else
                                pc <= dest_data[7:0];
                        end else begin
                            pc <= pc + 8'd1;
                        end
                    end
                    state <= 2'd0;
                end

                default: state <= 2'd0;
            endcase

            if (copied_io_regs && !prev_copied_io_regs) begin
                io_stall     <= 1'b0;
                io_reg_index <= 3'b0;
            end
        end
    end
endmodule