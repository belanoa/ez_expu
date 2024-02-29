mkfile_path := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))
BUILD_DIR  	?= $(mkfile_path)/work
BENDER_DIR	?= .
BENDER_NAME	?= bender
QUESTA      ?= #questa-2020.1

BENDER			?= $(BENDER_DIR)/$(BENDER_NAME)

compile_script 	?= scripts/compile.tcl
compile_flag  	?= -suppress 2583 -suppress 13314

#bender_defs += -D COREV_ASSERT_OFF

sim_targs += -t rtl
sim_targs += -t test
#bender_targs += -t cv32e40p_exclude_tracer
sim_targs += -t expu_sim

INI_PATH  = $(mkfile_path)/modelsim.ini
WORK_PATH = $(BUILD_DIR)

tb := expu_top_tb

gui      ?= 0
P_STALL  ?= 0.0

# Run the simulation
run: $(CRT)
ifeq ($(gui), 0)
	cd $(BUILD_DIR)/$(TEST_SRCS);          \
	$(QUESTA) vsim -c vopt_tb -do "run -a" \
	-gSTIM_INSTR=stim_instr.txt            \
	-gSTIM_DATA=stim_data.txt              \
	-gPROB_STALL=$(P_STALL)
else
	cd $(BUILD_DIR)/$(TEST_SRCS); \
	$(QUESTA) vsim vopt_tb        \
	-do "add log -r sim:/$(tb)/*" \
	-do "source $(WAVES)"         \
	-gSTIM_INSTR=stim_instr.txt   \
	-gSTIM_DATA=stim_data.txt     \
	-gPROB_STALL=$(P_STALL)
endif

bender:
	curl --proto '=https'  \
	--tlsv1.2 https://pulp-platform.github.io/bender/init -sSf

update-ips:
	$(BENDER) update
	$(BENDER) script vsim          \
	--vlog-arg="$(compile_flag)"   \
	--vcom-arg="-pedanticerrors"   \
	$(bender_targs) $(bender_defs) \
	$(sim_targs)    $(sim_deps)    \
	> ${compile_script}

hw-opt:
	$(QUESTA) vopt +acc=npr -o vopt_tb $(tb) -floatparameters+$(tb) -work $(BUILD_DIR)

hw-compile:
	$(QUESTA) vsim -c +incdir+$(UVM_HOME) -do 'quit -code [source $(compile_script)]'

hw-lib:
	@touch modelsim.ini
	@mkdir -p $(BUILD_DIR)
	@$(QUESTA) vlib $(BUILD_DIR)
	@$(QUESTA) vmap work $(BUILD_DIR)
	@chmod +w modelsim.ini

hw-clean:
	rm -rf transcript
	rm -rf modelsim.ini


hw-all: hw-clean hw-lib hw-compile hw-opt