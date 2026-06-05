// fib array calculation
void _start() {
    asm volatile("li sp, 0x80040000");

    int fib[5];
    fib[0] = 0;
    fib[1] = 1;
    for (int i = 2; i <= 4; i++) {
        fib[i] = fib[i - 1] + fib[i - 2];
    }

    volatile int* res = (volatile int*)0x80005ff0;
    *res = fib[4];
}