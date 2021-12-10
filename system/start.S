/*-
 * Copyright (c) 1990 The Regents of the University of California.
 * All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * William Jolitz.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)srt0.c	5.3 (Berkeley) 4/28/91
 */

/*
 * Startup code for standalone system
 * Non-relocating version -- for programs which are loaded by boot
 * Relocating version for boot
 * Small relocating version for "micro" boot
 */

/*
 * Multiboot2 Constants
 */
#define	MULTIBOOT_HEADER_MAGIC  0xE85250D6
#define MULTIBOOT_ARCH 		0
#define MULTIBOOT_HEADER_LENGTH	(mbootheader_end - mbootheader)
// #define MULTIBOOT_HEADER_LENGTH	0x54
#define MODULE_ALIGNMENT_TAG_TYPE	6
#define MODULE_ALIGNMENT_TAG_FLAGS	1
#define MODULE_ALIGNMENT_TAG_SIZE	8
#define ADDRESS_TAG_TYPE	2
#define ADDRESS_TAG_FLAGS	1
#define ADDRESS_TAG_SIZE	24
#define ENTRY_ADDRESS_TAG_TYPE	3
#define ENTRY_ADDRESS_TAG_FLAGS 1
#define ENTRY_ADDRESS_TAG_SIZE 	12
#define INFO_REQ_TAG_TYPE	1
#define INFO_REQ_TAG_FLAGS	0
#define INFO_REQ_MEM	4
#define INFO_REQ_MMAP	6

// TODO: Change to proper signature
//#define MULTIBOOT_SIGNATURE	0x36d76289	/* Multiboot signature verification	*/
#define MULTIBOOT_SIGNATURE	0x36d76229	/* QEMU Multiboot signature verification ? */
//#define MULTIBOOT_BOOTINFO_MMAP	0x00000040	/* mmap_length mmap_addr valid		*/
#define MULTIBOOT_BOOTINFO_MMAP_TYPE	6	/* mmap boot info tag */

#define	GDT_ENTRIES		4
#define	GDT_ENTRY_SIZE		8
#define	GDT_BYTES		(GDT_ENTRIES * GDT_ENTRY_SIZE)
#define	IDT_ENTRIES		256
#define	IDT_ENTRY_SIZE		8
#define	IDT_BYTES		(IDT_ENTRIES * IDT_ENTRY_SIZE)
#define NULLSTK			(8192)		/* This must match NULLSTK defined in kernel.h 		*/

	.data

	.align	16	
	.globl	gdt
gdt:	.space	GDT_BYTES
gdtr:	.word	(GDT_BYTES-1)		# sizeof _gdt -1 (in bytes)
	.long	gdt			# global pointer to the gdt
		
	.align	16	        	
	.globl	idt
idt:	.space	IDT_BYTES       	
idtr:	.word	(IDT_BYTES-1)		# size of _idt -1 (in bytes)
	.long	idt			# global pointer to the idt

	.globl	cpudelay
cpudelay:	.long	1

	.text
	jmp	start			# Handle loaders that start at first byte of
					# text rather than the entry point
	.align 	8
	.globl 	mbootheader
mbootheader:  				# Beginning of multiboot header, embedded in ELF header
	.long   MULTIBOOT_HEADER_MAGIC
	.long 	MULTIBOOT_ARCH
	.long	MULTIBOOT_HEADER_LENGTH	# mbootheader length
	.long	0x100000000 - (MULTIBOOT_HEADER_MAGIC + MULTIBOOT_ARCH + MULTIBOOT_HEADER_LENGTH) # Checksum

	# Module alignment tag
	.align 	8
	.short	MODULE_ALIGNMENT_TAG_TYPE
	.short	MODULE_ALIGNMENT_TAG_FLAGS
	.long	MODULE_ALIGNMENT_TAG_SIZE

	# Address tag	
	.align 	8
	.short	ADDRESS_TAG_TYPE
	.short 	ADDRESS_TAG_FLAGS
	.long	ADDRESS_TAG_SIZE
	.long	mbootheader		# header address
	.long	text			# load address
	.long	bss				# load end address
	.long 	ebss			# bss end address

	# Entry address tag	
	.align 	8
	.short 	ENTRY_ADDRESS_TAG_TYPE
	.short 	ENTRY_ADDRESS_TAG_FLAGS
	.long 	ENTRY_ADDRESS_TAG_SIZE
	.long	start			# Entry address

	# Information request tag
	.align 	8
info_req_tag:
	.short	INFO_REQ_TAG_TYPE
	.short	INFO_REQ_TAG_FLAGS
	.long	info_req_tag_end - info_req_tag	# Size of information request tag
	.long 	INFO_REQ_MEM	# Basic memory information
	.long 	INFO_REQ_MMAP	# Memory map information
info_req_tag_end:

	# Terminating tag
	.align 	8
	.short	0
	.short 	0
	.long 	8
mbootheader_end:  			# End of multiboot header

	.globl	start
	.code32
start:
	// Checkpoint: start
	mov	$0x3f8, %dx
	movb	$48, %al
	out	%al, %dx

	/*
	 * Store the boot arguments.
	 */
	movl	%eax, bootsign	# Should be 0x36d76289 on MB2
	movl	%ebx, bootinfo	# MB2 Info struct address
	
	/*
	 * Test the multiboot signature and memory map flags
	 */
	cmpl	$MULTIBOOT_SIGNATURE, %eax
	// TODO: Enable signature checking
	//jne	halt

	/*
	 *	Find memory map tag, halt if not found
	 */
	movl	(%ebx), %eax	# Boot info struct size
	addl	%ebx, %eax	# End address of boot info struct
	addl	$0x8, %ebx 	# Move to first tag
	jmp	search_mmap_tag

next_tag:
	# Checkpoint: next tag
	# Save
	movl	%eax, %ecx
	mov	$0x3f8, %dx
	movb	$49, %al
	out	%al, %dx
	movl	%ecx, %eax

	movl	4(%ebx), %ecx	# Read tag size (doesn't include padding)
	addl	%ecx, %ebx	# Inc address to next tag
	addl	$7, %ebx	# Add size of padding (align to next 8 byte boundary)
	andl	$0xFFFFFFF8, %ebx

search_mmap_tag:
	cmpl	%eax, %ebx	# If curr_addr > bootinfo_end, halt
	jae	halt

	cmpl	$MULTIBOOT_BOOTINFO_MMAP_TYPE, (%ebx)	# Check for mmap tag
	jne		next_tag	

	# Checkpoint: after tag search
	mov	$0x3f8, %dx
	movb	$50, %al
	out	%al, %dx

	/*
	 * Iterate through the memory map segments to find the highest
	 *   address that will fit the null stack
	 */

	movl	%ebx, %ecx	# Addr of first base_addr
	addl	$16, %ecx
	movl	4(%ebx), %edx 	# Load (mmap + tag) size
	andl	$0xfffffffc, %edx	# Load mmap_end, align to 4 bytes
	addl	%ebx, %edx		# end of mmap addr (mmap tag + size)
	movl	$0x0, %esp		# Initialize null stack pointer to some small value

	# Checkpoint: before search
	movl	%edx, %ebx
	mov	$0x3f8, %dx
	movb	$51, %al
	out	%al, %dx
	movl	%ebx, %edx


mmap_search_start:
	cmpl	%edx, %ecx		# If mmap_addr >= mmap_end then quit
	jae	mmap_search_done

	# skip memory segment if it is not usable
	movl	16(%ecx), %eax		# Test the address block type
	cmpl	$0x01, %eax		# If type is not equal to 1
	jne	mmap_search_next_sgmt	#   then this is not a usable block

	# skip memory segment if it is within the memory for Xinu
	movl	(%ecx), %eax		# Load memory address of segment (base_addr)
	movl	8(%ecx), %ebx		# Load segment size/length
	add	%ebx, %eax		# Find end of memory segment
	movl	$end, %ebx		# Load end of xinu
	cmpl	%ebx, %eax		# Compare segment and xinu end
	jle	mmap_search_next_sgmt	# Skip if segment is within xinu
	
	# Segment is usable and not within xinu memory region
	#   Check if it is big enough to hold the null stack
	#   Subtract off any memory location that overlaps the
	#     the Xinu memory region
	movl	(%ecx), %eax		# Load memory address of segment
	movl	$end, %ebx		# Load end of xinu
	subl	%eax, %ebx		# Determine overlap
	movl	8(%ecx), %eax		# Load segment size
	cmpl	$0x0, %ebx		# Check if overlap is greater than zero
	jl	mmap_search_no_overlap
	subl	%ebx, %eax		# Subtract overlap size
mmap_search_no_overlap:
	cmpl	$NULLSTK, %eax		# Compare with nullstack size
	jl	mmap_search_next_sgmt
	
	# Segment is big enough to hold the null stack
	#   want to save the highest possible address
	#   check if segment is larger than current stack pointer
	movl	(%ecx), %eax		# Load memory address of segment
	movl	8(%ecx), %ebx		# Load segment size
	addl	%ebx, %eax		# Retrieve segment end
	cmpl	%esp, %eax		# Compare segment and stack pointer
	jl	mmap_search_next_sgmt	# Skip segment if less than
	
	# Segment is big enough to hold the nullstack
	#   and larger than the current stack pointer
	#   Use the end of the new segment as the null stack (as stack grows down)
	#     Round to the nearest block and subtract 4 (for STACKMAGIC), stack grows
	# 	  below that.
	movl	%eax, %esp
	addl	$0x7, %esp	# Add 7 for rounding up
	andl	$0xFFFFFFF8, %esp	# Round (down) to 8 byte boundary
	subl	$0x4, %esp

mmap_search_next_sgmt:	
	# Checkpoint: next sgmt
	movl	%edx, %ebx
	mov	$0x3f8, %dx
	movb	$52, %al
	out	%al, %dx
	movl	%ebx, %edx

	addl	$24, %ecx	# Jump 24 bytes to the next entry
	jmp	mmap_search_start
	
mmap_search_done:

	# Checkpoint: mmap search done
	mov	$0x3f8, %dx
	movb	$53, %al
	out	%al, %dx

	# Stack pointer set continue with boot
	movl	%esp, %ebp
	
	/*
	 * Clear flags.
	 */
	pushl	$0
	popf
	
	/*
	 * Zero the bss space
	 */
	movl	$ebss, %ebx
	movl	$bss, %ecx		# start of bss in %ecx
	subl	%ecx, %ebx		# bss size in %ebx
	pushl	%ebx
	pushl	%ecx
	call	sbzero
	popl	%ecx
	popl	%ebx
	
	# Checkpoint: bss cleared
	mov	$0x3f8, %dx
	movb	$54, %al
	out	%al, %dx

	/*
	 * Set up the global descriptor table.
	 */
	call	setsegs

	lgdt	gdtr
	/*
	 * Reload segment registers; load code segment by a far
	 * jump
	 */
	ljmp	$0x8, $gdt1	/* CS descriptor 1 */
gdt1:
	movl	$0x10, %eax	/* DS descriptor 2 */
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %fs
	movw	%ax, %gs
	movl	$0x18, %eax	/* SS descriptor 3 */
	movw	%ax, %ss
	
	# Checkpoint: gdt init
	mov	$0x3f8, %dx
	movb	$55, %al
	out	%al, %dx

	/*
	 * Call the nulluser to initialize the system
	 */
	call	nulluser
	call	halt

	.globl	inb
inb:	movl	4(%esp), %edx
	xorl	%eax, %eax	# clr eax
	inb	%dx, %al
	ret

	.globl	inw
inw:	movl	4(%esp), %edx
	xorl	%eax, %eax	# clr eax
	inw	%dx, %ax
	ret

	.globl  inl
inl:	movl	4(%esp), %edx
	xorl	%eax, %eax
	inl	%dx, %eax
	ret

	.globl	outb
outb:	movl	4(%esp), %edx
	movl	8(%esp), %eax
	outb	%al, %dx
	ret

	.globl	outw
outw:	movl	4(%esp), %edx
	movl	8(%esp), %eax
	outw	%ax, %dx
	ret

	.globl	outl
outl:	movl	4(%esp), %edx
	movl	8(%esp), %eax
	outl	%eax, %dx
	ret

#ifndef SMALL
	.globl	_rtcin
_rtcin:	movl	4(%esp), %eax
	outb	%al, $0x70
	subl	%eax, %eax	# clr eax
	inb	$0x71, %al
	ret
#endif

	.globl ___udivsi3
___udivsi3:
	movl 4(%esp), %eax
	xorl %edx, %edx
	divl 8(%esp)
	ret

	.globl ___divsi3
___divsi3:
	movl 4(%esp), %eax
	xorl %edx, %edx
	cltd
	idivl 8(%esp)
	ret

	# sbzero (base, cnt)
	.globl sbzero
sbzero:
	pushl	%edi
	movl	8(%esp), %edi
	movl	12(%esp), %ecx
	movb	$0x00, %al
	cld
	rep
	stosb
	popl	%edi
	ret

	# insw(port, addr, cnt)
	.globl	insw
insw:
	pushl	%edi
	movw	8(%esp), %dx
	movl	12(%esp), %edi
	movl	16(%esp), %ecx
	cld
	.byte 0x66, 0xf2, 0x6d	# rep insw
	movl	%edi, %eax
	popl	%edi
	ret

	# outsw(port, addr, cnt)
	.globl	outsw
outsw:
	pushl	%esi
	movw	8(%esp), %dx
	movl	12(%esp), %esi
	movl	16(%esp), %ecx
	cld
	.byte 0x66, 0xf2, 0x6f	# rep outsw
	movl	%esi, %eax
	popl	%esi
	ret

	# bcopy(src, dst, count)
	.globl	bcopy
bcopy:
	pushl	%esi
	pushl	%edi
	movl	12(%esp), %esi
	movl	16(%esp), %edi
L1:
	movl	20(%esp), %ecx
	cld
	rep
	movsb
	popl	%edi
	popl	%esi
	ret

	# lidt() - load interrupt descriptor table from idtr
	.globl	lidt
lidt:
	lidt	idtr
	ret

	# cpuid() - report basic CPU type information
	.globl	cpuid
cpuid:
	pushl	%ebx
	movl	$1, %eax	# request basic CPU type
	xorl	%ecx, %ecx
	cpuid
	popl	%ebx
	ret			# return value in %eax
