// =============================================================================
//  ALU.v  â€"  Complete ALU for the 5th iteration MIPS Processor
//
//  Lab-7 operations (unchanged):
//    R-type (opcode=0): add, sub, and, or, xor, nor, sll, srl, sra, syscall
//    I-type: addi, addiu, andi, ori, xori, lui, lw, sw (dest passthrough)
//
//  Lab-8 additions:
//    R-type: jr (0x08), jalr (0x09), slt (0x2a), sltu (0x2b)
//    I-type: bltz/bgez (0x01), beq (0x04), bne (0x05),
//             blez (0x06), bgtz (0x07), slti (0x0a), sltiu (0x0b)
//    J-type: j (0x02), jal (0x03)
//
//  NEW PORTS vs Lab-7 ALU:
//    inputs  : pc [7:0]           â€" PC of the instruction being executed
//              branch_offset[31:0] â€" sign-extended imm (branches) or
//                                    zero-extended jump_target (j/jal)
//              rt [4:0]           â€" distinguishes bltz (rt==0) from bgez (rt==1)
//    outputs : branch_taken       â€" 1 if this instruction redirects the PC
//
//  dest encoding for branch/jump instructions:
//    conditional branches, j, jr  â†' dest = branch/jump target address
//    jal, jalr                    â†' dest = pc + 1  (return address for $31)
//    dest_valid                   â†' 0 for conditional branches, j, jr
//                                   1 for jal, jalr (write pc+1 to $31)
//
//  This is a purely combinational module (always @(*)).
// =============================================================================

`timescale 1ns / 1ps
`include "defs.vh"

module ALU5 (
    input [31:0] src1, 
    input [31:0] src2, 
    input [4:0] shift_amount, 
    input [5:0] opcode, 
    input [5:0] func, 
    input [7:0] pc,                  // Added for branch offset math
    input [31:0] branch_offset,      // Added for jump targets / branch immediate
    input [4:0] rt,                  // Added to distinguish bltz/bgez
    output [31:0] dest, 
    output dest_valid,
    output reg branch_taken          // Added to signal a taken jump/branch
);

    reg [31:0] result;
    reg result_valid;
    
    assign dest = result; 
    assign dest_valid = result_valid;

    always @(*) begin
        result = 32'd0;
        result_valid = 1'b0;
        branch_taken = 1'b0;

        case (opcode)

            // R-type instructions
            `OP_REG: begin
                case (func)
                    `FUNC_SLL:  begin result = src2 << shift_amount; result_valid = 1'b1; end
                    `FUNC_SRL:  begin result = src2 >> shift_amount; result_valid = 1'b1; end
                    `FUNC_SRA:  begin result = $signed(src2) >>> shift_amount; result_valid = 1'b1; end
                    `FUNC_SLLV: begin result = src2 << src1[4:0]; result_valid = 1'b1; end
                    `FUNC_SRLV: begin result = src2 >> src1[4:0]; result_valid = 1'b1; end
                    `FUNC_SRAV: begin result = $signed(src2) >>> src1[4:0]; result_valid = 1'b1; end
                    `FUNC_ADD:  begin result = src1 + src2; result_valid = 1'b1; end
                    `FUNC_SUB:  begin result = src1 - src2; result_valid = 1'b1; end
                    `FUNC_AND:  begin result = src1 & src2; result_valid = 1'b1; end
                    `FUNC_OR:   begin result = src1 | src2; result_valid = 1'b1; end
                    `FUNC_XOR:  begin result = src1 ^ src2; result_valid = 1'b1; end
                    `FUNC_NOR:  begin result = ~(src1 | src2); result_valid = 1'b1; end
                    
                    // --- Assignment 2: Comparisons ---
                    `FUNC_SLT:  begin result = ($signed(src1) < $signed(src2)) ? 32'd1 : 32'd0; result_valid = 1'b1; end
                    `FUNC_SLTU: begin result = (src1 < src2) ? 32'd1 : 32'd0; result_valid = 1'b1; end
                    
                    // --- Assignment 2: Jumps ---
                    `FUNC_JR: begin
                        result = src1; // branch target
                        branch_taken = 1'b1;
                        result_valid = 1'b0;
                    end
                    `FUNC_JALR: begin
                        result = {24'b0, pc} + 32'd1; // dest = pc+1 to link
                        branch_taken = 1'b1;
                        result_valid = 1'b1;
                    end
                    
                    `FUNC_SYSCALL: result_valid = 1'b0;
                    default: begin result = 32'd0; result_valid = 1'b0; end
                endcase
            end

            // I-type instructions
            `OP_ADDI: begin result = src1 + src2; result_valid = 1'b1; end
            `OP_ANDI: begin result = src1 & src2; result_valid = 1'b1; end
            `OP_ORI:  begin result = src1 | src2; result_valid = 1'b1; end
            `OP_XORI: begin result = src1 ^ src2; result_valid = 1'b1; end

            // --- Assignment 2: Immediate Comparisons ---
            `OP_SLTI:  begin result = ($signed(src1) < $signed(src2)) ? 32'd1 : 32'd0; result_valid = 1'b1; end // src2 is already imm_ext
            `OP_SLTIU: begin result = (src1 < src2) ? 32'd1 : 32'd0; result_valid = 1'b1; end

            // --- Assignment 2: Branches ---
            `OP_BEQ: begin
                result = {24'b0, pc} + branch_offset;
                branch_taken = (src1 == src2);
                result_valid = 1'b0;
            end
            `OP_BNE: begin
                result = {24'b0, pc} + branch_offset;
                branch_taken = (src1 != src2);
                result_valid = 1'b0;
            end
            `OP_BLEZ: begin
                result = {24'b0, pc} + branch_offset;
                branch_taken = ($signed(src1) <= $signed(32'b0));
                result_valid = 1'b0;
            end
            `OP_BGTZ: begin
                result = {24'b0, pc} + branch_offset;
                branch_taken = ($signed(src1) > $signed(32'b0));
                result_valid = 1'b0;
            end
            `OP_BLTZ_BGEZ: begin
                result = {24'b0, pc} + branch_offset;
                if (rt == 5'd0)      branch_taken = ($signed(src1) < $signed(32'b0));
                else if (rt == 5'd1) branch_taken = ($signed(src1) >= $signed(32'b0));
                result_valid = 1'b0;
            end

            // --- Assignment 2: J-type Jumps ---
            `OP_J: begin
                result = branch_offset; // branch_offset holds jump_target
                branch_taken = 1'b1;
                result_valid = 1'b0;
            end
            `OP_JAL: begin
                result = {24'b0, pc} + 32'd1; // dest = pc+1 to link
                branch_taken = 1'b1;
                result_valid = 1'b1;
            end

            default: begin
                result = 32'd0;
                result_valid = 1'b0;
                branch_taken = 1'b0;
            end

        endcase
    end
endmodule