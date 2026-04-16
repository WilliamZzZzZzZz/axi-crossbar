# --- Agent 仿真双重保险配置开始 ---
SHELL := /bin/bash
export LM_LICENSE_FILE := 27000@localhost
export SNPSLMD_LICENSE_FILE := 27000@localhost
.PHONY: elab run clean
# --- Agent 仿真双重保险配置结束 ---

#############################
# User variables
#############################
TB        = axi_crossbar_tb
SEED      = 1
GUI      ?= 0
COV      ?= 0
DOTCL    ?= 1
VERB     ?= UVM_HIGH
OUT      ?= out
TESTNAME ?= axicb_smoke_test
RUN_LOG  ?= $(OUT)/log/run.log

DFILES   := $(sort $(wildcard ../../dut/*.v))
VFILES   := ../vip/axi_pkg.sv \
            ../vip/axi_if.sv \
            ../env/axicb_pkg.sv \
            ../testbench/axi_crossbar_tb.sv

# T shorthand:
# "make run T=smoke GUI=1 &" expands to TESTNAME=axicb_smoke_test
ifdef T
TESTNAME = axicb_$(T)_test
endif

# Support both:
#   make checkinfo CLASS=axicb_smoke_virtual_sequence
#   make checkinfo axicb_smoke_virtual_sequence
ifeq ($(firstword $(MAKECMDGOALS)),checkinfo)
ifneq ($(word 2,$(MAKECMDGOALS)),)
CLASS := $(word 2,$(MAKECMDGOALS))
CHECKINFO_EXTRA_GOALS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
.PHONY: $(CHECKINFO_EXTRA_GOALS)
$(CHECKINFO_EXTRA_GOALS):
	@:
endif
endif


#############################
# Environment variables
#############################
VCOMP_INC = +incdir+../../dut \
            +incdir+../vip \
            +incdir+../vip/seq_lib \
            +incdir+../env \
            +incdir+../seq_lib \
            +incdir+../seq_lib/element_seq \
            +incdir+../test \
            +incdir+../testbench
VCOMP    = vlogan -full64 -ntb_opts uvm-1.2 -sverilog -timescale=1ps/1ps -nc -l $(OUT)/log/comp.log $(VCOMP_INC)
ELAB     = vcs -full64 -ntb_opts uvm-1.2 -debug_acc+all -l $(OUT)/log/elab.log -sim_res=1ps -LDFLAGS -Wl,--no-as-needed
RUN      = $(OUT)/obj/$(TB).simv -l $(RUN_LOG) -sml +ntb_random_seed=$(SEED) +UVM_TESTNAME=$(TESTNAME) +UVM_VERBOSITY=$(VERB) -cm_dir $(CM_DIR) -cm_name $(CM_NAME)
COV_OPTS = -full64 -dir $(CM_DIR)
CM_DIR  ?= $(OUT)/cov.vdb
CM_NAME ?= $(TESTNAME)_$(SEED)
SIMRUNFILE = axicb_sim_run.do

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
	mkdir -p $(OUT)/work
	mkdir -p $(OUT)/log
	mkdir -p $(OUT)/sim
	mkdir -p $(OUT)/obj

comp: prepare
	vlogan -full64 -ntb_opts uvm-1.2 -sverilog -timescale=1ps/1ps -nc -l $(OUT)/log/comp_uvm.log
	$(VCOMP) $(DFILES) $(VFILES)

elab: comp
	$(ELAB) -top $(TB) -o $(OUT)/obj/$(TB).simv

run: elab
	$(RUN)

#############################
# Test shortcuts
# Usage: make smoke GUI=1 &
#############################
smoke: TESTNAME = axicb_smoke_test
smoke: run

#############################
# Regression + Coverage
# Usage: make regress
#        make regress_cov
#############################
TESTS = smoke

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
	open urgReport/dashboard.html

#############################
# Utility targets
#############################
checkinfo:
	@if [ -z "$(strip $(CLASS))" ]; then \
		echo "Usage: make checkinfo CLASS=<uvm_type_name>"; \
		echo "   or: make checkinfo <uvm_type_name>"; \
		exit 1; \
	fi
	@if [ ! -f "$(RUN_LOG)" ]; then \
		echo "Log file not found: $(RUN_LOG)"; \
		echo "Run a simulation first, for example: make smoke"; \
		exit 1; \
	fi
	@echo "Filtering UVM_INFO for [$(CLASS)] from $(RUN_LOG)"
	@grep -n -E '^UVM_INFO .*\[$(CLASS)\]' "$(RUN_LOG)" || \
	{ echo "No UVM_INFO lines found for [$(CLASS)] in $(RUN_LOG)"; exit 1; }

killdve:
	@echo "Killing all DVE processes..."
	-pkill -f dve

KEEP_FILES = Makefile axicb_debug_wave.do axicb_sim_run.do with_vcs_env.sh
clean:
	find . -maxdepth 1 ! -name '.' $(foreach f,$(KEEP_FILES),! -name '$(f)') -exec rm -rf {} +
