// C(n, r) calculation

int nCr(int n, int r);
void test_main();

// entrance：naked, avoid compiler inserting stack operation
__attribute__((naked)) void _start() {
    asm volatile("li sp, 0x80040000"); // 1. initialize stack pointer
    asm volatile("call test_main");    // 2. jump to C function
    asm volatile("ret");               // 3. return
}

// main：C function
void test_main() {
    int result = nCr(5, 3); // C(5,3) = 10
    volatile int* result_ptr = (volatile int*)0x80002018;
    *result_ptr = result;
}

// recursive subprocess：calculate C(n, r)
int nCr(int n, int r) {
    if (r == 0 || n == r) return 1;
    return nCr(n - 1, r - 1) + nCr(n - 1, r);
}
