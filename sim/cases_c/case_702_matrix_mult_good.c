// matrix calculation case: good
#define N 32
int A[N][N];
int B[N][N];
int C[N][N];

__attribute__((always_inline)) inline int mul(int a, int b);
void mmb_loop_reorder();
void test_main();

// entrance：naked, avoid compiler inserting stack operation
__attribute__((naked)) void _start() {
    asm volatile("li sp, 0x80040000"); // 1. initialize stack pointer
    asm volatile("call test_main");    // 2. jump to C function
    asm volatile("j _custom_exit");    // 3. return
}

void test_main() {
    // initialized to small integers in 0~15
    for(int i = 0; i < N; i++) {
        for(int j = 0; j < N; j++) { 
            A[i][j] = (i + j) & 0xF; 
            B[i][j] = (i + (j << 2)) & 0xF; 
            C[i][j] = 0;
        }
    }
    
    mmb_loop_reorder();
}

__attribute__((always_inline)) inline int mul(int a, int b) {
    int res;
    int temp_b = b; // do not modify the original b register
    __asm__ volatile (
        "li %[res], 0\n\t"
        "beqz %[tb], 2f\n\t"
        "1:\n\t"
        "add %[res], %[res], %[a]\n\t"
        "addi %[tb], %[tb], -1\n\t"
        "bnez %[tb], 1b\n\t"
        "2:\n\t"
        : [res] "=&r" (res), [tb] "+r" (temp_b) // output operands
        : [a] "r" (a)                           // input operands
    );
    return res;
}

void mmb_loop_reorder() {
    // B has better spatial locality (accessed in row-major order)
    for (int i = 0; i < N; i++) {
        for (int k = 0; k < N; k++) {
            int r = A[i][k];
            for (int j = 0; j < N; j++) {
                C[i][j] += mul(r, B[k][j]);
            }
        }
    }
}
