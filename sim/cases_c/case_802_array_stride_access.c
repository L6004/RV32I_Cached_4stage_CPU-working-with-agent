// array stride access case
#define N 16384
int arr[N];

void test_main();

__attribute__((naked)) void _start() {
    asm volatile("li sp, 0x80040000"); 
    asm volatile("call test_main");    
    asm volatile("j _custom_exit");    
}

void test_main() {
    for (int i = 0; i < N; i++) arr[i] = i; 
    
    int final_sum;
    __asm__ volatile (
        "li t0, 4 \n\t"             // k = 4
        "la t1, arr \n\t"           // t1 = base addr
        "li t2, 16384 \n\t"         // t2 = N
        "li t3, 131 \n\t"           // t3 = STRIDE
        "li t4, 0 \n\t"             // t4 = idx = 0
        "li %[res], 0 \n\t"         // res = sum = 0
        "1: \n\t"                   // outer_loop:
        "li t5, 0 \n\t"             // i = 0
        "2: \n\t"                   // inner_loop:
        "slli t6, t4, 2 \n\t"       // t6 = idx * 4
        "add t6, t1, t6 \n\t"       // t6 = base + idx*4
        "lw t6, 0(t6) \n\t"         // the only D-Cache access: lw arr[idx]
        "add %[res], %[res], t6 \n\t" // sum += val
        "add t4, t4, t3 \n\t"       // idx += STRIDE
        "li t6, 0x3FFF \n\t"        // mask = 16383
        "and t4, t4, t6 \n\t"       // idx &= 0x3FFF
        "addi t5, t5, 1 \n\t"       // i++
        "blt t5, t2, 2b \n\t"       // if (i < N) goto inner_loop
        "addi t0, t0, -1 \n\t"      // k--
        "bnez t0, 1b \n\t"          // if (k != 0) goto outer_loop
        : [res] "=r" (final_sum)
        : 
        : "t0", "t1", "t2", "t3", "t4", "t5", "t6"
    );
    
    volatile int* out = (volatile int*)0x80005ff0;
    *out = final_sum;
}
