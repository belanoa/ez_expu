`include "common_cells/registers.svh"

import fpnew_pkg::*;
import expu_pkg::*;

module expu_row #(
    parameter fpnew_pkg::fp_format_e    FPFORMAT                = fpnew_pkg::FP16ALT    ,
    parameter expu_pkg::regs_config_t   REG_POS                 = expu_pkg::BEFORE      ,
    parameter int unsigned              NUM_REGS                = 0                     ,
    parameter int unsigned              A_FRACTION              = 14                    ,
    parameter int unsigned              ENABLE_ROUNDING         = 1                     ,
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
    input   logic                   clk_i       ,
    input   logic                   rst_ni      ,
    input   logic                   clear_i     ,
    input   logic                   enable_i    ,
    input   logic [WIDTH - 1 : 0]   op_i        ,
    output  logic [WIDTH - 1 : 0]   res_o            
);

    logic [WIDTH - 1 : 0]           res_sch,
                                    res_cor;

    logic [WIDTH - 1 : 0]           result;

    logic [NUM_REGS : 0] [WIDTH - 1 : 0] reg_data;

    logic [WIDTH - 1 : 0]   op_before,
                            op_after;

    generate
        if (REG_POS == fpnew_pkg::BEFORE) begin
            assign reg_data [0] = op_i;
            assign op_before    = reg_data [NUM_REGS];
            assign res_o        = result;
        end else if (REG_POS == fpnew_pkg::AFTER) begin
            assign reg_data [0] = result;
            assign res_o        = reg_data [NUM_REGS];
            assign op_before    = op_i;
        end
    endgenerate

    generate
        for (genvar i = 0; i < NUM_REGS; i ++) begin : gen_regs
            `FFLARNC(reg_data [i + 1],  reg_data [i],   enable_i,   clear_i,    '0)
        end
    endgenerate

    expu_schraudolph #(
        .FPFORMAT       (   FPFORMAT        ),
        .A_FRACTION     (   A_FRACTION      ),
        .ENABLE_ROUNDING(   ENABLE_ROUNDING )
    ) expu_schraudolph (
        .op_i   (   op_i    ),
        .res_o  (   res_sch )  
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
                .op_i   (   res_sch ), 
                .res_o  (   res_cor )   
            );

            `FFLARNC()

            assign result   = res_cor;
        end else begin
            assign result   = res_sch;
        end
    endgenerate

endmodule