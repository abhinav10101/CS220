`timescale 1ns / 1ps
`include "defs.vh"

module Processor2(
    input         clk,
    output        halt,
    input         reset,
    output reg [7:0] pc,
    input  [31:0] ins,
    output [31:0] io_reg1,
    output [31:0] io_reg2,
    output [31:0] io_reg3,
    output [31:0] io_reg4
);

// ─── Instruction decode (combinational, always from current ins) ──────────────
wire [5:0]  opcode        = ins[31:26];
wire [4:0]  src1_addr     = ins[25:21];
wire [4:0]  src2_addr     = ins[20:16];
wire [4:0]  dest_addr     = (opcode == `OP_REG) ? ins[15:11] : ins[20:16];
wire [4:0]  shift_amount  = ins[10:6];
wire [5:0]  func          = ins[5:0];
wire [15:0] imm           = ins[15:0];
wire [31:0] imm_ext       = (opcode == `OP_ANDI ||
                             opcode == `OP_ORI  ||
                             opcode == `OP_XORI)
                            ? {16'b0,    imm}
                            : {{16{imm[15]}}, imm};

// ─── Register file outputs ────────────────────────────────────────────────────
wire [31:0] src1;       // read port 1
wire [31:0] src2_rf;    // read port 2
wire [31:0] src2 = (opcode == `OP_REG) ? src2_rf : imm_ext;

// ─── ALU outputs ──────────────────────────────────────────────────────────────
wire [31:0] dest_data;
wire        dest_data_valid;

// ─── Inter-state (pipeline) registers ────────────────────────────────────────
// These carry State-0 results into State-1
reg         state;          // 0 = fetch/decode/execute, 1 = writeback
reg         fetched;        // goes high one cycle after reset deasserts

reg [4:0]   wb_addr;        // destination register address  (for RF write)
reg [31:0]  wb_data;        // destination register data     (for RF write)
reg         wb_enable;      // write-enable                  (for RF write)

// Saved fields needed for syscall detection in State 1
reg [5:0]   opcode_reg;
reg [5:0]   func_reg;
reg [31:0]  src1_reg;
reg [31:0]  src2_reg;

// ─── IO registers ─────────────────────────────────────────────────────────────
reg [31:0]  io_reg [0:3];
reg [1:0]   io_reg_index;

assign io_reg1 = io_reg[0];
assign io_reg2 = io_reg[1];
assign io_reg3 = io_reg[2];
assign io_reg4 = io_reg[3];

// ─── halt ─────────────────────────────────────────────────────────────────────
// Halt is asserted in State 1 when the registered instruction is SYS_exit.
// We keep PC frozen when halt is high so the instruction memory stays valid.
assign halt = (~reset & fetched & (state == 1'b1))
              ? ((opcode_reg == `OP_REG) &&
                 (func_reg   == `FUNC_SYSCALL) &&
                 (src1_reg   == `SYS_exit))
              : 1'b0;

// ─── Register File ────────────────────────────────────────────────────────────
RegisterFile rf (
    .read_addr1   (src1_addr),
    .read_addr2   (src2_addr),
    .read_data1   (src1),
    .read_data2   (src2_rf),
    .write_addr   (wb_addr),
    .write_data   (wb_data),
    .write_enable (wb_enable & fetched & (state == 1'b1)),
    .clk          (clk)
);
 
// ─── ALU ──────────────────────────────────────────────────────────────────────
ALU alu (
    .src1         (src1),
    .src2         (src2),
    .shift_amount (shift_amount),
    .opcode       (opcode),
    .func         (func),
    .dest         (dest_data),
    .dest_valid   (dest_data_valid)
);

// ─── FSM ──────────────────────────────────────────────────────────────────────
always @(posedge clk) begin
    if (reset) begin
        pc           <= 8'b0;
        state        <= 1'b0;
        fetched      <= 1'b0;
        wb_enable    <= 1'b0;
        io_reg_index <= 2'b0;
        io_reg[0]    <= 32'b0;
        io_reg[1]    <= 32'b0;
        io_reg[2]    <= 32'b0;
        io_reg[3]    <= 32'b0;
    end else begin

        // One cycle after reset the first instruction has been fetched
        fetched <= 1'b1;

        if (state == 1'b0) begin
            // ── State 0: Fetch / Decode / Read RF / Execute ───────────────
            // PC does NOT change here - it must remain stable so that `ins`
            // (which comes straight from instruction memory addressed by pc)
            // stays valid all the way through State 1 writeback.

            // Latch ALU result into inter-state pipeline registers
            wb_data    <= dest_data;
            wb_addr    <= dest_addr;
            wb_enable  <= dest_data_valid;

            // Latch instruction fields needed by State 1
            opcode_reg <= opcode;
            func_reg   <= func;
            src1_reg   <= src1;     // value read from RF this cycle
            src2_reg   <= src2;     // value read from RF / immediate this cycle

            state <= 1'b1;

        end else begin
            // ── State 1: Write-Back ───────────────────────────────────────
            // RF write is handled by the combinational enable above;
            // we just need to handle side-effects (syscalls) here.

            if ((opcode_reg == `OP_REG)   &&
                (func_reg   == `FUNC_SYSCALL) &&
                (src1_reg   == `SYS_write)) begin
                io_reg[io_reg_index] <= src2_reg;
                io_reg_index         <= io_reg_index + 1;
            end

            // Advance PC now (only if not halting).
            // Because PC changes here, `ins` will present the NEXT instruction
            // exactly when we return to State 0 - perfect timing.
            if (!halt) begin
                pc <= pc + 8'd1;
            end

            state <= 1'b0;
        end
    end
end

endmodule