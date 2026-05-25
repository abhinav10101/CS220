`timescale 1ns / 1ps
`include "defs.vh"

module Processor3(
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

// ─── Instruction decode (combinational, from current ins) ─────────────────────
wire [5:0]  opcode       = ins[31:26];
wire [4:0]  src1_addr    = ins[25:21];
wire [4:0]  src2_addr    = ins[20:16];
wire [4:0]  dest_addr    = (opcode == `OP_REG) ? ins[15:11] : ins[20:16];
wire [4:0]  shift_amount = ins[10:6];
wire [5:0]  func         = ins[5:0];
wire [15:0] imm          = ins[15:0];
wire [31:0] imm_ext      = (opcode == `OP_ANDI ||
                            opcode == `OP_ORI  ||
                            opcode == `OP_XORI)
                           ? {16'b0, imm}
                           : {{16{imm[15]}}, imm};

// ─── Register file outputs (combinational reads) ──────────────────────────────
wire [31:0] src1;
wire [31:0] src2_rf;
wire [31:0] src2 = (opcode == `OP_REG) ? src2_rf : imm_ext;

// ─── ALU outputs ──────────────────────────────────────────────────────────────
wire [31:0] dest_data;
wire        dest_data_valid;

// ═══════════════════════════════════════════════════════════════════════════════
// Inter-state pipeline registers
// ═══════════════════════════════════════════════════════════════════════════════

// Stage 0→1: decoded fields + RF read values → Execute stage
reg [5:0]  s1_opcode;
reg [5:0]  s1_func;
reg [4:0]  s1_shift_amount;
reg [31:0] s1_src1;
reg [31:0] s1_src2;
reg [4:0]  s1_dest_addr;

// Stage 1→2: ALU result → Write-Back stage
reg [4:0]  wb_addr;
reg [31:0] wb_data;
reg        wb_enable;

// ─── FSM state ────────────────────────────────────────────────────────────────
reg [1:0]  state;
reg        fetched;

// ─── Halt control ─────────────────────────────────────────────────────────────
// exit_detected: set in State 1 when SYS_exit is identified
// halt_reg:      set in State 2 so the exit instruction consumes all 3 cycles
//                before halting, giving correct proc_cycle count
reg        exit_detected;
reg        halt_reg;
assign     halt = halt_reg;

// ─── IO registers ─────────────────────────────────────────────────────────────
reg [31:0] io_reg [0:3];
reg [1:0]  io_reg_index;

assign io_reg1 = io_reg[0];
assign io_reg2 = io_reg[1];
assign io_reg3 = io_reg[2];
assign io_reg4 = io_reg[3];

// ─── Register File ────────────────────────────────────────────────────────────
// Reads: combinational, used in State 0
// Write: only enabled in State 2
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

// ─── ALU ──────────────────────────────────────────────────────────────────────
// Inputs are Stage-0→1 pipeline registers - stable throughout State 1.
// Critical path this cycle: s1_reg → ALU → wb_data_reg (much shorter than M2)
ALU alu (
    .src1         (s1_src1),
    .src2         (s1_src2),
    .shift_amount (s1_shift_amount),
    .opcode       (s1_opcode),
    .func         (s1_func),
    .dest         (dest_data),
    .dest_valid   (dest_data_valid)
);

// ─── FSM ──────────────────────────────────────────────────────────────────────
always @(posedge clk) begin
    if (reset) begin
        pc            <= 8'b0;
        state         <= 2'd0;
        fetched       <= 1'b0;
        wb_enable     <= 1'b0;
        halt_reg      <= 1'b0;
        exit_detected <= 1'b0;
        io_reg_index  <= 2'b0;
        io_reg[0]     <= 32'b0;
        io_reg[1]     <= 32'b0;
        io_reg[2]     <= 32'b0;
        io_reg[3]     <= 32'b0;
        // Safe NOP values for pipeline registers
        s1_opcode       <= 6'b0;
        s1_func         <= 6'b0;
        s1_shift_amount <= 5'b0;
        s1_src1         <= 32'b0;
        s1_src2         <= 32'b0;
        s1_dest_addr    <= 5'b0;
        wb_addr         <= 5'b0;
        wb_data         <= 32'b0;
    end else begin

        fetched <= 1'b1;

        case (state)

            // ── State 0: Fetch / Decode / Read RF ────────────────────────
            // PC is FROZEN - ins and RF reads are stable this entire cycle.
            // Latch everything needed by the Execute stage.
            2'd0: begin
                s1_opcode       <= opcode;
                s1_func         <= func;
                s1_shift_amount <= shift_amount;
                s1_src1         <= src1;      // RF read, valid now
                s1_src2         <= src2;      // RF read or immediate, valid now
                s1_dest_addr    <= dest_addr;
                state           <= 2'd1;
            end

            // ── State 1: Execute (ALU + syscall) ─────────────────────────
            // Only combinational path: s1_pipeline_reg → ALU → wb_data_reg
            // This is the timing-critical path - much shorter than M2's path.
            2'd1: begin
                // Latch ALU result for write-back in State 2
                wb_data   <= dest_data;
                wb_addr   <= s1_dest_addr;
                wb_enable <= dest_data_valid;

                // IO write syscall: executed this cycle per milestone spec
                if ((s1_opcode == `OP_REG)      &&
                    (s1_func   == `FUNC_SYSCALL) &&
                    (s1_src1   == `SYS_write)) begin
                    io_reg[io_reg_index] <= s1_src2;
                    io_reg_index         <= io_reg_index + 1;
                end

                // Flag exit syscall - halt_reg will be set in State 2 so that
                // the exit instruction consumes all 3 cycles before halting.
                // This ensures proc_cycles == 3 × single-cycle count.
                exit_detected <= ((s1_opcode == `OP_REG)      &&
                                  (s1_func   == `FUNC_SYSCALL) &&
                                  (s1_src1   == `SYS_exit));

                state <= 2'd2;
            end

            // ── State 2: Write-Back ───────────────────────────────────────
            // RF write performed by combinational write_enable above.
            // halt_reg asserted HERE (not State 1) so exit instruction
            // uses its full 3rd cycle before the processor halts.
            // PC advances here so next instruction is ready for State 0.
            2'd2: begin
                // Assert halt now - exit instruction has completed State 2
                if (exit_detected) begin
                    halt_reg      <= 1'b1;
                    exit_detected <= 1'b0;
                end

                // Advance PC only if not halting
                if (!halt_reg && !exit_detected) begin
                    pc <= pc + 8'd1;
                end

                state <= 2'd0;
            end

            default: state <= 2'd0;

        endcase
    end
end

endmodule