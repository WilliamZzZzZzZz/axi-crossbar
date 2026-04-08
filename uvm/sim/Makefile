#############################
# User variables
#############################
TB        = axiram_tb
SEED      = 1
GUI      ?= 0
COV      ?= 0
DOTCL    ?= 1
VERB     ?= UVM_MEDIUM
OUT      ?= out
TESTNAME ?= axiram_crossbar_smoke_test

DFILES = \
    ../../dut/priority_encoder.v \
    ../../dut/arbiter.v \
    ../../dut/axi_register_wr.v \
    ../../dut/axi_register_rd.v \
    ../../dut/axi_crossbar_addr.v \
    ../../dut/axi_crossbar_wr.v \
    ../../dut/axi_crossbar_rd.v \
    ../../dut/axi_crossbar.v \
    ../../dut/axi_crossbar_wrap_2x2.v

VFILES = \
    ../vip/axi_if.sv \
    ../vip/axi_pkg.sv \
    ../env/axiram_pkg.sv \
    ../testbench/axiram_tb.sv

ifdef T
TESTNAME = axiram_crossbar_$(T)_test
endif

#############################
# Environment variables
#############################
VCOMP_INC = \
    +incdir+../../dut \
    +incdir+../vip \
    +incdir+../vip/seq_lib \
    +incdir+../env \
    +incdir+../seq_lib \
    +incdir+../seq_lib/element_seq \
    +incdir+../test

VCOMP = vlogan -full64 -ntb_opts uvm-1.2 -sverilog -timescale=1ps/1ps -nc -l $(OUT)/log/comp.log $(VCOMP_INC)
ELAB  = vcs -full64 -ntb_opts uvm-1.2 -debug_acc+all -l $(OUT)/log/elab.log -sim_res=1ps -LDFLAGS -Wl,--no-as-needed
RUN   = $(OUT)/obj/$(TB).simv -l run.log -sml +ntb_random_seed=$(SEED) +UVM_TESTNAME=$(TESTNAME) +UVM_VERBOSITY=$(VERB) -cm_dir $(CM_DIR) -cm_name $(CM_NAME)

COV_OPTS = -full64 -dir $(CM_DIR)
CM_DIR  ?= $(OUT)/cov.vdb
CM_NAME ?= $(TESTNAME)_$(SEED)
SIMRUNFILE = axiram_sim_run.do

ifeq ($(GUI),1)
RUN += -gui
endif
ifeq ($(DOTCL),1)
RUN += -ucli -do $(SIMRUNFILE)
endif
ifeq ($(COV),1)
ELAB += -cm line+cond+fsm+tgl+branch+assert -cm_dir $(CM_DIR)
RUN  += -cm line+cond+fsm+tgl+branch+assert -covg_cont_on_error
endif

prepare:
	mkdir -p $(OUT)/work $(OUT)/log $(OUT)/sim $(OUT)/obj

comp: prepare
	$(VCOMP)
	$(VCOMP) $(DFILES) $(VFILES)

elab: comp
	$(ELAB) -top $(TB) -o $(OUT)/obj/$(TB).simv

run: elab
	$(RUN)

#############################
# Test shortcuts
#############################
smoke: TESTNAME = axiram_crossbar_smoke_test
smoke: run

crossbar_smoke: smoke

#############################
# Coverage targets
#############################
mergecov:
	urg -format both $(COV_OPTS)

dvecov:
	dve -cov $(COV_OPTS)

verdicov:
	verdi -cov -covdir $(CM_DIR)

htmlcov:
	firefox urgReport/dashboard.html

#############################
# Utility targets
#############################
killdve:
	@echo "Killing all DVE processes..."
	-pkill -f dve

KEEP_FILES = Makefile axiram_debug_wave.do axiram_sim_run.do
clean:
	find . -maxdepth 1 ! -name '.' $(foreach f,$(KEEP_FILES),! -name '$(f)') -exec rm -rf {} +
