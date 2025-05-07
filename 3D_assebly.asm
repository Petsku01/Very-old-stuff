; Pyörivä 3D ASCII-kuutio Assemblyssä (Linux)
; nasm -f elf64 cube.asm && ld cube.o -o cube
; Toimiva 2025
; Suorita: ./cube (Ctrl+C lopettaa, ehkä)

section .data
    ; 3D-kuution kärjet (x, y, z)
    vertices: dd -1.0, -1.0, -1.0, 1.0, -1.0, -1.0, 1.0, 1.0, -1.0, -1.0, 1.0, -1.0
              dd -1.0, -1.0, 1.0, 1.0, -1.0, 1.0, 1.0, 1.0, 1.0, -1.0, 1.0, 1.0
    ; Reunat: kärkien indeksiparit
    edges: db 0,1, 1,2, 2,3, 3,0, 4,5, 5,6, 6,7, 7,4, 0,4, 1,5, 2,6, 3,7
    ; Näyttöpuskuri (80x24 terminaali, ASCII + väri)
    buffer: times 80*24*8 db 0
    ; ANSI-värikoodit
    colors: db 31, 32, 33, 34, 35, 36, 37
    ; Tyhjennä näyttö ja siirrä kursori vasempaan yläkulmaan
    clear: db 27, '[2J', 27, '[H'
    clear_len: equ $-clear
    ; Matemaattiset vakiot
    pi: dq 3.141592653589793
    angle: dq 0.0
    angle_inc: dq 0.05
    ; Projektion parametrit
    distance: dq 5.0
    scale: dq 20.0
    half_width: dq 40.0
    half_height: dq 12.0

section .bss
    sin_val: resq 1
    cos_val: resq 1
    projected: resq 16  ; 2D-projisoidut koordinaatit (x, y 8 kärjelle)

section .text
global _start

_start:
    ; Alusta FPU
    finit


; Päälooppi

main_loop:
    ; Tyhjennä näyttö
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    lea rsi, [clear]
    mov rdx, clear_len
    syscall

    ; Laskee sinin ja cossin liikkuvuutta varten
    fld qword [angle]
    fsincos
    fstp qword [cos_val]
    fstp qword [sin_val]

    ; Muuttaa 3D-kärjet 2D:ksi
    xor rbx, rbx        ; Kärkien laskuri
project_loop:
    cmp rbx, 8
    jge project_done

    ; Lataa kärki (x, y, z)
    mov rsi, rbx
    shl rsi, 2
    lea rsi, [vertices + rsi*3]
    fld dword [rsi]     ; x
    fld dword [rsi+4]   ; y
    fld dword [rsi+8]   ; z

    ; Y-akselin kierto
    fld st1             ; y
    fmul qword [cos_val]
    fld st3             ; z
    fmul qword [sin_val]
    fsubp
    fstp st1            ; Päivitä y
    fld st2             ; z
    fmul qword [cos_val]
    fld st2             ; y
    fmul qword [sin_val]
    faddp
    fstp st3            ; Päivitä z

    ; Kierto X-akselin ympäri
    fld st1             ; y
    fmul qword [cos_val]
    fld st2             ; z
    fmul qword [sin_val]
    fsubp
    fstp st1            ; Päivitä y
    fld st2             ; z
    fmul qword [cos_val]
    fld st2             ; y
    fmul qword [sin_val]
    faddp
    fstp st3            ; Päivitä z

    ; Projektio
    fld st2             ; z
    fadd qword [distance]
    fld qword [scale]
    fdivrp              ; scale / (z + distance)
    fld st1             ; x
    fmul st1
    fadd qword [half_width]
    fistp qword [projected + rbx*16]  ; Tallenna x
    fld st2             ; y
    fmul st1
    fadd qword [half_height]
    fistp qword [projected + rbx*16 + 8] ; Tallenna y
    fstp st0            ; Poista scale
    fstp st0            ; Poista z
    fstp st0            ; Poista y
    fstp st0            ; Poista x

    inc rbx
    jmp project_loop

project_done:
    ; Tyhjennä puskuri
    lea rdi, [buffer]
    mov rcx, 80*24*8
    xor rax, rax
    rep stosb

    ; Piirrä reunat
    xor rbx, rbx        ; Reunojen laskuri
draw_loop:
    cmp rbx, 12
    jge draw_done

    ; Hae reunan kärjet
    movzx rsi, byte [edges + rbx*2]
    movzx rdi, byte [edges + rbx*2 + 1]

    ; Hae projisoidut koordinaatit
    mov rax, [projected + rsi*16]
    mov rcx, [projected + rsi*16 + 8]
    mov rdx, [projected + rdi*16]
    mov r8, [projected + rdi*16 + 8]

    ; Piirrä viiva (Bresenhamin algoritmi)
    push rbx
    call draw_line
    pop rbx

    inc rbx
    jmp draw_loop

draw_done:
    ; Näytä puskuri
    lea rsi, [buffer]
    mov rcx, 80*24
    mov rdi, 1          ; stdout
display_loop:
    cmp rcx, 0
    je display_done

    lodsb
    cmp al, 0
    je skip_char
    mov byte [rsi-1], 27
    mov byte [rsi], '['
    mov byte [rsi+1], '3'
    mov rbx, rcx
    and rbx, 7
    mov al, [colors + rbx]
    mov [rsi+2], al
    mov byte [rsi+3], 'm'
    mov byte [rsi+4], '#'
    mov byte [rsi+5], 27
    mov byte [rsi+6], '[0m'
    mov rax, 1
    mov rdx, 8
    syscall
    jmp next_char
skip_char:
    mov byte [rsi-1], ' '
    mov rax, 1
    mov rdx, 1
    syscall
next_char:
    dec rcx
    jmp display_loop

display_done:
    ; Päivitä kulma
    fld qword [angle]
    fadd qword [angle_inc]
    fstp qword [angle]

    ; Nuku ~16ms (60 FPS)
    mov rax, 35         ; sys_nanosleep
    mov rdi, timespec
    xor rsi, rsi
    mov qword [rdi], 0
    mov qword [rdi+8], 16000000
    syscall

    jmp main_loop

draw_line:
    ; Bresenhamin viiva-algoritmi
    ; rax, rcx: alku (x, y)
    ; rdx, r8: loppu (x, y)
    mov r9, rax
    sub rax, rdx
    jge no_abs_dx
    neg rax
no_abs_dx:
    mov r10, rcx
    sub rcx, r8
    jge no_abs_dy
    neg rcx
no_abs_dy:
    cmp rax, rcx
    jge steep
    xchg rax, rcx
    xchg r9, r10
    xchg rdx, r8
steep:
    mov r11, 1
    cmp r9, rdx
    jle no_swap_x
    xchg r9, rdx
    xchg r10, r8
no_swap_x:
    mov r12, 1
    cmp r10, r8
    jle no_neg_y
    neg r12
no_neg_y:
    mov rsi, rax
    shr rsi, 1
    mov rbx, r9
    mov rbp, r10
line_loop:
    cmp rbx, rdx
    jg line_done
    ; Piirrä pikseli
    cmp rbx, 0
    jl no_plot
    cmp rbx, 79
    jge no_plot
    cmp rbp, 0
    jl no_plot
    cmp rbp, 23
    jge no_plot
    mov rdi, rbp
    imul rdi, 80
    add rdi, rbx
    mov byte [buffer + rdi*8], '#'
no_plot:
    add rsi, rcx
    cmp rsi, rax
    jl no_step
    sub rsi, rax
    add rbp, r12
no_step:
    inc rbx
    jmp line_loop
line_done:
    ret

section .data
timespec: dq 0, 0
