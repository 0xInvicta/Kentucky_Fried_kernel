global start
extern long_mode_start
section .text
bits 32
start:
	mov esp, stack_top ; Move the stack pointer[ESP] to the top of the stack

	call check_multiboot ;Checks if we have booted with multiboot

	call check_cpuid ;Check the CPU ID

	call check_cpu_long_mode ;check for long mode support so we can move to 64bit

	call setup_page_tables ;call to set up page tables for virtual memory 

	call enable_paging ; call to enable paging tables

	lgdt [gdt64.pointer] ;load global table 

	jmp gdt64.code_segment:long_mode_start ; CPU will jump into long mode

	

	hlt

check_multiboot:
	cmp eax, 0x36d76286 ;Checks for magic value
	jne .no_multiboot ;call .no_multiboot to print error message
	ret ;RETURN
.no_multiboot:
	mov al, "M" ; M = mulitboot error
	jmp error 

check_cpuid:
	pushfd
	pop eax
	mov ecx, eax
	xor eax, 1 << 21 ;Flip the ID bit if it works CPU supports checkid
	push eax ;push back onto the stack
	popfd ;pop back into flag register
	pushfd ;copy back to flag register
	pop eax ;copy back to flag register
	push ecx
	popfd ; reset the flags 
	cmp eax, ecx ; compare the results to see if bit flip is successful 
	je .no_cpuid
	ret
.no_cpuid:
	mov al, "C" ; C = CPU Error
	jmp error

check_cpu_long_mode:
	mov eax, 0x80000000 ;if CPU supports long mode cpuid will return a bigger nummber then 80000000
	cpuid ; call cpuid to see if the cpu can return a bigger number
	cmp eax, 0x80000001 ; compare +1
	jb .no_long_mode ; if fail jump to no_long_mode

	cmp eax, 0x80000001 ;check again
	cpuid
	test edx, 1 << 29
	jz .no_long_mode ; if fail jump to no_long_mode
.no_long_mode:
	mov al, "L" ; L = Long mode Error
	jmp error

setup_page_tables:
	mov eax, page_table_l3
	or eax, 0b11 ;writable bits
	mov [page_table_l4], eax
	
	mov eax, page_table_l2
	or eax, 0b11 ; writable bits
	mov [page_table_l3], eax

	mov ecx, 0 ; The loop counter
.loop:

	mov eax, 0x200000 ; 2mb
	mul ecx
	or eax, 0b10000011 ; present, writable
	mov [page_table_l2 + ecx * 8], eax ; Move with offset 

	inc ecx ; increment counter
	cmp ecx, 512 ; checks if the whole table is mapped
	jne .loop ; if not, continue

	ret

enable_paging:
	mov eax, page_table_l4 ; move address of L4 table to EAX
	mov cr3, eax ; move above value to cr3 register to enable page mapping 

	mov eax, cr4 ; Enable PAE for 64bit paging
	or eax, 1 << 5 ; Enable 5th bit for PAE flag
	mov cr4, eax

	mov ecx, 0xC0000080 ;Magice number for RDMSR register to enable long mode (64bit)
	rdmsr
	or eax, 1 << 8
	wrmsr
	

	mov eax, cr0 ;To enable memory paging
	or eax, 1 << 31 ; Enable bit 31 for paging 
	mov cr0, eax 
	ret
error:
	;Below this will print the ERROR message
	mov dword [0xb8000], 0x4f524f45 ;ASCCI Char every 4bytes 
	mov dword [0xb8004], 0x4f3a4f52 ;ASCCI Char every 4bytes 
	mov dword [0xb8008], 0x4f204f20 ;ASCCI Char every 4bytes 
	mov byte  [0xb800a], al ; whatever error code is set eg: "C" or "M" or "L"
	hlt  
section .bss

;START OF PAGE TABLES
;Below is the begining of the tables
align 4096 ;Align all tables to 4kb

page_table_l4:
	resb 4096 

page_table_l3:
	resb 4096

page_table_l2:
	resb 4096

; END OF PAGE TABLES



; START OF STACK
;Below is the begining of the stack 
stack_bottom:
	resb 4096 * 4 ;Reseve of 16kb of Memory 
stack_top:

; END OF STACK


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; READ ONLY DATA 
; GLOBAL DESCRIPITOR TABLE
; to enter 64bit mode
section .rodata
gdt64:
	dq 0 ; zero entry
.code_segment: equ $ - gdt64
	dq (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53) ; Enable Flags 
.pointer:
	dw $ - gdt64 - 1 ; length
	dq gdt64 ; address