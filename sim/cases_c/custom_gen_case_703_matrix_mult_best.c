// matrix calculation case: best
#define N 8
int A[N][N];
int B[N][N];
int C[N][N];

__attribute__((always_inline)) inline int mul(int a, int b);
void mmc_blocked();
void test_main();

// entrance：naked, avoid compiler inserting stack operation
__attribute__((naked)) void _start() {
    asm volatile("li sp, 0x80040000"); // 1. initialize stack pointer
    asm volatile("call test_main");    // 2. jump to C function
    asm volatile("j _custom_exit");    // 3. return
}

void test_main() {
    // 初始化 0~15 的小整数[cite: 1]
    for(int i = 0; i < N; i++) 
        for(int j = 0; j < N; j++) { 
            A[i][j] = (i + j) & 0xF; 
            B[i][j] = (i + (j << 2)) & 0xF; 
            C[i][j] = 0;
        }
    
    mmc_blocked();
}

// 使用循环加法模拟乘法，排除乘法指令缺失的影响[cite: 1]
__attribute__((always_inline)) inline int mul(int a, int b) {
    int res;
    int temp_b = b; // 复制一份 b，避免修改原始的传入变量寄存器
    __asm__ volatile (
        "li %[res], 0\n\t"
        "beqz %[tb], 2f\n\t"
        "1:\n\t"
        "add %[res], %[res], %[a]\n\t"
        "addi %[tb], %[tb], -1\n\t"
        "bnez %[tb], 1b\n\t"
        "2:\n\t"
        : [res] "=&r" (res), [tb] "+r" (temp_b) // 输出操作数
        : [a] "r" (a)                           // 输入操作数
    );
    return res;
}

void mmc_blocked() {
    int B_SIZE = 4;
    // 外层控制分块起点的循环保持不变
    for (int i = 0; i < N; i += B_SIZE) {
        for (int j = 0; j < N; j += B_SIZE) {
            for (int k = 0; k < N; k += B_SIZE) {
                
                // 内层循环：增加 && ii < N, && jj < N, && kk < N 的边界保护
                for (int ii = i; ii < i + B_SIZE && ii < N; ii++) {
                    for (int jj = j; jj < j + B_SIZE && jj < N; jj++) {
                        
                        int sum = 0; // 局部变量暂存累加结果，减少对 C[ii][jj] 的频繁读取
                        
                        for (int kk = k; kk < k + B_SIZE && kk < N; kk++) {
                            sum += mul(A[ii][kk], B[kk][jj]);
                        }
                        
                        C[ii][jj] += sum;
                    }
                }
                
            }
        }
    }
}
