`include "defs.vh"
module ALU (input [31:0] src1, input [31:0] src2, input [4:0] shift_amount, input [5:0] opcode, input [5:0] func, output [31:0] dest, output dest_valid);
    reg [31:0] result;
    reg result_valid;
    assign dest = result; 
    assign dest_valid = result_valid; 
    always @(src1 or src2 or opcode or func or shift_amount) begin
        result = 32'd0;
        result_valid = 1'b0;

        case (opcode)

            // R-type instructions
            `OP_REG: begin
                case (func)

                    // Immediate shifts (use shamt)
                    `FUNC_SLL: begin
                        result = src2 << shift_amount;
                        result_valid = 1'b1;
                    end

                    `FUNC_SRL: begin
                        result = src2 >> shift_amount;
                        result_valid = 1'b1;
                    end

                    `FUNC_SRA: begin
                        result = $signed(src2) >>> shift_amount;
                        result_valid = 1'b1;
                    end

                    // Variable shifts (use rs)
                    `FUNC_SLLV: begin
                        result = src2 << src1[4:0];
                        result_valid = 1'b1;
                    end

                    `FUNC_SRLV: begin
                        result = src2 >> src1[4:0];
                        result_valid = 1'b1;
                    end

                    `FUNC_SRAV: begin
                        result = $signed(src2) >>> src1[4:0];
                        result_valid = 1'b1;
                    end

                    // Arithmetic / logical
                    `FUNC_ADD: begin
                        result = src1 + src2;
                        result_valid = 1'b1;
                    end

                    `FUNC_SUB: begin
                        result = src1 - src2;
                        result_valid = 1'b1;
                    end

                    `FUNC_AND: begin
                        result = src1 & src2;
                        result_valid = 1'b1;
                    end

                    `FUNC_OR: begin
                        result = src1 | src2;
                        result_valid = 1'b1;
                    end

                    `FUNC_XOR: begin
                        result = src1 ^ src2;
                        result_valid = 1'b1;
                    end

                    `FUNC_NOR: begin
                        result = ~(src1 | src2);
                        result_valid = 1'b1;
                    end

                    // SYSCALL does not write back
                    `FUNC_SYSCALL: begin
                        result_valid = 1'b0;
                    end

                    default: begin
                        result = 32'd0;
                        result_valid = 1'b0;
                    end

                endcase
            end

            // I-type instructions
            `OP_ADDI: begin
                result = src1 + src2;
                result_valid = 1'b1;
            end

            `OP_ANDI: begin
                result = src1 & src2;
                result_valid = 1'b1;
            end

            `OP_ORI: begin
                result = src1 | src2;
                result_valid = 1'b1;
            end

            `OP_XORI: begin
                result = src1 ^ src2;
                result_valid = 1'b1;
            end

            default: begin
                result = 32'd0;
                result_valid = 1'b0;
            end

        endcase
    end
endmodule