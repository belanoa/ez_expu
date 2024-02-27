module expu_correction #(
    parameter int unsigned  INPUT_FRACTION          = 7 ,
    parameter int unsigned  COEFFICIENT_FRACTION    = 7 ,
    parameter int unsigned  CONSTANT_FRACTION       = 7 ,
    parameter int unsigned  MUL_SURPLUS_BITS        = 1 ,
    parameter int unsigned  NOT_SURPLUS_BITS        = 0
) (
    input   logic                           clk_i                   ,
    input   logic                           enable_i                ,
    input   logic                           clear_i                 ,
    input   logic                           rst_ni                  ,
    input   logic [INPUT_FRACTION - 1 : 0]  mantissa_i              ,
    output  logic [INPUT_FRACTION - 1 : 0]  corrected_mantissa_o    
);
    
    localparam  int unsigned    SUM_FRACTION    = INPUT_FRACTION > CONSTANT_FRACTION ? INPUT_FRACTION : CONSTANT_FRACTION;

    localparam  real    ALPHA_REAL  = 0.27055988837249;
    localparam  real    BETA_REAL   = 0.4294429717321613;   

    //Q<-1.CONSTANT_FRACTION>
    localparam int unsigned ALPHA   = int'(ALPHA_REAL * 2 ** COEFFICIENT_FRACTION);
    localparam int unsigned BETA    = int'(BETA_REAL * 2 ** COEFFICIENT_FRACTION);

    //Q<2.COEFFICIENT_FRACTION>
    localparam int unsigned GAMMA_1 = int'($ln(2.0) / ALPHA_REAL * 2 ** CONSTANT_FRACTION);
    localparam int unsigned GAMMA_2 = int'((2.0 * $ln(2.0) / BETA_REAL - 1.0) * 2 ** CONSTANT_FRACTION);


    //Q<-1.INPUT_FRACTION + MUL_SURPLUS_BITS>
    logic [INPUT_FRACTION - 2 + MUL_SURPLUS_BITS : 0]   mant_mul_1;

    //Q<-1.COEFFICIENT_FRACTION>
    logic [COEFFICIENT_FRACTION - 2 : 0]                alpha_beta_mul_1;

    //Q<0.SUM_FRACTION>
    logic [SUM_FRACTION - 1 : 0]                        mant_add_1;

    //Q<2.SUM_FRACTION>
    logic [SUM_FRACTION + 1 : 0]                        gamma_add_1;

    //Q<2.SUM_FRACTION>
    logic [SUM_FRACTION + 1 : 0]                        res_add_1;

    //Q<-2.COEF + INPUT + MUL_SURPLUS_BITS>
    logic [INPUT_FRACTION + COEFFICIENT_FRACTION + MUL_SURPLUS_BITS -3 : 0]                 res_mul_1;

    //Q<0.INPUT_FRACTION + SUM_FRACTION + COEFFICIENT_FRACTION + MUL_SURPLUS_BITS>
    logic [INPUT_FRACTION + SUM_FRACTION + COEFFICIENT_FRACTION + MUL_SURPLUS_BITS - 1: 0]  res_mul_2;

    //Q<0.INPUT_FRACTION + NOT_SURPLUS_BITS>
    logic [INPUT_FRACTION + NOT_SURPLUS_BITS - 1 : 0]                                       res_pre_inversion;

    logic [INPUT_FRACTION - 1 : 0]  mantissa_q;


    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            mantissa_q <= '0;
        end else begin
            if (clear_i) begin
                mantissa_q <= '0;
            end else if (enable_i) begin
                mantissa_q <= mantissa_i;
            end else begin
                mantissa_q <= mantissa_q;
            end
        end
    end


    assign mant_mul_1           = mantissa_q [INPUT_FRACTION - 1] == 1'b0 ? {mantissa_q [INPUT_FRACTION - 2 : 0], {MUL_SURPLUS_BITS{1'b0}}} : ~{mantissa_q [INPUT_FRACTION - 1 : 0], {MUL_SURPLUS_BITS{1'b0}}};
    assign alpha_beta_mul_1     = mantissa_q [INPUT_FRACTION - 1] == 1'b0 ? ALPHA : BETA;

    assign res_mul_1            = mant_mul_1 * alpha_beta_mul_1;

    assign mant_add_1           = {mantissa_q, {(SUM_FRACTION - INPUT_FRACTION){1'b0}}};
    assign gamma_add_1          = {mantissa_q [INPUT_FRACTION - 1] == 1'b0 ? GAMMA_1 : GAMMA_2, {(SUM_FRACTION - CONSTANT_FRACTION){1'b0}}};

    assign res_add_1            = mant_add_1 + gamma_add_1;

    assign res_mul_2            = res_mul_1 * res_add_1;
    
    assign res_pre_inversion    = res_mul_2 >> (SUM_FRACTION + COEFFICIENT_FRACTION + MUL_SURPLUS_BITS - NOT_SURPLUS_BITS);

    assign corrected_mantissa_o = (mantissa_q [INPUT_FRACTION - 1] == 1'b0 ? res_pre_inversion : ~res_pre_inversion) >> NOT_SURPLUS_BITS;

endmodule