module expu_top #(
    parameter   int unsigned    MANTISSA_BITS           = 7                 ,
    parameter   int unsigned    EXPONENT_BITS           = 8                 ,
    parameter   int unsigned    A_FRACTION              = MANTISSA_BITS * 2 ,
    parameter   int unsigned    ENABLE_ROUNDING         = 1                 ,
    parameter   logic           ENABLE_MANT_CORRECTION  = 1                 ,
    parameter   int unsigned    COEFFICIENT_FRACTION    = MANTISSA_BITS     ,
    parameter   int unsigned    CONSTANT_FRACTION       = MANTISSA_BITS     ,
    parameter   int unsigned    MUL_SURPLUS_BITS        = 1                 ,
    parameter   int unsigned    NOT_SURPLUS_BITS        = 0
) (
    input   logic                                       clk_i       ,
    input   logic                                       rst_ni      ,
    input   logic                                       clear_i     ,
    input   logic                                       enable_i    ,
    input   logic [MANTISSA_BITS + EXPONENT_BITS : 0]   float_i     ,
    output  logic [MANTISSA_BITS + EXPONENT_BITS : 0]   float_o            
);

    logic [MANTISSA_BITS - 1 : 0]               mant_sch,
                                                mant_cor;
    logic [EXPONENT_BITS -1 : 0]                exp_sch;
    logic [MANTISSA_BITS + EXPONENT_BITS : 0]   result;

    logic [EXPONENT_BITS - 1 : 0]               exponent_q;

    expu_schraudolph #(
        .MANTISSA_BITS  (   MANTISSA_BITS   ),
        .EXPONENT_BITS  (   EXPONENT_BITS   ),
        .A_FRACTION     (   A_FRACTION      ),
        .ENABLE_ROUNDING(   ENABLE_ROUNDING )
    ) expu_schraudolph (
        .clk_i          (   clk_i           ),
        .enable_i       (   enable_i        ), 
        .clear_i        (   clear_i         ), 
        .rst_ni         (   rst_ni          ), 
        .float_i        (   float_i         ),
        .mantissa_o     (   mant_sch        ), 
        .exponent_o     (   exp_sch         )   
    );

    generate
        if (ENABLE_MANT_CORRECTION) begin
            expu_correction #(
                .INPUT_FRACTION         (   MANTISSA_BITS           ),
                .COEFFICIENT_FRACTION   (   COEFFICIENT_FRACTION    ),
                .CONSTANT_FRACTION      (   CONSTANT_FRACTION       ),
                .MUL_SURPLUS_BITS       (   MUL_SURPLUS_BITS        ),
                .NOT_SURPLUS_BITS       (   NOT_SURPLUS_BITS        )
            ) expu_correction (
                .clk_i                  (   clk_i                   ),
                .enable_i               (   enable_i                ),
                .clear_i                (   clear_i                 ), 
                .rst_ni                 (   rst_ni                  ), 
                .mantissa_i             (   mant_sch                ), 
                .corrected_mantissa_o   (   mant_cor                )   
            );

            always_ff @(posedge clk_i or negedge rst_ni) begin
                if (~rst_ni) begin
                    exponent_q <= '0;
                end else begin
                    if (clear_i) begin
                        exponent_q <= '0;
                    end else if (enable_i) begin
                        exponent_q <= exp_sch;
                    end else begin
                        exponent_q <= exponent_q;
                    end
                end
            end

            assign result   = {1'b0, exponent_q, mant_cor};
        end else begin
            assign result   = {1'b0, exp_sch, mant_sch};
        end
    endgenerate

    assign float_o  = result;

endmodule