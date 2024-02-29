import fpnew_pkg::*;
import expu_pkg::*;

module expu_top #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT                = FP16ALT       ,
    parameter int unsigned              A_FRACTION              = 14            ,
    parameter int unsigned              ENABLE_ROUNDING         = 1             ,
    parameter logic                     ENABLE_MANT_CORRECTION  = 1             ,
    parameter int unsigned              COEFFICIENT_FRACTION    = 4             ,
    parameter int unsigned              CONSTANT_FRACTION       = 7             ,
    parameter int unsigned              MUL_SURPLUS_BITS        = 1             ,
    parameter int unsigned              NOT_SURPLUS_BITS        = 0             ,
    parameter real                      ALPHA_REAL              = 0.24609375    ,
    parameter real                      BETA_REAL               = 0.41015625    ,
    parameter real                      GAMMA_1_REAL            = 2.8359375     ,
    parameter real                      GAMMA_2_REAL            = 2.16796875    ,

    localparam int unsigned WIDTH           = fpnew_pkg::fp_width(FPFORMAT) ,
    localparam int unsigned MANTISSA_BITS   = fpnew_pkg::man_bits(FPFORMAT) ,
    localparam int unsigned EXPONENT_BITS   = fpnew_pkg::exp_bits(FPFORMAT)
) (
    input   logic                   clk_i       ,
    input   logic                   rst_ni      ,
    input   logic                   clear_i     ,
    input   logic                   enable_i    ,
    input   logic [WIDTH - 1 : 0]   op_i        ,
    output  logic [WIDTH - 1 : 0]   res_o            
);

    logic [MANTISSA_BITS - 1 : 0]   mant_sch,
                                    mant_cor;
    logic [EXPONENT_BITS -1 : 0]    exp_sch;
    logic [WIDTH - 1 : 0]           result;

    logic [EXPONENT_BITS - 1 : 0]   exponent_q;

    expu_schraudolph #(
        .FPFORMAT       (   FPFORMAT        ),
        .A_FRACTION     (   A_FRACTION      ),
        .ENABLE_ROUNDING(   ENABLE_ROUNDING )
    ) expu_schraudolph (
        .clk_i          (   clk_i           ),
        .enable_i       (   enable_i        ), 
        .clear_i        (   clear_i         ), 
        .rst_ni         (   rst_ni          ), 
        .op_i           (   op_i         ),
        .mantissa_o     (   mant_sch        ), 
        .exponent_o     (   exp_sch         )   
    );

    generate
        if (ENABLE_MANT_CORRECTION) begin
            expu_correction #(
                .COEFFICIENT_FRACTION   (   COEFFICIENT_FRACTION    ),
                .CONSTANT_FRACTION      (   CONSTANT_FRACTION       ),
                .MUL_SURPLUS_BITS       (   MUL_SURPLUS_BITS        ),
                .NOT_SURPLUS_BITS       (   NOT_SURPLUS_BITS        ),
                .ALPHA_REAL             (   ALPHA_REAL              ),
                .BETA_REAL              (   BETA_REAL               ),
                .GAMMA_1_REAL           (   GAMMA_1_REAL            ),
                .GAMMA_2_REAL           (   GAMMA_2_REAL            ) 
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

    assign res_o  = result;

endmodule