#!/usr/bin/bash

export PRJ_PATH=/media/nvme0n1p5/Courses/Computer_Organization_and_Architecture/Project_2/skill/
# export PRJ_PATH=/media/nvme1n1p5/Courses/Computer_Organization_and_Architecture/Project_2/skill/
export RTL_PATH=${PRJ_PATH}src/rtl/
export TB_PATH=${PRJ_PATH}sim/bench/
export CASE_ASM_PATH=${PRJ_PATH}sim/cases_asm/
export CASE_C_PATH=${PRJ_PATH}sim/cases_c/
export CASE_BIN_PATH=${PRJ_PATH}sim/cases_bin/
export SIM_SCR_PATH=${PRJ_PATH}sim/scripts/
export RTL_SCR_PATH=${PRJ_PATH}src/scripts/

alias dasmcase='cd ${CASE_ASM_PATH}'
alias dccase='cd ${CASE_C_PATH}'
alias dbincase='cd ${CASE_BIN_PATH}'
alias drtl='cd ${RTL_PATH}'
alias prj='cd ${PRJ_PATH}'
alias dsimscr='cd ${SIM_SCR_PATH}'
alias run_sim='${SIM_SCR_PATH}run_sim.py'
alias run_reg='${SIM_SCR_PATH}run_reg.py'
alias run_syn_imp='${RTL_SCR_PATH}run_syn_imp.py'
alias run_exp='${SIM_SCR_PATH}run_exp.py'
