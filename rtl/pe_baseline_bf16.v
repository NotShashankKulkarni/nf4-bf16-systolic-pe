module rshift_sticky #(
    parameter W  = 27,
    parameter SW = 8
) (
    input  wire [W-1:0]  din,
    input  wire [SW-1:0] shamt,
    output wire [W-1:0]  dout,
    output wire          sticky
);

wire big_shift = (shamt >= W);
wire [W-1:0] shifted = big_shift ? {W{1'b0}} : (din >> shamt);
wire [W-1:0] mask    = big_shift ? {W{1'b1}} :
                        (shamt == 0) ? {W{1'b0}} : ({W{1'b1}} >> (W - shamt));

assign dout   = shifted;
assign sticky = |(din & mask);

endmodule
module lzc27 (
    input  wire [26:0] din,
    output reg  [4:0]  cnt
);

integer i;

always @(*) begin
    cnt = 5'd27;
    for (i = 26; i >= 0; i = i - 1)
        if (din[i] && cnt == 5'd27)
            cnt = 26 - i;
end

endmodule
module bf16_mul_fp32 (
    input  wire [15:0] a,
    input  wire [15:0] b,
    output wire [31:0] p
);

wire        sign_a = a[15];
wire        sign_b = b[15];
wire [7:0]  exp_a  = a[14:7];
wire [7:0]  exp_b  = b[14:7];
wire [6:0]  man_a  = a[6:0];
wire [6:0]  man_b  = b[6:0];

wire a_zero = (exp_a == 8'd0) && (man_a == 7'd0);
wire b_zero = (exp_b == 8'd0) && (man_b == 7'd0);
wire a_inf  = (exp_a == 8'hFF) && (man_a == 7'd0);
wire b_inf  = (exp_b == 8'hFF) && (man_b == 7'd0);
wire a_nan  = (exp_a == 8'hFF) && (man_a != 7'd0);
wire b_nan  = (exp_b == 8'hFF) && (man_b != 7'd0);

wire [7:0]  mant_a = {1'b1, man_a};
wire [7:0]  mant_b = {1'b1, man_b};
wire [15:0] prod   = mant_a * mant_b;
wire        norm_shift = prod[15];

wire signed [9:0] exp_raw = $signed({2'b0, exp_a}) + $signed({2'b0, exp_b})
                             - 10'sd127 + {9'd0, norm_shift};

wire        p_sign = sign_a ^ sign_b;
wire [22:0] p_mant = norm_shift ? {prod[14:0], 8'b0} : {prod[13:0], 9'b0};

wire under = (exp_raw <= 10'sd0);
wire over  = (exp_raw >= 10'sd255);
wire [7:0] p_exp = exp_raw[7:0];

wire res_nan = a_nan || b_nan || (a_inf && b_zero) || (b_inf && a_zero);
wire res_inf = !res_nan && (a_inf || b_inf || over);
wire res_zro = !res_nan && !res_inf && (a_zero || b_zero || under);

assign p = res_nan ? {1'b0, 8'hFF, 23'h400000} :
           res_inf ? {p_sign, 8'hFF, 23'd0}     :
           res_zro ? {p_sign, 31'd0}            :
                     {p_sign, p_exp, p_mant};

endmodule
module fp32_add (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] sum
);

wire        sign_a = a[31];
wire        sign_b = b[31];
wire [7:0]  exp_a  = a[30:23];
wire [7:0]  exp_b  = b[30:23];
wire [22:0] frac_a = a[22:0];
wire [22:0] frac_b = b[22:0];

wire a_zero = (exp_a == 8'd0) && (frac_a == 23'd0);
wire b_zero = (exp_b == 8'd0) && (frac_b == 23'd0);
wire a_inf  = (exp_a == 8'hFF) && (frac_a == 23'd0);
wire b_inf  = (exp_b == 8'hFF) && (frac_b == 23'd0);
wire a_nan  = (exp_a == 8'hFF) && (frac_a != 23'd0);
wire b_nan  = (exp_b == 8'hFF) && (frac_b != 23'd0);

wire [23:0] mant_a = {(exp_a != 8'd0), frac_a};
wire [23:0] mant_b = {(exp_b != 8'd0), frac_b};

wire a_ge = (exp_a > exp_b) || ((exp_a == exp_b) && (mant_a >= mant_b));

wire [7:0]  exp_big  = a_ge ? exp_a  : exp_b;
wire [7:0]  exp_sml  = a_ge ? exp_b  : exp_a;
wire        sign_big = a_ge ? sign_a : sign_b;
wire        sign_sml = a_ge ? sign_b : sign_a;
wire [23:0] mant_big = a_ge ? mant_a : mant_b;
wire [23:0] mant_sml = a_ge ? mant_b : mant_a;
wire [7:0]  exp_diff = exp_big - exp_sml;

wire [26:0] big_ext = {mant_big, 3'b000};
wire [26:0] sml_ext = {mant_sml, 3'b000};
wire [26:0] sml_shifted;
wire        sticky_align;

rshift_sticky #(.W(27), .SW(8)) u_align (
    .din(sml_ext), .shamt(exp_diff), .dout(sml_shifted), .sticky(sticky_align)
);

wire same_sign = (sign_big == sign_sml);

wire [27:0] raw = same_sign ? ({1'b0, big_ext} + {1'b0, sml_shifted})
                             : ({1'b0, big_ext} - {1'b0, sml_shifted});

wire neg_res   = !same_sign && raw[27];
wire carry_out =  same_sign && raw[27];

wire [26:0] mag = same_sign ? (carry_out ? raw[27:1] : raw[26:0])
                             : (neg_res  ? (~raw[26:0] + 27'd1) : raw[26:0]);

wire res_sign_gen = same_sign ? sign_big : (neg_res ? sign_sml : sign_big);
wire is_mag_zero  = (mag == 27'd0);
wire shift_out_bit = carry_out ? raw[0] : 1'b0;

wire [4:0] lzc;
lzc27 u_lzc (.din(mag), .cnt(lzc));

wire signed [9:0] exp_adj = same_sign   ? ($signed({2'b0, exp_big}) + {9'd0, carry_out}) :
                             is_mag_zero ? 10'sd0 :
                                           ($signed({2'b0, exp_big}) - $signed({5'b0, lzc}));

wire [26:0] mag_norm = same_sign   ? mag :
                        is_mag_zero ? 27'd0 :
                                      (mag << lzc);

wire [22:0] frac_pre     = mag_norm[25:3];
wire        guard        = mag_norm[2];
wire        sticky_total = mag_norm[1] | mag_norm[0] | sticky_align | shift_out_bit;
wire        round_up     = guard & (sticky_total | frac_pre[0]);

wire [23:0]       frac_rounded = {1'b0, frac_pre} + {23'd0, round_up};
wire              mant_carry   = frac_rounded[23];
wire [22:0]       frac_final   = mant_carry ? 23'd0 : frac_rounded[22:0];
wire signed [9:0] exp_final    = exp_adj + {9'd0, mant_carry};

wire ovf = (exp_final >= 10'sd255);
wire unf = (exp_final <= 10'sd0);
wire [7:0] exp_result = exp_final[7:0];

wire res_nan  = a_nan || b_nan || (a_inf && b_inf && (sign_a != sign_b));
wire zero_sgn = sign_a & sign_b;

assign sum = res_nan             ? {1'b0, 8'hFF, 23'h400000}                      :
             (a_inf || b_inf)    ? {(a_inf ? sign_a : sign_b), 8'hFF, 23'd0}       :
             (a_zero && b_zero)  ? {zero_sgn, 31'd0}                              :
             a_zero              ? b                                              :
             b_zero              ? a                                              :
             is_mag_zero         ? 32'd0                                          :
             unf                 ? {res_sign_gen, 31'd0}                          :
             ovf                 ? {res_sign_gen, 8'hFF, 23'd0}                   :
                                   {res_sign_gen, exp_result, frac_final};

endmodule
module pe_bf16_ws (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ld_weight,
    input  wire        en,
    input  wire [15:0] a_in,
    input  wire [15:0] b_in,
    input  wire [31:0] psum_in,
    output reg  [15:0] a_out,
    output reg  [15:0] b_out,
    output wire [31:0] psum_out
);

reg  [15:0] w_reg;
wire [31:0] prod_comb;
bf16_mul_fp32 u_mul (.a(a_in), .b(w_reg), .p(prod_comb));

reg  [31:0] prod_reg;
reg  [31:0] psum_in_r;
reg         en_r;
reg  [31:0] psum_out_reg;

wire [31:0] sum_comb;
fp32_add u_add (.a(psum_in_r), .b(prod_reg), .sum(sum_comb));

assign psum_out = psum_out_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        w_reg        <= 16'd0;
        a_out        <= 16'd0;
        b_out        <= 16'd0;
        prod_reg     <= 32'd0;
        psum_in_r    <= 32'd0;
        en_r         <= 1'b0;
        psum_out_reg <= 32'd0;
    end else begin
        a_out     <= a_in;
        b_out     <= b_in;
        if (ld_weight)
            w_reg <= b_in;
        prod_reg     <= prod_comb;
        psum_in_r    <= psum_in;
        en_r         <= en;
        psum_out_reg <= en_r ? sum_comb : psum_in_r;
    end
end

endmodule
