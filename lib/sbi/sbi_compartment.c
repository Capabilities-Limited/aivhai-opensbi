#include <sbi/sbi_string.h>
#include <sbi/sbi_console.h>

extern unsigned long write_var, read_var;

void compartment_print_exception(unsigned long mcause) {
    sbi_printf("Compartment returned with an exception\n");

    switch (mcause) {
        case 32: sbi_printf("CHERI Instruction Access Fault\n"); break;
        case 33: sbi_printf("CHERI Load Access Fault\n"); break;
        case 34: sbi_printf("CHERI Store/AMO Access Fault\n"); break;
        case 35: sbi_printf("CHERI Load Capability Fault\n"); break;
        case 36: sbi_printf("CHERI Store/AMO Page Fault\n"); break;
        default: sbi_printf("%lx\n", mcause);
    }

    while(1);
}

void compartment_print_return(void) {
    sbi_printf("Compartment returned successfully\n");

    if (write_var != 0xcacacaca) {
        sbi_printf("Integrity attack successful: write_var = %lx\n", write_var);
    }

    while(1);
}
