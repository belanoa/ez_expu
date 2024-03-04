timeunit 1ps;
timeprecision 1ps;

import expu_pkg::*;

module expu_top_tb;
    localparam TCp  = 1.0ns;
    localparam TA   = 0.2ns;

    localparam fpnew_pkg::fp_format_e   FPFORMAT        = fpnew_pkg::FP16ALT;
    localparam logic                    MANT_CORRECTION = 1'b1;
    localparam int unsigned             NUM_REGS        = 5;
    localparam int unsigned             N_ROWS          = 8;    

    localparam int unsigned WIDTH           = fpnew_pkg::fp_width(FPFORMAT);
    localparam int unsigned MANTISSA_BITS   = fpnew_pkg::man_bits(FPFORMAT);
    localparam int unsigned EXPONENT_BITS   = fpnew_pkg::exp_bits(FPFORMAT); 

    localparam int unsigned                     N_EXP   = 7;
    localparam logic                            SIGN    = 1'b0;
    localparam int unsigned                     N_MANT  = 2 ** MANTISSA_BITS;
    localparam logic [EXPONENT_BITS - 1 : 0]    MIN_EXP = 127;

    event   start_input_generation;
    event   start_recording;

    int unsigned    results;

    int unsigned    n_gen;

    logic   clk,
            rst_n,
            enable,
            clear,
            valid,
            ready;

    logic   valid_o,
            ready_o;
    logic [N_ROWS - 1 : 0] strb_o;

    logic [N_ROWS - 1 : 0] strb;

    logic [N_ROWS - 1 : 0] [WIDTH - 1 : 0]  op,
                                            res_o;

    logic [EXPONENT_BITS - 1 : 0]   exp;
    logic [MANTISSA_BITS - 1 : 0]   mant;

    expu_top #(      
        .FPFORMAT               (                       ),
        .REG_POS                (   expu_pkg::BEFORE    ),
        .NUM_REGS               (   NUM_REGS            ),
        .N_ROWS                 (   N_ROWS              ),
        .A_FRACTION             (                       ),
        .ENABLE_ROUNDING        (                       ),
        .ENABLE_MANT_CORRECTION (   MANT_CORRECTION     ),
        .COEFFICIENT_FRACTION   (                       ),
        .CONSTANT_FRACTION      (                       ),
        .MUL_SURPLUS_BITS       (                       ),
        .NOT_SURPLUS_BITS       (                       ),
        .ALPHA_REAL             (                       ),
        .BETA_REAL              (                       ),
        .GAMMA_1_REAL           (                       ),
        .GAMMA_2_REAL           (                       )
    ) expu_top_dut (
        .clk_i      (   clk     ),
        .rst_ni     (   rst_n   ),
        .clear_i    (   clear   ),
        .enable_i   (   enable  ),
        .valid_i    (   valid   ),
        .ready_i    (   ready   ),
        .strb_i     (   strb    ),
        .op_i       (   op      ),
        .res_o      (   res_o   ),
        .valid_o    (   valid_o ),
        .ready_o    (   ready_o ),
        .strb_o     (   strb_o  )
    );

    task clk_cycle;
        clk <= #(TCp / 2) 0;
        clk <= #TCp 1; 
        
        #TCp;
    endtask


    task gen_vars;
        ->start_recording;

        exp <= #TA 127;

        repeat(N_EXP) begin
            mant <= #TA'b0;

            repeat(128) begin
                clk_cycle();
                mant <= #TA mant + 1;
            end

            exp <= #TA exp + 1;
        end

        repeat(5)
            clk_cycle();

        enable <= #TA '0;
    endtask

    initial begin
        clk     <= '0;
        rst_n   <= '1;
        clear   <= '0;
        enable  <= '0;
        valid   <= '0;
        ready   <= '0;
        strb    <= '0;
        op      <= '0;

        exp <= MIN_EXP;
        mant <= 0;
        n_gen = 0;

        clk_cycle();

        rst_n <= #TA 1'b0;

        repeat(10)
            clk_cycle();

        rst_n <= #TA 1'b1;
        enable <= #TA 1'b1;
        ready <= #TA 1'b1;
        strb <= #TA 'b01010101010;

        ->start_input_generation;
        //->start_recording;

        while (1) begin
            clk_cycle();
            strb <= #TA ~strb;
            valid <= #TA ~valid;
            ready <= #TA ~ready;
        end

    end


    initial begin : input_generation
        @(start_input_generation.triggered)

        valid <= #TA 1;

        repeat(N_EXP) begin
            repeat(N_MANT) begin
                op [n_gen] <= #TA {SIGN, exp, mant};

                mant <= #TA mant + 1;

                n_gen = n_gen + 1;

                if (n_gen == N_ROWS) begin
                    n_gen = '0;
                    #TCp;
                end
            end

            exp <= #TA exp + 1;
        end

        repeat(10)
            #TCp;

        $stop;
    end


    /*initial begin : write_results
        @(start_recording.triggered)

        results = $fopen("./res.txt", "w");
        $fwrite(results, "[");

        if (MANT_CORRECTION) begin
            #(2 * TCp);
        end else begin
            #TCp;
        end

        @(res)

        repeat(128 * N_EXP) begin
            #TA;
            $fwrite(results, "0b%b,", res);
            #(TCp - TA);
        end

        $fwrite(results, "]");
        $fclose(results);
    end*/

endmodule