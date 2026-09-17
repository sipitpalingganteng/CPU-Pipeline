/* Linker script for the pipeline_cpu C runtime.
 *
 * .text (code + read-only data) is placed at the reset vector 0xbfc00000.
 * .data/.bss live in the low 64 KiB of data RAM; sim_main.cpp starts that
 * RAM zeroed, so .bss needs no load image. The stack is set up by _start.
 * MIPS metadata sections are discarded so the raw .text image starts at
 * _start.
 */

OUTPUT_ARCH(mips)
ENTRY(_start)

SECTIONS
{
  . = 0xbfc00000;
  .text : {
    *(.text)
    *(.text.*)
    *(.rodata)
    *(.rodata.*)
  }

  . = 0x00000000;
  .data : {
    *(.data)
    *(.data.*)
  }

  .bss : {
    *(.bss)
    *(.bss.*)
    *(COMMON)
  }

  /DISCARD/ : {
    *(.MIPS.abiflags)
    *(.reginfo)
    *(.mdebug*)
    *(.comment)
    *(.note*)
  }
}
