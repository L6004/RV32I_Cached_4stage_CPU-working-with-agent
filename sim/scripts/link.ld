/* link.ld: Minimal bare-metal linker script */
OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
    . = 0x80000000;

    .text : {
        *(.text .text.*)
    }
    . = ALIGN(0x1000);

    .rodata : {
        *(.rodata .rodata.*)
    }
    . = ALIGN(0x1000);

    . = 0x80002000;

    .data : {
        *(.data .data.*)
        *(.sdata .sdata.*)
    }
    . = ALIGN(0x4000);

    .tohost : {
	    *(.tohost)
    }
    . = ALIGN(0x1000);

    .bss : {
        *(.bss .bss.*)
        *(.sbss .sbss.*)
    }
    . = ALIGN(0x1000);

    _end = .;
}
