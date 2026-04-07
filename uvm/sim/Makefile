#############################
# User variables
#############################
TB       	= rkv_axiram_tb
SEED     	= 1
GUI      ?= 0
COV      ?= 0
DOTCL    ?= 1
OUT      ?= out
TESTNAME ?= rkv_axiram_smoke_test

DFILES  	= ../../verilog/axi_ram.v

VFILES   +=  ../vip_lib/lvc_axi/lvc_axi_pkg.sv \
						 ../vip_lib/lvc_axi/lvc_axi_if.sv \
						 ../env/rkv_axiram_pkg.sv \
						 ../tb/rkv_axiram_if.sv \
						 ../tb/rkv_axiram_tb.sv


#############################
# Environment variables
#############################
VCOMP_INC = +incdir+../../verilog \
						+incdir+../vip_lib/lvc_axi \
						+incdir+../{cfg,cov,reg,env,seq_lib,seq_lib/elem_seqs,test} 

VCOMP    = vlogan -full64 -ntb_opts uvm-1.2 -sverilog -timescale=1ps/1ps -nc -l $(OUT)/log/comp.log $(VCOMP_INC)
ELAB     = vcs -full64 -ntb_opts uvm-1.2 -debug_acc+all -l $(OUT)/log/elab.log -sim_res=1ps 
RUN      = $(OUT)/obj/$(TB).simv -l run.log -sml +ntb_random_seed=$(SEED) +UVM_TESTNAME=$(TESTNAME) -cm_dir $(CM_DIR) -cm_name $(CM_NAME)

COV_OPTS = -full64 -dir $(CM_DIR)
CM_DIR  ?= $(OUT)/cov.vdb
CM_NAME ?= $(TESTNAME)_$(SEED)

SIMRUNFILE 	= rkv_axiram_sim_run.do

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

#############################
# Targets
#############################
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

all: elab run

regression:
	$(MAKE) all TESTNAME=rkv_axiram_smoke_test SEED=1

mergecov:
	urg -format both $(COV_OPTS)

dvecov:
	dve $(COV_OPTS)

verdicov:
	verdi -cov -covdir $(CM_DIR)

htmlcov:
	firefox urgReport/dashboard.html

clean:
	rm -rf $(OUT) 64 AN.DB DVEfiles csrc *.simv *.simv.daidir *.simv.vdb ucli.key
	rm -rf *.log* *.vpd *.h urgReport *.vcd

.PHONY: prepare comp elab run all regression mergecov dvecov verdicov htmlcov clean
