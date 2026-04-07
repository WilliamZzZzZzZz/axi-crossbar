#############################
# User variables
#############################
TB       	= axiram_tb
SEED     	= 1
GUI      ?= 0
COV      ?= 0
DOTCL    ?= 1
VERB     ?= UVM_HIGH
OUT      ?= out
TESTNAME ?= axiram_smoke_test
DFILES  	= ../../dut/axi_ram.v
VFILES   +=  ../vip/axi_pkg.sv \
						 ../vip/axi_if.sv \
						 ../env/axiram_pkg.sv \
						 ../testbench/axiram_tb.sv

# T= shorthand: "make run T=narrow GUI=1 &" expands to TESTNAME=axiram_narrow_test
ifdef T
TESTNAME = axiram_$(T)_test
endif


#############################
# Environment variables
#############################
VCOMP_INC = +incdir+../../dut \
						+incdir+../vip/{.,seq_lib} \
						+incdir+../{env,seq_lib,seq_lib/element_seq,test}
VCOMP    = vlogan -full64 -ntb_opts uvm-1.2 -sverilog -timescale=1ps/1ps -nc -l $(OUT)/log/comp.log $(VCOMP_INC)
ELAB     = vcs -full64 -ntb_opts uvm-1.2 -debug_acc+all -l $(OUT)/log/elab.log -sim_res=1ps -LDFLAGS -Wl,--no-as-needed
RUN      = $(OUT)/obj/$(TB).simv -l run.log -sml +ntb_random_seed=$(SEED) +UVM_TESTNAME=$(TESTNAME) +UVM_VERBOSITY=$(VERB) -cm_dir $(CM_DIR) -cm_name $(CM_NAME)
COV_OPTS = -full64 -dir $(CM_DIR)
CM_DIR  ?= $(OUT)/cov.vdb
CM_NAME ?= $(TESTNAME)_$(SEED)
SIMRUNFILE 	= axiram_sim_run.do
ifeq ($(GUI),1)
RUN += -gui
endif
ifeq ($(DOTCL),1)
RUN += -ucli -do $(SIMRUNFILE)
endif
ifeq ($(COV),1)
	ELAB  += -cm line+cond+fsm+tgl+branch+assert -cm_dir $(CM_DIR)
	RUN += -cm line+cond+fsm+tgl+branch+assert -covg_cont_on_error
endif

prepare:
	mkdir -p $(OUT)/work
	mkdir -p $(OUT)/log
	mkdir -p $(OUT)/sim
	mkdir -p $(OUT)/obj

comp: prepare
	$(VCOMP)
	$(VCOMP) $(DFILES) $(VFILES)

elab: comp
	$(ELAB) -top $(TB) -o $(OUT)/obj/$(TB).simv

run:
	$(RUN)

#############################
# Test shortcuts
# Usage: make <name> GUI=1 &
#############################
smoke: TESTNAME = axiram_smoke_test
smoke: run

fixed: TESTNAME = axiram_fixed_test
fixed: run

narrow: TESTNAME = axiram_narrow_test
narrow: run

unaligned: TESTNAME = axiram_unaligned_test
unaligned: run

reset: TESTNAME = axiram_reset_test
reset: run

pipeline: TESTNAME = axiram_pipeline_test
pipeline: run

#############################
# Regression + Coverage
# Usage: make comp COV=1 → make elab COV=1 → make regress_cov → make dvecov
#############################
TESTS = smoke fixed narrow unaligned reset pipeline

regress:
	@for t in $(TESTS); do \
		echo "===== Running $$t ====="; \
		$(MAKE) $$t COV=$(COV) || exit 1; \
	done

regress_cov:
	@for t in $(TESTS); do \
		echo "===== Running $$t with coverage ====="; \
		$(MAKE) $$t COV=1 || exit 1; \
	done
	$(MAKE) mergecov

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
