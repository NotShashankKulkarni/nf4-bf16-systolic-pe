module nf4_mul_fp32 (
    input  wire [3:0]  code,
    input  wire [15:0] a,
    output wire [31:0] p
);

wire        sign_a = a[15];
wire [7:0]  exp_a  = a[14:7];
wire [6:0]  man_a  = a[6:0];

wire a_zero = (exp_a == 8'd0) && (man_a == 7'd0);
wire a_inf  = (exp_a == 8'hFF) && (man_a == 7'd0);
wire a_nan  = (exp_a == 8'hFF) && (man_a != 7'd0);

reg        nf4_sign;
reg  [7:0] nf4_exp;
wire       nf4_zero = (code == 4'd7);

always @(*) begin
    case (code)
        4'd0:  begin nf4_sign = 1'b1; nf4_exp = 8'd127; end
        4'd1:  begin nf4_sign = 1'b1; nf4_exp = 8'd126; end
        4'd2:  begin nf4_sign = 1'b1; nf4_exp = 8'd126; end
        4'd3:  begin nf4_sign = 1'b1; nf4_exp = 8'd125; end
        4'd4:  begin nf4_sign = 1'b1; nf4_exp = 8'd125; end
        4'd5:  begin nf4_sign = 1'b1; nf4_exp = 8'd124; end
        4'd6:  begin nf4_sign = 1'b1; nf4_exp = 8'd123; end
        4'd7:  begin nf4_sign = 1'b0; nf4_exp = 8'd0;   end
        4'd8:  begin nf4_sign = 1'b0; nf4_exp = 8'd123; end
        4'd9:  begin nf4_sign = 1'b0; nf4_exp = 8'd124; end
        4'd10: begin nf4_sign = 1'b0; nf4_exp = 8'd124; end
        4'd11: begin nf4_sign = 1'b0; nf4_exp = 8'd125; end
        4'd12: begin nf4_sign = 1'b0; nf4_exp = 8'd125; end
        4'd13: begin nf4_sign = 1'b0; nf4_exp = 8'd126; end
        4'd14: begin nf4_sign = 1'b0; nf4_exp = 8'd126; end
        default: begin nf4_sign = 1'b0; nf4_exp = 8'd127; end // code 15
    endcase
end

// Shared shift-add significand network.
// Instead of selecting among 16 pre-shifted wide values (which forces a
// large mux per bit), decode code -> a small (shift amount, sign) control
// pair per slot first, then apply ONE shared variable-shift operator per
// slot. The 4-adder combine tree below is reused for every code.
reg [3:0] shamt0, shamt1, shamt2, shamt3, shamt4;
reg [1:0] sgn0,   sgn1,   sgn2,   sgn3,   sgn4;   // 00=unused(force 0), 01=+, 10=-

always @(*) begin
    {shamt0,sgn0} = {4'd0,2'd0}; {shamt1,sgn1} = {4'd0,2'd0};
    {shamt2,sgn2} = {4'd0,2'd0}; {shamt3,sgn3} = {4'd0,2'd0};
    {shamt4,sgn4} = {4'd0,2'd0};
    case (code)
        4'd0, 4'd15: begin
            {shamt0,sgn0} = {4'd7,2'd1};
        end
        4'd1: begin
            {shamt0,sgn0} = {4'd7,2'd1}; {shamt1,sgn1} = {4'd5,2'd1};
            {shamt2,sgn2} = {4'd4,2'd1}; {shamt3,sgn3} = {4'd1,2'd1};
        end
        4'd2: begin
            {shamt0,sgn0} = {4'd7,2'd1}; {shamt1,sgn1} = {4'd2,2'd1};
            {shamt2,sgn2} = {4'd1,2'd1};
        end
        4'd3: begin
            {shamt0,sgn0} = {4'd7,2'd1}; {shamt1,sgn1} = {4'd6,2'd1};
            {shamt2,sgn2} = {4'd3,2'd1}; {shamt3,sgn3} = {4'd1,2'd1};
        end
        4'd4: begin
            {shamt0,sgn0} = {4'd7,2'd1}; {shamt1,sgn1} = {4'd4,2'd1};
            {shamt2,sgn2} = {4'd1,2'd1};
        end
        4'd5: begin
            {shamt0,sgn0} = {4'd8,2'd1}; {shamt1,sgn1} = {4'd6,2'd2};
            {shamt2,sgn2} = {4'd2,2'd2}; {shamt3,sgn3} = {4'd0,2'd1};
        end
        4'd6: begin
            {shamt0,sgn0} = {4'd8,2'd1}; {shamt1,sgn1} = {4'd6,2'd2};
            {shamt2,sgn2} = {4'd3,2'd2}; {shamt3,sgn3} = {4'd1,2'd1};
        end
        4'd8: begin
            {shamt0,sgn0} = {4'd7,2'd1}; {shamt1,sgn1} = {4'd5,2'd1};
            {shamt2,sgn2} = {4'd1,2'd1}; {shamt3,sgn3} = {4'd0,2'd1};
        end
        4'd9: begin
            {shamt0,sgn0} = {4'd7,2'd1}; {shamt1,sgn1} = {4'd5,2'd1};
            {shamt2,sgn2} = {4'd2,2'd1}; {shamt3,sgn3} = {4'd0,2'd1};
        end
        4'd10: begin
            {shamt0,sgn0} = {4'd8,2'd1}; {shamt1,sgn1} = {4'd2,2'd2};
        end
        4'd11: begin
            {shamt0,sgn0} = {4'd7,2'd1}; {shamt1,sgn1} = {4'd5,2'd1};
            {shamt2,sgn2} = {4'd3,2'd1}; {shamt3,sgn3} = {4'd2,2'd1};
            {shamt4,sgn4} = {4'd0,2'd1};
        end
        4'd12: begin
            {shamt0,sgn0} = {4'd8,2'd1}; {shamt1,sgn1} = {4'd5,2'd2};
            {shamt2,sgn2} = {4'd1,2'd1};
        end
        4'd13: begin
            {shamt0,sgn0} = {4'd7,2'd1}; {shamt1,sgn1} = {4'd4,2'd1};
        end
        4'd14: begin
            {shamt0,sgn0} = {4'd8,2'd1}; {shamt1,sgn1} = {4'd6,2'd2};
            {shamt2,sgn2} = {4'd3,2'd2}; {shamt3,sgn3} = {4'd0,2'd1};
        end
        default: ; // code 7, zero
    endcase
end

wire [8:0] mant_a = {1'b0, 1'b1, man_a};

wire [8:0] m_gated0 = (sgn0 == 2'd0) ? 9'd0 : mant_a;
wire [8:0] m_gated1 = (sgn1 == 2'd0) ? 9'd0 : mant_a;
wire [8:0] m_gated2 = (sgn2 == 2'd0) ? 9'd0 : mant_a;
wire [8:0] m_gated3 = (sgn3 == 2'd0) ? 9'd0 : mant_a;
wire [8:0] m_gated4 = (sgn4 == 2'd0) ? 9'd0 : mant_a;

wire [16:0] shifted0 = {8'd0, m_gated0} << shamt0;
wire [16:0] shifted1 = {8'd0, m_gated1} << shamt1;
wire [16:0] shifted2 = {8'd0, m_gated2} << shamt2;
wire [16:0] shifted3 = {8'd0, m_gated3} << shamt3;
wire [16:0] shifted4 = {8'd0, m_gated4} << shamt4;

wire signed [16:0] slot0 = (sgn0 == 2'd2) ? -$signed(shifted0) : $signed(shifted0);
wire signed [16:0] slot1 = (sgn1 == 2'd2) ? -$signed(shifted1) : $signed(shifted1);
wire signed [16:0] slot2 = (sgn2 == 2'd2) ? -$signed(shifted2) : $signed(shifted2);
wire signed [16:0] slot3 = (sgn3 == 2'd2) ? -$signed(shifted3) : $signed(shifted3);
wire signed [16:0] slot4 = (sgn4 == 2'd2) ? -$signed(shifted4) : $signed(shifted4);

wire signed [16:0] stageA = slot0 + slot1;
wire signed [16:0] stageB = slot2 + slot3;
wire signed [16:0] stageC = stageA + stageB;
wire signed [16:0] prod_s = stageC + slot4;
wire        [15:0] prod   = nf4_zero ? 16'd0 : prod_s[15:0];

wire        norm_shift = prod[15];

wire signed [9:0] exp_raw = $signed({2'b0, exp_a}) + $signed({2'b0, nf4_exp})
                             - 10'sd127 + {9'd0, norm_shift};

wire        p_sign = sign_a ^ nf4_sign;
wire [22:0] p_mant = norm_shift ? {prod[14:0], 8'b0} : {prod[13:0], 9'b0};

wire under = (exp_raw <= 10'sd0);
wire over  = (exp_raw >= 10'sd255);
wire [7:0] p_exp = exp_raw[7:0];

wire res_nan = a_nan || (a_inf && nf4_zero);
wire res_inf = !res_nan && (a_inf || over);
wire res_zro = !res_nan && !res_inf && (a_zero || nf4_zero || under);

assign p = res_nan ? {1'b0, 8'hFF, 23'h400000} :
           res_inf ? {p_sign, 8'hFF, 23'd0}     :
           res_zro ? {p_sign, 31'd0}            :
                     {p_sign, p_exp, p_mant};

endmodule
module pe_nf4_bf16_ws (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ld_weight,
    input  wire        en,
    input  wire [15:0] a_in,
    input  wire [3:0]  code_in,
    input  wire [31:0] psum_in,
    output reg  [15:0] a_out,
    output reg  [3:0]  code_out,
    output wire [31:0] psum_out
);

reg  [3:0]  code_reg;
wire [31:0] prod_comb;
// PE-level operand isolation: when the PE isn't performing a MAC this
// cycle, the multiplier never sees the real (changing) activation, so
// its entire internal network stays static instead of chewing through
// irrelevant streamed values that will just get discarded.
wire [15:0] a_gated = en ? a_in : 16'd0;
nf4_mul_fp32 u_mul (.code(code_reg), .a(a_gated), .p(prod_comb));

reg  [31:0] prod_reg;
reg  [31:0] psum_in_r;
reg         en_r;
reg  [31:0] psum_out_reg;

wire [31:0] sum_comb;
fp32_add u_add (.a(psum_in_r), .b(prod_reg), .sum(sum_comb));

assign psum_out = psum_out_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        code_reg     <= 4'd0;
        a_out        <= 16'd0;
        code_out     <= 4'd0;
        prod_reg     <= 32'd0;
        psum_in_r    <= 32'd0;
        en_r         <= 1'b0;
        psum_out_reg <= 32'd0;
    end else begin
        a_out     <= a_in;
        code_out  <= code_in;
        if (ld_weight)
            code_reg <= code_in;
        prod_reg     <= prod_comb;
        psum_in_r    <= psum_in;
        en_r         <= en;
        psum_out_reg <= en_r ? sum_comb : psum_in_r;
    end
end

endmodule
