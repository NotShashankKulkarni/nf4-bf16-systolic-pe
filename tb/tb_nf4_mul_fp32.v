`timescale 1ns/1ps

module tb_nf4_mul_fp32;

reg  [3:0]  code;
reg  [15:0] a;
wire [31:0] p_nf4;

nf4_mul_fp32 dut (.code(code), .a(a), .p(p_nf4));

function [15:0] nf4_bf16_bits(input [3:0] c);
    case (c)
        4'd0:  nf4_bf16_bits = 16'b1_01111111_0000000;
        4'd1:  nf4_bf16_bits = 16'b1_01111110_0110010;
        4'd2:  nf4_bf16_bits = 16'b1_01111110_0000110;
        4'd3:  nf4_bf16_bits = 16'b1_01111101_1001010;
        4'd4:  nf4_bf16_bits = 16'b1_01111101_0010010;
        4'd5:  nf4_bf16_bits = 16'b1_01111100_0111101;
        4'd6:  nf4_bf16_bits = 16'b1_01111011_0111010;
        4'd7:  nf4_bf16_bits = 16'd0;
        4'd8:  nf4_bf16_bits = 16'b0_01111011_0100011;
        4'd9:  nf4_bf16_bits = 16'b0_01111100_0100101;
        4'd10: nf4_bf16_bits = 16'b0_01111100_1111100;
        4'd11: nf4_bf16_bits = 16'b0_01111101_0101101;
        4'd12: nf4_bf16_bits = 16'b0_01111101_1100010;
        4'd13: nf4_bf16_bits = 16'b0_01111110_0010000;
        4'd14: nf4_bf16_bits = 16'b0_01111110_0111001;
        default: nf4_bf16_bits = 16'b0_01111111_0000000; // code 15
    endcase
endfunction

reg  [15:0] b_ref;
wire [31:0] p_ref;
bf16_mul_fp32 golden (.a(a), .b(b_ref), .p(p_ref));

integer c, k;
integer total, fails;

initial begin
    total = 0;
    fails = 0;
    for (c = 0; c < 16; c = c + 1) begin
        code  = c[3:0];
        b_ref = nf4_bf16_bits(c[3:0]);
        for (k = 0; k < 65536; k = k + 1) begin
            a = k[15:0];
            #1;
            total = total + 1;
            if (p_nf4 !== p_ref) begin
                fails = fails + 1;
                if (fails <= 20)
                    $display("FAIL code=%0d a=%h got=%h exp=%h", c, a, p_nf4, p_ref);
            end
        end
    end
    $display("total vectors: %0d", total);
    $display("failures: %0d", fails);
    if (fails == 0) $display("ALL TESTS PASSED");
    else $display("TESTS FAILED");
    $finish;
end

endmodule
