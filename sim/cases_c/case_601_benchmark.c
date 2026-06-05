// benchmark case: large fib array calculation

void _start() {
    asm volatile("li sp, 0x80040000");

    int a = 0;
    int b = 1;
    int sum = 0;
    
    // heavy calculation and jump
    for (int i = 0; i < 100; i++) {
        sum = sum + a;
        int next = a + b;
        a = b;
        b = next;
    }
    
    // write memory for verification
    volatile int* result_ptr = (volatile int*)0x80002018;
    *result_ptr = sum; // supposed: 986 (0x3DA)
}
