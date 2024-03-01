`include "common_cells/registers.svh"

import fpnew_pkg::*;
import expu_pkg::*;

module expu_top #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT                = fpnew_pkg::FP16ALT    ,
    parameter expu_pkg::regs_config_t   REG_POS                 = expu_pkg::BEFORE      ,
    parameter int unsigned              NUM_REGS                = 0                     ,
    parameter int unsigned              N_ROWS                  = 1                     ,
    parameter int unsigned              A_FRACTION              = 14                    ,
    parameter logic                     ENABLE_ROUNDING         = 1                     ,
    parameter logic                     ENABLE_MANT_CORRECTION  = 1                     ,
    parameter int unsigned              COEFFICIENT_FRACTION    = 4                     ,
    parameter int unsigned              CONSTANT_FRACTION       = 7                     ,
    parameter int unsigned              MUL_SURPLUS_BITS        = 1                     ,
    parameter int unsigned              NOT_SURPLUS_BITS        = 0                     ,
    parameter real                      ALPHA_REAL              = 0.24609375            ,
    parameter real                      BETA_REAL               = 0.41015625            ,
    parameter real                      GAMMA_1_REAL            = 2.8359375             ,
    parameter real                      GAMMA_2_REAL            = 2.16796875            ,

    localparam int unsigned WIDTH           = fpnew_pkg::fp_width(FPFORMAT) ,
    localparam int unsigned MANTISSA_BITS   = fpnew_pkg::man_bits(FPFORMAT) ,
    localparam int unsigned EXPONENT_BITS   = fpnew_pkg::exp_bits(FPFORMAT)
) (
    input   logic                                   clk_i       ,
    input   logic                                   rst_ni      ,
    input   logic                                   clear_i     ,
    input   logic                                   enable_i    ,
    input   logic                                   valid_i     ,
    input   logic                                   ready_i     ,
    input   logic [N_ROWS]                          strb_i      ,
    input   logic [N_ROWS - 1 : 0] [WIDTH - 1 : 0]  op_i        ,
    output  logic [N_ROWS - 1 : 0] [WIDTH - 1 : 0]  res_o       ,
    output  logic                                   valid_o     ,
    output  logic                                   ready_o     ,
    output  logic                                   strb_o
);

    logic   [N_ROWS : 0]    valid_reg;
    
    logic reg_en;

    generate
        for (genvar i = 0; i < N_ROWS; i++) begin : expu_row
            expu_row #(
                .FPFORMAT               (   FPFORMAT                ),
                .REG_POS                (   REG_POS                 ),
                .NUM_REGS               (   NUM_REGS                ),
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
                .clk_i      (   clk_i                   ),
                .rst_ni     (   rst_ni                  ),
                .clear_i    (   clear_i                 ),
                .enable_i   (   strb_i  [i] & reg_en    ),
                .op_i       (   op_i    [i]             ),
                .res_o      (   res_o   [i]             )
            );
        end
    endgenerate

    generate
        for (genvar i = 0; i < NUM_REGS; i++) begin : control_signals_registers
            `FFLARNC(valid_reg [i + 1], valid_reg [i],  reg_en, clear_i,    '0, clk_i,  rst_ni)
        end
    endgenerate

    assign ready_o = ready_i;
    assign reg_en  = enable_i & valid_i & ready_o;

endmodule