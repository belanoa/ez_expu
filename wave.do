onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -group expu_top /expu_top_tb/expu_top_dut/*
add wave -group expu_top -group expu_row /expu_top_tb/expu_top_dut/expu_row[0]/i_expu_row/*
add wave -group expu_top -group expu_row -group expu_schraudolph /expu_top_tb/expu_top_dut/expu_row[0]/i_expu_row/expu_schraudolph/*
add wave -group expu_top -group expu_row -group expu_correction /expu_top_tb/expu_top_dut/expu_row[0]/i_expu_row/genblk3/expu_correction/*