// array sequential access case
#define N 3072
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
        "li t2, 3072 \n\t"          // t2 = N
        "li %[res], 0 \n\t"         // res = sum = 0
        "1: \n\t"                   // outer_loop:
        "mv t3, t1 \n\t"            // ptr = base
        "li t4, 0 \n\t"             // i = 0
        "2: \n\t"                   // inner_loop:
        "lw t5, 0(t3) \n\t"         // the only D-Cache access: lw arr[idx]
        "add %[res], %[res], t5 \n\t" // sum += val
        "addi t3, t3, 4 \n\t"       // ptr++
        "addi t4, t4, 1 \n\t"       // i++
        "blt t4, t2, 2b \n\t"       // if (i < N) goto inner_loop
        "addi t0, t0, -1 \n\t"      // k--
        "bnez t0, 1b \n\t"          // if (k != 0) goto outer_loop
        : [res] "=r" (final_sum)
        : 
        : "t0", "t1", "t2", "t3", "t4", "t5"
    );
    
    volatile int* out = (volatile int*)0x80005ff0;
    *out = final_sum;
}