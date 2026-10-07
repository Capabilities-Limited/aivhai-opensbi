/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Western Digital Corporation or its affiliates.
 *
 * Authors:
 *   Anup Patel <anup.patel@wdc.com>
 */

OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
	#include "fw_base.ldS"

#ifdef FW_COMPARTMENT_OFFSET
	. = FW_TEXT_START + FW_COMPARTMENT_OFFSET;
#else
	. = ALIGN(FW_COMPARTMENT_ALIGN);
#endif

	.compartment :
	{
		PROVIDE(_compartment_start = .);
		*(.compartment)
		. = ALIGN(8);
		PROVIDE(_compartment_end = .);
	}

	PROVIDE(_fw_reloc_end = .);
}
