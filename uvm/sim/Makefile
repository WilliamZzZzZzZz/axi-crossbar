# --- Agent 仿真双重保险配置开始 ---
SHELL := /bin/bash
LM_LICENSE_FILE ?= 27000@localhost
SNPSLMD_LICENSE_FILE ?= $(LM_LICENSE_FILE)
export LM_LICENSE_FILE
export SNPSLMD_LICENSE_FILE
.DEFAULT_GOAL := help
.PHONY: help prepare comp elab run smoke decerr regress regress_cov mergecov dvecov verdicov htmlcov check checkinfo killdve clean
# --- Agent 仿真双重保险配置结束 ---

help: ## Show grouped help for simulation targets
	@awk 'BEGIN { \
		FS = ":.*## "; \
		print ""; \
		print "Usage:"; \
		print "  make <target> [VAR=value]"; \
	} \
	/^##@/ { \
		printf "\n%s\n", substr($$0, 5); \
	} \
	/^[a-zA-Z0-9_.-]+:.*## / { \
		printf "  %-14s %s\n", $$1, $$2; \
	} \
	END { \
		print ""; \
		print "Common variables:"; \
		print "  T=<name>       Expand TESTNAME to axicb_<name>_test for make run"; \
		print "  TESTNAME=<id>  Override the UVM test class"; \
		print "  SEED=<n>       Override +ntb_random_seed"; \
		print "  GUI=1          Launch DVE GUI"; \
		print "  COV=1          Enable coverage during elab/run"; \
		print "  DOTCL=0        Skip -ucli -do axicb_sim_run.do"; \
		print "  VERB=<level>   Override +UVM_VERBOSITY"; \
		print "  OUT=<dir>      Redirect generated artifacts"; \
		print "  RUN_LOG=<path> Read a different simulation log"; \
		print "  TESTS=\"...\"    Override regression target list"; \
		print "  CM_DIR=<dir>    Override the coverage database location"; \
		print "  CM_NAME=<name>  Override the coverage run name"; \
		print ""; \
		print "Examples:"; \
		print "  make smoke"; \
		print "  make run T=decerr GUI=1"; \
		print "  make regress COV=1"; \
		print "  make check error"; \
		print "  make checkinfo axicb_smoke_virtual_sequence"; \
	}' $(MAKEFILE_LIST)

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

# Support: make check <error|warning|info|fatal>
ifeq ($(firstword $(MAKECMDGOALS)),check)
ifneq ($(word 2,$(MAKECMDGOALS)),)
SEVERITY := $(word 2,$(MAKECMDGOALS))
CHECK_EXTRA_GOALS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
.PHONY: $(CHECK_EXTRA_GOALS)
$(CHECK_EXTRA_GOALS):
	@:
endif
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

##@ Setup
prepare: ## Create output directories under $(OUT)
	mkdir -p $(OUT)/work
	mkdir -p $(OUT)/log
	mkdir -p $(OUT)/sim
	mkdir -p $(OUT)/obj

##@ Simulation
comp: prepare ## Compile UVM and RTL sources
	vlogan -full64 -ntb_opts uvm-1.2 -sverilog -timescale=1ps/1ps -nc -l $(OUT)/log/comp_uvm.log
	$(VCOMP) $(DFILES) $(VFILES)

elab: comp ## Elaborate the compiled design into $(OUT)/obj/$(TB).simv
	$(ELAB) -top $(TB) -o $(OUT)/obj/$(TB).simv

run: elab ## Run the simulation with the selected TESTNAME/SEED/GUI/COV knobs
	$(RUN)

##@ Tests
smoke: TESTNAME = axicb_smoke_test
smoke: run ## Run the default smoke test

decerr_single: TESTNAME = axicb_decerr_single_test
decerr_single: run ## Run the DECERR-single test

decerr_burst: TESTNAME = axicb_decerr_burst_test
decerr_burst: run ## Run the DECERR-burst test

decerr_id: TESTNAME = axicb_decerr_id_test
decerr_id: run ## Run the DECERR-id test

decerr_dual_mst: TESTNAME = axicb_decerr_dual_mst_test
decerr_dual_mst: run ## Run the DECERR-dual-master test

##@ Regression
TESTS ?= smoke

regress: ## Run each test listed in TESTS with the current knobs
	@for t in $(TESTS); do \
		echo "===== Running $$t ====="; \
		$(MAKE) $$t COV=$(COV) || exit 1; \
	done

regress_cov: ## Run TESTS with coverage enabled, then merge the databases
	@for t in $(TESTS); do \
		echo "===== Running $$t with coverage ====="; \
		$(MAKE) $$t COV=1 || exit 1; \
	done
	$(MAKE) mergecov

##@ Coverage
mergecov: ## Merge coverage data in $(CM_DIR) with urg
	urg -format both $(COV_OPTS)

dvecov: ## Open merged coverage in DVE
	dve -cov $(COV_OPTS)

verdicov: ## Open merged coverage in Verdi
	verdi -cov -covdir $(CM_DIR)

htmlcov: ## Open the generated urg HTML dashboard
	open urgReport/dashboard.html

##@ Utility
check: ## Grep UVM messages by severity: make check <error|warning|info|fatal>
	@if [ -z "$(strip $(SEVERITY))" ]; then \
		echo "Usage: make check <error|warning|info|fatal>"; \
		exit 1; \
	fi
	@if [ ! -f "$(RUN_LOG)" ]; then \
		echo "Log file not found: $(RUN_LOG)"; \
		echo "Run a simulation first, e.g.: make smoke"; \
		exit 1; \
	fi
	@SEV=$$(echo "$(SEVERITY)" | tr '[:lower:]' '[:upper:]'); \
	echo "========== UVM_$$SEV from $(RUN_LOG) =========="; \
	grep -n "^UVM_$$SEV [^:]" "$(RUN_LOG)" || echo "(none found)"; \
	echo "================================================"; \
	COUNT=$$(grep -c "^UVM_$$SEV [^:]" "$(RUN_LOG)" 2>/dev/null); \
	echo "Total: $$COUNT UVM_$$SEV message(s)"

checkinfo: ## Grep UVM_INFO lines by class: make checkinfo <uvm_type_name>
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

killdve: ## Kill all running DVE processes
	@echo "Killing all DVE processes..."
	-pkill -f dve

KEEP_FILES = Makefile axicb_debug_wave.do axicb_sim_run.do with_vcs_env.sh README.md
clean: ## Remove generated files while keeping helper scripts in this directory
	find . -maxdepth 1 ! -name '.' $(foreach f,$(KEEP_FILES),! -name '$(f)') -exec rm -rf {} +
