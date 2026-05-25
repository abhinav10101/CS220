//`timescale 1ns / 1ps

//module tb;

//    reg clk;
//    reg reset;
//    reg done_storing;
//    reg [7:0] ins_addr;
//    reg [31:0] ins;

//    wire done;
//    wire [31:0] out_reg1;
//    wire [31:0] out_reg2;
//    wire [31:0] out_reg3;
//    wire [31:0] out_reg4;
//    wire [31:0] total_cycles;
//    wire [31:0] proc_cycles;

//    Computer uut(
//        reset,
//        ins_addr,
//        ins,
//        clk,
//        done_storing,
//        done,
//        out_reg1,
//        out_reg2,
//        out_reg3,
//        out_reg4,
//        total_cycles,
//        proc_cycles
//    );

//    always #5 clk = ~clk;

//    initial begin
//        clk = 0;
//        reset = 1;
//        done_storing = 0;
//        ins_addr = 0;
//        ins = 0;

//        #7;
//        reset = 0;

//        ins = 32'h20010000; ins_addr = 0;
//        #10;
//        ins = 32'h20020000; ins_addr = 1;
//        #10;
//        ins = 32'h20050005; ins_addr = 2;
//        #10;
//        ins = 32'h00221820; ins_addr = 3;
//        #10;
//        ins = 32'h00222022; ins_addr = 4;
//        #10;
//        ins = 32'h200603ec; ins_addr = 5;
//        #10;
//        ins = 32'h00c3000c; ins_addr = 6;
//        #10;
//        ins = 32'h00c4000c; ins_addr = 7;
//        #10;
//        ins = 32'h00223824; ins_addr = 8;
//        #10;
//        ins = 32'h00224026; ins_addr = 9;
//        #10;
//        ins = 32'h00e73825; ins_addr = 10;
//        #10;
//        ins = 32'h00644825; ins_addr = 11;
//        #10;
//        ins = 32'h01204827; ins_addr = 12;
//        #10;
//        ins = 32'h01204827; ins_addr = 13;
//        #10;
//        ins = 32'h01204827; ins_addr = 14;
//        #10;
//        ins = 32'h00c0000c;ins_addr = 15;
//        #10;
//        done_storing = 1;
//        wait(done);
//        $display("%t %d",$time, done);
//        #10;
//        $finish;
//    end
//    always @(done) begin
//            $display("%t %d",$time,done);
//    end

//endmodule

`timescale 1ns/1ps
module tb_Computer;
    reg reset;
    reg [7:0] ins_addr;
    reg [31:0] ins;
    reg clk;
    reg done_storing;
    wire done;
    wire [31:0] out_reg1, out_reg2, out_reg3, out_reg4;
    wire [31:0] total_cycles, proc_cycles;

    Computer uut (
        .reset(reset),
        .ins_addr(ins_addr),
        .ins(ins),
        .clk(clk),
        .done_storing(done_storing),
        .done(done),
        .out_reg1(out_reg1),
        .out_reg2(out_reg2),
        .out_reg3(out_reg3),
        .out_reg4(out_reg4),
        .total_cycles(total_cycles),
        .proc_cycles(proc_cycles)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        reset = 1;
        done_storing = 0;
        ins_addr = 0;
        ins = 0;

        #7;
        reset = 0;

        ins_addr = 0;
        ins = 32'h2001fff1; // addi $1, $0, -15
        #10;

        ins_addr = 1;
        ins = 32'h20020014; // addi $2, $0, 20
        #10;

        ins_addr = 2;
        ins = 32'h00221820; // add $3, $1, $2
        #10;

        ins_addr = 3;
        ins = 32'h200403ec; // addi $4, $0, 1004
        #10;

        ins_addr = 4;
        ins = 32'h0083000c; // syscall $4, $3
        #10;

        ins_addr = 5;
        ins = 32'h200403e9; // addi $4, $0, 1001
        #10;

        ins_addr = 6;
        ins = 32'h0080000c; // syscall $4, $0
        #10;

        done_storing = 1;
        wait(done);
        #20;
        $display("%t %d",$time,done);
        $display("out_reg1 = %0d (expected 5)", out_reg1);
        $display("total_cycles = %0d", total_cycles);
        $display("proc_cycles = %0d", proc_cycles);

        if (out_reg1 == 32'd5)
            $display("PASS: out_reg1 is correct");
        else
            $display("FAIL: out_reg1 is %0d, expected 5", out_reg1);

        $finish;
    end
endmodule