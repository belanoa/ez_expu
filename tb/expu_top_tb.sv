timeunit 1ps;
timeprecision 1ps;

module expu_top_tb;
    localparam TCp  = 1.0ns;
    localparam TA   = 0.2ns;

    localparam int unsigned     EXPONENT_BITS   = 8;
    localparam int unsigned     MANTISSA_BITS   = 7;

    localparam int unsigned     N_EXP           = 1;
    localparam logic            SIGN            = 1'b0;

    localparam logic            MANT_CORRECTION = 1'b1;

    event   start_recording;

    int unsigned    results;

    logic   clk,
            rst_n,
            enable,
            clear;

    logic [EXPONENT_BITS - 1 : 0]               exp;
    logic [MANTISSA_BITS - 1 : 0]               mant;
    logic [EXPONENT_BITS + MANTISSA_BITS : 0]   res;

    expu_top #(
        .MANTISSA_BITS          (   7               ),           
        .EXPONENT_BITS          (   8               ),         
        .A_FRACTION             (                   ),
        .ENABLE_ROUNDING        (   1               ),              
        .ENABLE_MANT_CORRECTION (   MANT_CORRECTION ),  
        .COEFFICIENT_FRACTION   (                   ),    
        .CONSTANT_FRACTION      (                   ),       
        .MUL_SURPLUS_BITS       (   1               ),        
        .NOT_SURPLUS_BITS       (   0               )        
    ) expu_top_dut (
        .clk_i      (   clk                 ),
        .rst_ni     (   rst_n               ),
        .clear_i    (   clear               ),
        .enable_i   (   enable              ),
        .float_i    (   {SIGN, exp, mant}   ),
        .float_o    (   res                 )            
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
        clk <= 1'b0;
        rst_n <= 1'b1;
        exp <= '0;
        mant <= '0;
        enable <= '0;
        clear <= '0;

        clk_cycle();

        rst_n <= #TA 1'b0;

        repeat(10)
            clk_cycle();

        rst_n <= #TA 1'b1;
        enable <= #TA 1'b1;

        clk_cycle();
        gen_vars();

        $stop;
    end


    initial begin : write_results
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
    end

endmodule