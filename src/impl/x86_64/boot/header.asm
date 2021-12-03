section .multiboot_header
header_start:
	
	dd 0xe85250d6 ;This is the magic number for multiboot2 
	
	dd 0 ;This will run in protected mode i386

	
	dd header_end - header_start ;This will calculate header length
	

	dd 0x100000000 - (0xe85250d6 + 0 + (header_end - header_start)) ;This is the checksum of the header 

	; end tag
	dw 0
	dw 0
	dd 8
header_end:
