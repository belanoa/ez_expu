timeunit 1ps;
timeprecision 1ps;

import expu_pkg::*;

class rng;
    int unsigned seed;

    function new(int unsigned seed);
        this.seed = seed;
    endfunction

    function int unsigned next;
        this.seed = $urandom(this.seed);

        return this.seed;
    endfunction
endclass

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

    localparam real P_STALL_GEN = 0.10;
    localparam real P_STALL_RCV = 0.10;

    localparam int unsigned SEED = 42;

    event   start_input_generation;
    event   start_recording;

    logic   gen_stall,
            rcv_stall;

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


    property ready_i_check;
        @(posedge clk) (valid_o && ~ready) |=> ($stable(res_o) && $stable(strb_o))
    endproperty

    property strb_o_check(strb, res);
            @(posedge clk) disable iff (~rst_n) (strb == 0) |-> (res == $past(res))
    endproperty

    assert property (ready_i_check);

    for (genvar i = 0; i < N_ROWS; i++) begin
        assert property (strb_o_check(strb_o [i], res_o [i]));
    end
    

    task clk_cycle;
        clk <= #(TCp / 2) 0;
        clk <= #TCp 1; 
        
        #TCp;
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

        exp = MIN_EXP;
        mant = 0;

        clk_cycle();

        rst_n <= #TA 1'b0;

        repeat(10)
            clk_cycle();

        rst_n <= #TA 1'b1;
        enable <= #TA 1'b1;

        ->start_input_generation;

        while (1) begin
            clk_cycle();
        end

    end

    initial begin : input_generation
        rng random = new(SEED);

        @(start_input_generation.triggered)

        repeat(N_EXP) begin
            repeat(N_MANT) begin
                do begin
                    gen_stall = random.next() < int'(real'(unsigned'(2 ** 32 - 1)) * P_STALL_GEN);
                    rcv_stall = random.next() < int'(real'(unsigned'(2 ** 32 - 1)) * P_STALL_GEN);

                    valid <= #TA ~gen_stall;
                    ready <= #TA ~rcv_stall;

                    if (gen_stall) begin
                        #TCp;
                    end
                end while (gen_stall);

                strb <= #TA random.next();
                op <= #TA {N_ROWS{SIGN, exp, mant}};

                mant = mant + 1;

                #TCp;
            end

            exp = exp + 1;
        end

        repeat(10)
            #TCp;

        $stop;
    end

endmodule