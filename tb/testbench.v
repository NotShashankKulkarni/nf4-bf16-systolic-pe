`timescale 1ns/1ps

module tb_common_pe_power;

reg  clk, rst_n;
reg  ld_weight, en;
reg  [15:0] a_in;
reg  [3:0]  code_in;
reg  [15:0] b_in_bf16;

wire [31:0] psum_bf16;
wire [31:0] psum_nf4;

pe_bf16_ws     pe_baseline (
    .clk(clk), .rst_n(rst_n), .ld_weight(ld_weight), .en(en),
    .a_in(a_in), .b_in(b_in_bf16), .psum_in(32'd0),
    .a_out(), .b_out(), .psum_out(psum_bf16)
);

pe_nf4_bf16_ws pe_optimized (
    .clk(clk), .rst_n(rst_n), .ld_weight(ld_weight), .en(en),
    .a_in(a_in), .code_in(code_in), .psum_in(32'd0),
    .a_out(), .code_out(), .psum_out(psum_nf4)
);

always #5 clk = ~clk;

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

reg [3:0] rep_codes [0:7999];
initial $readmemh("representative_codes.hex", rep_codes);

integer seed = 32'hFACEFEED;
integer i, j, k, mismatches;
reg [3:0] cur_code;

task run_one_cycle(input [3:0] code_val, input do_check);
    begin
        code_in   = code_val;
        b_in_bf16 = nf4_bf16_bits(code_val);
        if (ld_weight) begin
            @(posedge clk); #1;
        end else begin
            a_in = $random(seed);
            @(posedge clk); #1;
            if (do_check && psum_bf16 !== psum_nf4) begin
                mismatches = mismatches + 1;
                if (mismatches <= 10)
                    $display("MISMATCH t=%0t code=%0d bf16=%h nf4=%h", $time, cur_code, psum_bf16, psum_nf4);
            end
        end
    end
endtask

initial begin
    $dumpfile("common_power.vcd");
    $dumpvars(0, tb_common_pe_power);
    clk = 0; rst_n = 0; ld_weight = 0; en = 0;
    a_in = 0; code_in = 0; b_in_bf16 = 0;
    mismatches = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;

    // ---- Regime A: weight changes every cycle (old, unrealistic case,
    // kept only to show the equivalence check still holds even in the
    // worst-case, most-conservative scenario) ----
    $display("REGIME_A_START t=%0t", $time);
    en = 1;
    for (i = 0; i < 200; i = i + 1) begin
        cur_code = $random(seed) % 16;
        ld_weight = 1; run_one_cycle(cur_code, 1'b0);
        ld_weight = 0; run_one_cycle(cur_code, 1'b1);
    end
    $display("Regime A (weight-changes-every-cycle) done, mismatches so far: %0d", mismatches);
    $display("REGIME_B_START t=%0t", $time);

    // ---- Regime B: stationary weight, long random-activation stream,
    // swept across all 16 codes (the corrected, realistic methodology) ----
    for (k = 0; k < 16; k = k + 1) begin
        cur_code = k[3:0];
        ld_weight = 1; run_one_cycle(cur_code, 1'b0);
        ld_weight = 0;
        for (i = 0; i < 300; i = i + 1)
            run_one_cycle(cur_code, 1'b1);
    end
    $display("Regime B (stationary weight sweep) done, mismatches so far: %0d", mismatches);
    $display("REGIME_C_START t=%0t", $time);

    // ---- Regime C: representative workload, weight code drawn from a
    // real Gaussian-quantized distribution, held stationary for a
    // realistic run length before moving to the next weight ----
    i = 0;
    while (i < 8000) begin
        cur_code = rep_codes[i];
        ld_weight = 1; run_one_cycle(cur_code, 1'b0);
        ld_weight = 0;
        for (j = 0; j < 32 && i < 8000; j = j + 1) begin
            run_one_cycle(cur_code, 1'b1);
            i = i + 1;
        end
    end
    $display("Regime C (representative workload) done, total mismatches: %0d", mismatches);
    $display("REGIME_C_END t=%0t", $time);

    if (mismatches == 0)
        $display("ALL PE OUTPUTS IDENTICAL ACROSS ALL REGIMES - PASS");
    else
        $display("OUTPUT MISMATCHES DETECTED - FAIL");

    $finish;
end

endmodule
