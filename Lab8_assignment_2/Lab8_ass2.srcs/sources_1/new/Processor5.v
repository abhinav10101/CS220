`timescale 1ns / 1ps
`include "defs.vh"

module Processor5(
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
    output reg    io_stall,
    output [2:0]  io_reg_index_out
);

    wire [5:0]  opcode       = ins[31:26];
    wire [4:0]  src1_addr    = ins[25:21];
    wire [4:0]  src2_addr    = ins[20:16];
    wire [4:0]  shift_amount = ins[10:6];
    wire [5:0]  func         = ins[5:0];
    wire [15:0] imm          = ins[15:0];
    
    // NEW: Destination address logic (Forces '31' for JAL and JALR)
    wire [4:0]  dest_addr    = (opcode == `OP_JAL || (opcode == `OP_REG && func == `FUNC_JALR)) ? 5'd31 :
                               (opcode == `OP_REG) ? ins[15:11] : ins[20:16];

    // NEW: Branch offset computation (Sign extended imm OR zero-extended jump target)
    wire [31:0] branch_offset_wire = (opcode == `OP_J || opcode == `OP_JAL) ? 
                                     {6'b0, ins[25:0]} : {{16{imm[15]}}, imm};

    // Immediate extension for ANDI, ORI, XORI
    wire [31:0] imm_ext = (opcode == `OP_ANDI || opcode == `OP_ORI || opcode == `OP_XORI)
                          ? {16'b0, imm} : {{16{imm[15]}}, imm};

    wire [31:0] src1;
    wire [31:0] src2_rf;
    
    // Route the register file to src2 for R-Type AND conditional branches
    wire [31:0] src2 = (opcode == `OP_REG || opcode == `OP_BEQ || opcode == `OP_BNE) ? src2_rf : imm_ext;

    // ALU Wires
    wire [31:0] dest_data;
    wire        dest_data_valid;
    wire        alu_branch_taken; // NEW

    // Stage 1 Pipeline Registers
    reg [5:0]  s1_opcode;
    reg [5:0]  s1_func;
    reg [4:0]  s1_shift_amount;
    reg [31:0] s1_src1;
    reg [31:0] s1_src2;
    reg [4:0]  s1_dest_addr;
    reg [7:0]  s1_pc;             // NEW
    reg [31:0] s1_branch_offset;  // NEW
    reg [4:0]  s1_rt;             // NEW

    reg [4:0]  wb_addr;
    reg [31:0] wb_data;
    reg        wb_enable;

    reg [1:0]  state;
    reg        fetched;
    reg        exit_detected;
    reg        halt_reg;
    assign     halt = halt_reg;
    
    reg [31:0] io_reg [0:3];
    reg [2:0]  io_reg_index;
    reg        will_stall;
    reg        prev_copied_io_regs;

    assign io_reg1          = io_reg[0];
    assign io_reg2          = io_reg[1];
    assign io_reg3          = io_reg[2];
    assign io_reg4          = io_reg[3];
    assign io_reg_index_out = io_reg_index;

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

    ALU5 alu (
        .src1         (s1_src1),
        .src2         (s1_src2),
        .shift_amount (s1_shift_amount),
        .opcode       (s1_opcode),
        .func         (s1_func),
        .pc           (s1_pc),            // NEW
        .branch_offset(s1_branch_offset), // NEW
        .rt        (s1_rt),            // NEW
        .dest         (dest_data),
        .dest_valid   (dest_data_valid),
        .branch_taken (alu_branch_taken)  // NEW
    );

    always @(posedge clk) begin
        if (reset) begin
            pc            <= 8'b0;
            state         <= 2'd0;
            fetched       <= 1'b0;
            wb_enable     <= 1'b0;
            halt_reg      <= 1'b0;
            exit_detected <= 1'b0;
            io_reg_index  <= 3'b0;
            io_stall      <= 1'b0;
            will_stall    <= 1'b0;
            prev_copied_io_regs <= 1'b0;
            io_reg[0]     <= 32'b0;
            io_reg[1]     <= 32'b0;
            io_reg[2]     <= 32'b0;
            io_reg[3]     <= 32'b0;
            s1_opcode       <= 6'b0;
            s1_func         <= 6'b0;
            s1_shift_amount <= 5'b0;
            s1_src1         <= 32'b0;
            s1_src2         <= 32'b0;
            s1_dest_addr    <= 5'b0;
            s1_pc           <= 8'b0;
            s1_branch_offset<= 32'b0;
            s1_rt           <= 5'b0;
            wb_addr         <= 5'b0;
            wb_data         <= 32'b0;
        end else begin
            fetched <= 1'b1;
            prev_copied_io_regs <= copied_io_regs;

            case (state)
                // ── State 0: Fetch / Decode / Read RF ────────────────────────
                2'd0: begin
                    if (!io_stall) begin
                        s1_opcode        <= opcode;
                        s1_func          <= func;
                        s1_shift_amount  <= shift_amount;
                        s1_src1          <= src1;
                        s1_src2          <= src2;
                        s1_dest_addr     <= dest_addr;
                        s1_pc            <= pc;                  // Latch PC for target computation
                        s1_branch_offset <= branch_offset_wire;  // Latch jump/branch imm
                        s1_rt            <= src2_addr;           // Latch RT for bltz/bgez
                        state            <= 2'd1;
                    end
                end

                // ── State 1: Execute ──────────────────────────────────────────
                2'd1: begin
                    wb_data   <= dest_data;
                    wb_addr   <= s1_dest_addr;
                    wb_enable <= dest_data_valid;

                    if ((s1_opcode == `OP_REG) && (s1_func == `FUNC_SYSCALL) && (s1_src1 == `SYS_write)) begin
                        if (io_reg_index == 3'd4) begin
                            will_stall <= 1'b1;
                        end else begin
                            io_reg[io_reg_index] <= s1_src2;
                            io_reg_index <= io_reg_index + 1;
                        end
                    end

                    exit_detected <= ((s1_opcode == `OP_REG) && (s1_func == `FUNC_SYSCALL) && (s1_src1 == `SYS_exit));
                    state <= 2'd2;
                end

                // ── State 2: Write-Back & PC Update ───────────────────────────
                2'd2: begin
                    if (will_stall) begin
                        io_stall   <= 1'b1;
                        will_stall <= 1'b0;
                    end

                    if (exit_detected) begin
                        halt_reg      <= 1'b1;
                        exit_detected <= 1'b0;
                    end

                    // NEW: Update PC based on branch_taken and instruction type
                    if (!halt_reg && !exit_detected && !will_stall && !io_stall) begin
                        if (alu_branch_taken) begin
                            if (s1_opcode == `OP_JAL)
                                pc <= s1_branch_offset[7:0]; // jal: explicitly route jump_target
                            else if (s1_opcode == `OP_REG && s1_func == `FUNC_JALR)
                                pc <= s1_src1[7:0];          // jalr: explicitly route src1
                            else
                                pc <= dest_data[7:0];        // All other branches/jumps use ALU dest
                        end else begin
                            pc <= pc + 8'd1;
                        end
                    end

                    state <= 2'd0;
                end

                default: state <= 2'd0;
            endcase

            // ── Unstall (Edge Detected) ───────────────────────────────────────
            if (copied_io_regs && !prev_copied_io_regs) begin
                io_stall     <= 1'b0;
                io_reg_index <= 3'b0;
            end
        end
    end
endmodule