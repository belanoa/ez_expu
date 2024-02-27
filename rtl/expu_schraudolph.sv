module expu_schraudolph #(
    parameter int unsigned  MANTISSA_BITS   = 7     ,
    parameter int unsigned  EXPONENT_BITS   = 8     ,
    parameter int unsigned  A_FRACTION      = 14    ,
    parameter logic         ENABLE_ROUNDING = 1     
) (
    input   logic                                       clk_i       ,
    input   logic                                       enable_i    ,
    input   logic                                       clear_i     ,
    input   logic                                       rst_ni      ,
    input   logic [MANTISSA_BITS + EXPONENT_BITS : 0]   float_i     ,
    output  logic [MANTISSA_BITS - 1 : 0]               mantissa_o  ,
    output  logic [EXPONENT_BITS - 1 : 0]               exponent_o  
);

    localparam real         A_REAL              = 1 / $ln(2);

    localparam int unsigned A_INT_BITS          = $clog2(int'(A_REAL)) + 1;
    localparam int unsigned MANTISSA_INT_BITS   = 1;

    localparam int unsigned BIAS                = 2 ** (EXPONENT_BITS - 1) - 1;
    localparam int unsigned MAX_EXP             = BIAS + (EXPONENT_BITS - (A_INT_BITS + MANTISSA_INT_BITS));

    //Q<A_INT_BITS.A_FRACTION>
    localparam logic [A_INT_BITS + A_FRACTION - 1 : 0]  A   = int'(A_REAL * 2 ** A_FRACTION);

    logic [MANTISSA_BITS + EXPONENT_BITS : 0]   float_q;

    logic                                       sign;
    logic [EXPONENT_BITS - 1 : 0]               exponent;
    //Q<1.MANTISSA_BITS>
    logic [MANTISSA_BITS : 0]                   mantissa;

    //Q<2.MANTISSA_BITS + A_FRACTION>
    logic [MANTISSA_BITS + A_FRACTION + A_INT_BITS : 0]     scaled_mantissa;

    logic [EXPONENT_BITS + MANTISSA_BITS : 0]               shifted_mantissa;
    logic [EXPONENT_BITS + MANTISSA_BITS - 1 : 0]           rounded_mantissa;
    logic [EXPONENT_BITS + MANTISSA_BITS - 1 : 0]           signed_mantissa;

    logic [EXPONENT_BITS - 1 : 0]   new_exponent;
    logic [MANTISSA_BITS - 1 : 0]   new_mantissa;

    logic   ovfr    ;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            float_q <= '0;
        end else begin
            if (clear_i) begin
                float_q <= '0;
            end else if (enable_i) begin
                float_q <= float_i;
            end else begin
                float_q <= float_q;
            end
        end
    end

    assign sign     =   float_q   [MANTISSA_BITS + EXPONENT_BITS];
    assign exponent =   float_q   [MANTISSA_BITS + EXPONENT_BITS - 1 : MANTISSA_BITS];
    assign mantissa =   {1'b1, float_q [MANTISSA_BITS - 1 : 0]};

    assign scaled_mantissa  =   (mantissa * A);
    assign shifted_mantissa =   (scaled_mantissa [MANTISSA_BITS + A_FRACTION + A_INT_BITS : A_FRACTION - MANTISSA_BITS] >> (MAX_EXP - exponent));
    assign rounded_mantissa =   shifted_mantissa [EXPONENT_BITS + MANTISSA_BITS : 1] + ENABLE_ROUNDING ? shifted_mantissa [0] : '0;
    assign signed_mantissa  =   sign == 1'b0 ? rounded_mantissa : -rounded_mantissa;

    assign ovfr =   (exponent > MAX_EXP) || (
                        (exponent == MAX_EXP) && (
                            scaled_mantissa [MANTISSA_BITS + A_FRACTION + A_INT_BITS] || (
                                (sign == 1'b1) && 
                                &scaled_mantissa [MANTISSA_BITS + A_FRACTION + A_INT_BITS - 1 -: EXPONENT_BITS]
                            )
                        )
                    );

    always_comb begin
        if (~ovfr) begin
            new_exponent    =   signed_mantissa [EXPONENT_BITS + MANTISSA_BITS - 1 : MANTISSA_BITS] + BIAS;
            new_mantissa    =   signed_mantissa [MANTISSA_BITS - 1 : 0];
        end else begin
            new_exponent    =   sign == 1'b0 ? '1 : '0;
            new_mantissa    =   '0;
        end
    end

    assign mantissa_o   =   new_mantissa;
    assign exponent_o   =   new_exponent;

endmodule