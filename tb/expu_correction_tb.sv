`timescale 1ns/1ps

module expu_correction_tb;

    logic [6:0] mant_in;
    logic [6:0] mant_out;

    int results;

    expu_correction #(
        .INPUT_FRACTION         (7  )       ,
        .COEFFICIENT_FRACTION   (4  )       ,
        .CONSTANT_FRACTION      (7  )       ,
        .MUL_SURPLUS_BITS       (1  )       ,
        .NOT_SURPLUS_BITS       (0  )
    ) exp_cor_dut (
        .mantissa_i             (   mant_in     )   ,
        .corrected_mantissa_o   (   mant_out    )
    );

    initial begin
        results = $fopen("./res.txt", "w");

        mant_in = 'b0;

        $fdisplay(results, "[");

        repeat(128) begin
            #1

            $fdisplay(results, "0x%0h,", mant_out);
            mant_in = mant_in + 'b1;
        end

        $fdisplay(results, "]");
        $fclose(results);
    end

endmodule