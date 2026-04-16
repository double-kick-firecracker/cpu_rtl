#include <stdio.h>

int main()
{
    asm volatile ("ori   x23,x0 ,123    ");
    asm volatile ("ori   x24,x0 ,0x678  ");
    asm volatile ("ori   x1 ,x0 ,8      ");
    asm volatile ("ori   x2 ,x0 ,12     ");
    asm volatile ("ori   x3 ,x0 ,0      ");
    asm volatile ("add   x11,x2 ,x1     ");
    asm volatile ("sub   x12,x2 ,x1     ");
    asm volatile ("addi  x13,x2 ,1      ");
    asm volatile ("or    x14,x2 ,x3     ");
    asm volatile ("and   x15,x1 ,x2     ");
    asm volatile ("xor   x19,x2 ,x1     ");
    asm volatile ("ori   x4 ,x0 ,4      ");
    asm volatile ("sll   x7 ,x2 ,x4     "); 
    asm volatile ("ori   x15,x0 ,128    ");
    asm volatile ("srl   x6 ,x15,x4     ");
    asm volatile ("sra   x5 ,x15,x4     ");
    asm volatile ("ori   x4 ,x0 ,4      ");
    asm volatile ("sw    x4 ,-4(x1)     ");
    asm volatile ("sw    x2 , 0(x0)     ");
    asm volatile ("sw    x3 , 4(x0)     ");
    asm volatile ("lw    x5 , -8(x1)    ");
    asm volatile ("sll   x5 ,x2 ,x4     ");
    asm volatile ("_addi:               ");
    asm volatile ("addi  x3 ,x2 ,1      ");
    asm volatile ("or    x2 ,x3 ,x0     ");
    asm volatile ("bne   x3 ,x5 ,_addi  ");
    asm volatile ("addi  x29,x0 ,76     ");
    asm volatile ("addi  x27,x0 ,0xab   ");
    asm volatile ("sw    x27,4(x29)     ");
    asm volatile ("jal   x0 ,_jtest    ");
    asm volatile ("ori   x0 ,x1 ,0      ");
    asm volatile ("ori   x0 ,x1 ,0      ");
    asm volatile ("ori   x0 ,x1 ,0      ");
    asm volatile ("_jtest:              ");
    asm volatile ("lw    x28,4(x29)     ");
    asm volatile ("beq x27, x28, 16     ");
    asm volatile ("ori   x0 ,x1 ,0      ");
    asm volatile ("ori   x0 ,x1 ,0      ");
    asm volatile ("ori   x0 ,x1 ,0      ");
    asm volatile ("lw x30, 4(x29)      ");
}
