import fpnew_pkg::*;
import expu_pkg::*;

module expu_top #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT                = FP16ALT       ,
    parameter int unsigned              N_ROWS                  = 16            ,
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
    input   logic                                   clk_i       ,
    input   logic                                   rst_ni      ,
    input   logic                                   clear_i     ,
    input   logic                                   enable_i    ,
    input   logic [N_ROWS - 1 : 0] [WIDTH - 1 : 0]  op_i        ,
    output  logic [N_ROWS - 1 : 0] [WIDTH - 1 : 0]  res_o       
);

    logic   [N_ROWS - 1 : 0] [WIDTH - 1 : 0]    op_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            op_q <= '0;
        end else begin
            if (clear_i) begin
                op_q <= '0;
            end else if (enable_i) begin
                op_q <= op_i;
            end else begin
                op_q <= op_q;
            end
        end
    end

    generate
        for (genvar i = 0; i < N_ROWS; i++) begin : expu_row
            expu_row #(
                .FPFORMAT               (   FPFORMAT                ),
                .A_FRACTION             (   A_FRACTION              ),
                .ENABLE_ROUNDING        (   ENABLE_ROUNDING         ),
                .ENABLE_MANT_CORRECTION (   ENABLE_MANT_CORRECTION  ),
                .COEFFICIENT_FRACTION   (   COEFFICIENT_FRACTION    ),
                .CONSTANT_FRACTION      (   CONSTANT_FRACTION       ),
                .MUL_SURPLUS_BITS       (   MUL_SURPLUS_BITS        ),
                .NOT_SURPLUS_BITS       (   NOT_SURPLUS_BITS        ),
                .ALPHA_REAL             (   ALPHA_REAL              ),
                .BETA_REAL              (   BETA_REAL               ),
                .GAMMA_1_REAL           (   GAMMA_1_REAL            ),
                .GAMMA_2_REAL           (   GAMMA_2_REAL            )
            ) i_expu_row (
                .clk_i      (   clk_i       ),
                .rst_ni     (   rst_ni      ),
                .clear_i    (   clear_i     ),
                .enable_i   (   enable_i    ),
                .op_i       (   op_i    [i] ),
                .res_o      (   res_o   [i] )
            );
        end
    endgenerate

endmodule