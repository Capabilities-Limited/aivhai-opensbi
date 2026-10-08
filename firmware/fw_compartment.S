/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Western Digital Corporation or its affiliates.
 *
 * Authors:
 *   Anup Patel <anup.patel@wdc.com>
 */

#include "fw_base.S"

	.section .entry, "ax", %progbits
	.align 3
	.global fw_boot_hart
	/*
	 * This function is called very early even before
	 * fw_save_info() is called.
	 * We can only use a0, a1, and a2 registers here.
	 * The boot HART id should be returned in 'a0'.
	 */
fw_boot_hart:
	li	a0, -1
	ret

	.section .entry, "ax", %progbits
	.align 3
	.global fw_save_info
	/*
	 * We can only use a0, a1, a2, a3, and a4 registers here.
	 * The a0, a1, and a2 registers will be same as passed by
	 * previous booting stage.
	 * Nothing to be returned here.
	 */
fw_save_info:
	ret

	.section .entry, "ax", %progbits
	.align 3
	.global fw_next_arg1
	/*
	 * We can only use a0, a1, and a2 registers here.
	 * The a0, a1, and a2 registers will be same as passed by
	 * previous booting stage.
	 * The next arg1 should be returned in 'a0'.
	 */
fw_next_arg1:
#ifdef FW_PAYLOAD_FDT_ADDR
  li  a0, FW_PAYLOAD_FDT_ADDR
#elif defined(FW_PAYLOAD_FDT_OFFSET)
  PC_PTR_L  a0, _fw_start
  li  a1, FW_PAYLOAD_FDT_OFFSET
  PREG_ADD  a0, a0, a1
#else
  add a0, a1, zero
#endif
#if defined(__CHERI__)
  yaddrw  a0, a3, a0
  set_cap_perm  a0, a0, a1, CHERI_PERM_DATA /* FDT is a read-write data */
#endif /* defined(__CHERI__) */
  ret

	.section .entry, "ax", %progbits
	.align 3
	.global fw_next_addr
	/*
	 * We can only use a0, a1, and a2 registers here.
	 * The next address should be returned in 'a0'.
	 */
fw_next_addr:
	PC_PTR_L	a0, compartment_setup
#if defined(__CHERI__)
	yaddrw	a0, a3, a0
#endif /* defined(__CHERI__) */
	ret

	.section .entry, "ax", %progbits
	.align 3
	.global fw_next_mode
	/*
	 * We can only use a0, a1, and a2 registers here.
	 * The next address should be returned in 'a0'.
	 */
fw_next_mode:
	li	a0, PRV_M
	ret

	.section .entry, "ax", %progbits
	.align 3
	.global fw_options
	/*
	 * We can only use a0, a1, and a2 registers here.
	 * The 'a4' register will have default options.
	 * The next address should be returned in 'a0'.
	 */
fw_options:
	add	a0, zero, zero
	ret

# -------------------- Compartmentlaisation-related bits ---------------- #

######################################################################### #
## An asset to try to attack/reach from _within_ a compartment
## XXX remove when no longer needed
	.section .read_write_me_if_you_can, "aw", %progbits
	.align 8
	.globl write_var
write_var: .long 0xcacacaca
	.globl read_var
read_var: .long 0xcbcbcbcb
######################################################################### #

.extern compartment_print_exception
######################################################################### #
## Compartment exception handling
	.section .compartment_exception, "ax", %progbits
	.align 4
	.globl compartment_trap
compartment_trap:
	# Get a stack for the print call
	csrrw tp, CSR_MSCRATCH, tp
	PREG_L  sp, SBI_SCRATCH_STACK_OFFSET(tp)

	csrr a0, mcause
	call compartment_print_exception
	wfi
	j compartment_trap
######################################################################### #

######################################################################### #
## Compartment bootstrapping and setup before first entry
	.section .compartment, "ax", %progbits
	.align 4
	.globl compartment_setup
compartment_setup:
###0 Start a compartment in capability mode
	ymodeswy

###1 Setup mtvec
	PC_PTR_L t0, compartment_trap
	csrw  mtvec, t0

###2 Disable interrupts
	csrw  CSR_MIE, zero

###3 Setup PCC
	# Load PCC
	PC_PTR_L  t0, cheri_infinite_cap
	PTR_L ra, compartment_enter
	ylenr t1, ra
	yaddrw t0, t0, ra
#if defined(AIVHAI_VULN_BOUNDS)
	ymv t1, t0
#else
	ybndsrw t1, t0, t1
#endif

#if !defined(AIVHAI_VULN_ASR)
	# Strip ASR permission
	li t0, CHERI_PERM_SYSTEM_REGS
	ypermc t1, t1, t0
#endif

	ymv ra, t1

#if !defined(AIVHAI_VULN_REGS_TEMP)
###4 clear all registers
	/* flush the instruction cache */
	fence.i
	li sp, 0
	li gp, 0
	li tp, 0
	li t0, 0
	li t1, 0
	li t2, 0
	li s0, 0
	li s1, 0
	li a0, 0
	li a1, 0
	li a2, 0
	li a3, 0
	li a4, 0
	li a5, 0
	li a6, 0
	li a7, 0
	li s2, 0
	li s3, 0
	li s4, 0
	li s5, 0
	li s6, 0
	li s7, 0
	li s8, 0
	li s9, 0
	li s10, 0
	li s11, 0
	li t3, 0
	li t4, 0
	li t5, 0
	li t6, 0
	csrw CSR_SEPC, 0
	csrw CSR_MEPC, 0
	csrw CSR_STVEC, 0
	csrw CSR_SSCRATCH, 0
#endif

#if !defined(AIVHAI_VULN_DDC)
	csrw ddc, 0
#endif

###5 Jump to a compartment
	########################################################################
	# Jump to the compartment
	# After this point, a compartment is entered, take extra care
  #######################################################################$
	jalr ra

###6 Compartment return without exceptions
compartment_return:
	# Get a stack for the print call
	csrrw tp, CSR_MSCRATCH, tp
	PREG_L  sp, SBI_SCRATCH_STACK_OFFSET(tp)

	call compartment_print_return

	wfi
	j compartment_return

## Actual compartment content (ELF/bin, code, data, etc)
	.section .compartment_bits, "awx", %progbits
	.align 4
	.globl compartment_enter
compartment_enter:
#ifndef FW_COMPARTMENT_PATH
	wfi
	j	compartment_enter
#else
	.incbin	FW_COMPARTMENT_PATH
#endif
.size compartment_enter, . -compartment_enter
# -------------------- Compartmentlaisation-related bits ---------------- #
