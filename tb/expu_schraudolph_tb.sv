`timescale 1ns/1ps

module expu_schraudolph_tb;

    logic [6:0] mant;
    logic [7:0] exp;

    logic [15:0] bf_in;
    logic [7:0]  exp_out;
    logic [6:0]  mant_out;

    int results;

    expu_schraudolph #(
        .A_FRACTION (   14          )
    ) expu_schraudolph_dut (
        .float_i    (   bf_in       )   ,
        .exponent_o (   exp_out     )   ,
        .mantissa_o (   mant_out    )
    );

    initial begin
        results = $fopen("./res.txt", "w");
        exp = 127 + 0;

        $fwrite(results, "[");

        repeat(5) begin
            mant = 'b0;

            repeat(128) begin
                bf_in = {1'b1, exp, mant};

                #1

                $fwrite(results, "0b%b%b,", exp_out, mant_out);
            
                mant = mant + 1;
            end

            exp = exp + 1;
        end

        $fwrite(results, "]");
        $fclose(results);
    end

endmodule