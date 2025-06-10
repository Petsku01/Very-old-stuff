; Pyörivä 3D ASCII-kuutio Assemblyssä (Linux)
; nasm -f elf64 cube.asm && ld cube.o -o cube
; Toimiva 2025
; Suorita: ./cube (Paina 'q' lopettaaksesi)

section .data
    ; 3D-kuution kärjet (x, y, z) 32-bit floatteina
    vertices: dd -1.0, -1.0, -1.0,  1.0, -1.0, -1.0,  1.0, 1.0, -1.0, -1.0, 1.0, -1.0
              dd -1.0, -1.0,  1.0,  1.0, -1.0,  1.0,  1.0, 1.0,  1.0, -1.0, 1.0,  1.0
    ; Reunat: kärkien indeksiparit
    edges: db 0,1, 1,2, 2,3, 3,0, 4,5, 5,6, 6,7, 7,4, 0,4, 1,5, 2,6, 3,7
    ; ANSI-värikoodit (vihreä '#')
    color: db 27, '[', '3', '2', 'm', '#', 27, '[0m'
    color_len: equ $-color
    space: db ' '
    ; Tyhjennä näyttö ja siirrä kursori vasempaan yläkulmaan
    clear: db 27, '[2J', 27, '[0;0H'
    clear_len: equ $-clear
    ; Matemaattiset vakiot (64-bit doubles)
    pi: dq 3.141592653589793
    angle: dq 0.0
    angle_inc: dq 0.05
    ; Projektion parametrit
    distance: dq 4.0
    scale: dq 20.0
    half_width: dq 40.0
    half_height: dq 12.0
    timespec: dq 0, 16000000 ; 16ms for ~60 FPS
    ; Terminaalin asetukset
    TERMIOS_SIZE equ 60
    termios: times TERMIOS_SIZE db 0
    termios_backup: times TERMIOS_SIZE db 0
    ; Näyttöparametrit
    SCREEN_WIDTH equ 80
    SCREEN_HEIGHT equ 24

section .bss
    buffer: resb SCREEN_WIDTH*SCREEN_HEIGHT
    sin_val: resq 1
    cos_val: resq 1
    projected: resq 16  ; 2D-projisoidut koordinaatit (x, y 8 kärjelle)
    input_char: resb 1

section .text
global _start

_start:
    ; Alusta FPU
    finit

    ; Alusta .bss
    lea rdi, [buffer]
    mov rcx, SCREEN_WIDTH*SCREEN_HEIGHT + 2*8 + 16*8 + 1
    xor al, al
    rep stosb

    ; Aseta stdin non-blocking
    mov rax, 72         ; sys_fcntl
    mov rdi, 0          ; stdin
    mov rsi, 4          ; F_GETFL
    syscall
    cmp rax, -1
    je error_exit
    mov rbx, rax        ; Save flags
    mov rax, 72         ; sys_fcntl
    mov rsi, 4          ; F_SETFL
    or rbx, 0x0800      ; O_NONBLOCK
    mov rdx, rbx
    syscall
    cmp rax, -1
    je error_exit

    ; Save terminal settings
    mov rax, 16         ; sys_ioctl
    mov rdi, 0          ; stdin
    mov rsi, 0x5401     ; TCGETS
    lea rdx, [termios_backup]
    syscall
    cmp rax, -1
    je error_exit

    ; Disable canonical mode and echo
    lea rdi, [termios]
    lea rsi, [termios_backup]
    mov rcx, TERMIOS_SIZE/8
    rep movsq
    mov eax, [termios+12] ; c_lflag
    and eax, ~(0x02 | 0x08) ; ~ICANON & ~ECHO
    mov [termios+12], eax
    mov rax, 16         ; sys_ioctl
    mov rdi, 0          ; stdin
    mov rsi, 0x5402     ; TCSETS
    lea rdx, [termios]
    syscall
    cmp rax, -1
    je error_exit

; Päälooppi
main_loop:
    ; Tarkista näppäimistö ('q' lopettaa)
    mov rax, 0          ; sys_read
    mov rdi, 0          ; stdin
    lea rsi, [input_char]
    mov rdx, 1
    syscall
    cmp rax, 0
    jle next_char_check
    cmp byte [input_char], 'q'
    je restore_term
next_char_check:

    ; Tyhjennä näyttö
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    lea rsi, [clear]
    mov rdx, clear_len
    call write_buffer

    ; Laske sini ja kosini
    fld qword [angle]
    fsincos
    fstp qword [cos_val]
    fstp qword [sin_val]

    ; Projisoi 3D-kärjet 2D:ksi
    xor rbx, rbx        ; Kärkien laskuri
project_loop:
    cmp rbx, 8
    jge project_done

    ; Lataa kärki (x, y, z)
    mov rsi, rbx
    lea rsi, [vertices + rsi*12] ; 3 floats * 4 bytes = 12 bytes
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

    ; X-akselin kierto
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

    ; Perspektiiviprojektio
    fld st2             ; z
    fadd qword [distance]
    fldz
    fcomip st1
    fstp st0
    jbe skip_vertex     ; Skip if z + distance <= 0
    fld qword [scale]
    fdivrp              ; scale / (z + distance)
    fld st1             ; x
    fmul st1
    fadd qword [half_width]
    fistp qword [projected + rbx*16]  ; Tallenna x
    mov rax, [projected + rbx*16]
    cmp rax, 0
    jl skip_vertex
    cmp rax, SCREEN_WIDTH-1
    jg skip_vertex
    fld st2             ; y
    fmul st1
    fadd qword [half_height]
    fistp qword [projected + rbx*16 + 8] ; Tallenna y
    mov rax, [projected + rbx*16 + 8]
    cmp rax, 0
    jl skip_vertex
    cmp rax, SCREEN_HEIGHT-1
    jg skip_vertex
    fstp st0            ; Poista scale
    fstp st0            ; Poista z
    fstp st0            ; Poista y
    fstp st0            ; Poista x
    jmp next_vertex
skip_vertex:
    fstp st0            ; Poista scale tai z
    fstp st0            ; Poista z
    fstp st0            ; Poista y
    fstp st0            ; Poista x
    mov qword [projected + rbx*16], 0
    mov qword [projected + rbx*16 + 8], 0
next_vertex:
    inc rbx
    jmp project_loop

project_done:
    ; Tyhjennä puskuri
    lea rdi, [buffer]
    mov rcx, SCREEN_WIDTH*SCREEN_HEIGHT
    mov al, ' '
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

    ; Tarkista, onko kärjet kelvollisia
    cmp rax, 0
    jle skip_edge
    cmp rcx, 0
    jle skip_edge
    cmp rdx, 0
    jle skip_edge
    cmp r8, 0
    jle skip_edge

    ; Piirrä viiva
    push rbx
    call draw_line
    pop rbx

skip_edge:
    inc rbx
    jmp draw_loop

draw_done:
    ; Näytä puskuri
    lea rsi, [buffer]
    mov rcx, SCREEN_WIDTH*SCREEN_HEIGHT
display_loop:
    cmp rcx, 0
    je display_done

    lodsb
    cmp al, ' '
    je skip_char
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    lea rsi, [color]
    mov rdx, color_len
    call write_buffer
    jmp next_char
skip_char:
    mov rax, 1
    mov rdi, 1
    lea rsi, [space]
    mov rdx, 1
    call write_buffer
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
    lea rdi, [timespec]
    mov qword [timespec], 0
    mov qword [timespec+8], 16000000
    xor rsi, rsi
    syscall
    cmp rax, -4         ; -EINTR
    je main_loop
    cmp rax, -1
    je error_exit

    jmp main_loop

restore_term:
    mov rax, 16         ; sys_ioctl
    mov rdi, 0          ; stdin
    mov rsi, 0x5402     ; TCSETS
    lea rdx, [termios_backup]
    syscall
    jmp exit

; Kirjoita puskuri, käsittele osittaiset kirjoitukset
write_buffer:
    mov r10, rdx        ; Save total length
.write_loop:
    mov rax, 1          ; sys_write
    syscall
    cmp rax, -1
    je error_exit
    add rsi, rax        ; Advance buffer
    sub r10, rax        ; Decrease remaining length
    jz .done            ; All bytes written
    mov rdx, r10        ; Update length
    jmp .write_loop
.done:
    ret

; Bresenhamin viiva-algoritmi
draw_line:
    ; rax, rcx: alku (x, y)
    ; rdx, r8: loppu (x, y)
    cmp rax, rdx
    jne not_same_point
    cmp rcx, r8
    je plot_single_point
not_same_point:
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
    cmp rax, 0
    je vertical_line
    cmp rcx, 0
    je horizontal_line
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
    cmp rbx, SCREEN_WIDTH-1
    jge no_plot
    cmp rbp, 0
    jl no_plot
    cmp rbp, SCREEN_HEIGHT-1
    jg no_plot
    mov rdi, rbp
    imul rdi, SCREEN_WIDTH
    add rdi, rbx
    mov byte [buffer + rdi], '#'
no_plot:
    add rsi, rcx
    cmp rsi, rax
    jl no_step
    sub rsi, rax
    add rbp, r12
no_step:
    inc rbx
    jmp line_loop
plot_single_point:
    cmp rax, 0
    jl line_done
    cmp rax, SCREEN_WIDTH-1
    jge line_done
    cmp rcx, 0
    jl line_done
    cmp rcx, SCREEN_HEIGHT-1
    jg line_done
    mov rdi, rcx
    imul rdi, SCREEN_WIDTH
    add rdi, rax
    mov byte [buffer + rdi], '#'
    jmp line_done
vertical_line:
    cmp r10, r8
    jle no_swap_v
    xchg r10, r8
no_swap_v:
    mov rbx, r9
    mov rbp, r10
vline_loop:
    cmp rbp, r8
    jg line_done
    cmp rbx, 0
    jl no_vplot
    cmp rbx, SCREEN_WIDTH-1
    jge no_vplot
    cmp rbp, 0
    jl no_vplot
    cmp rbp, SCREEN_HEIGHT-1
    jg no_vplot
    mov rdi, rbp
    imul rdi, SCREEN_WIDTH
    add rdi, rbx
    mov byte [buffer + rdi], '#'
no_vplot:
    inc rbp
    jmp vline_loop
horizontal_line:
    cmp r9, rdx
    jle no_swap_h
    xchg r9, rdx
no_swap_h:
    mov rbx, r9
    mov rbp, r10
hline_loop:
    cmp rbx, rdx
    jg line_done
    cmp rbx, 0
    jl no_hplot
    cmp rbx, SCREEN_WIDTH-1
    jge no_hplot
    cmp rbp, 0
    jl no_hplot
    cmp rbp, SCREEN_HEIGHT-1
    jg no_hplot
    mov rdi, rbp
    imul rdi, SCREEN_WIDTH
    add rdi, rbx
    mov byte [buffer + rdi], '#'
no_hplot:
    inc rbx
    jmp hline_loop
line_done:
    ret

exit:
    mov rax, 60         ; sys_exit
    xor rdi, rdi        ; status 0
    syscall

error_exit:
    mov rax, 16         ; sys_ioctl
    mov rdi, 0          ; stdin
    mov rsi, 0x5402     ; TCSETS
    lea rdx, [termios_backup]
    syscall
    mov rax, 60
    mov rdi, 1          ; status 1
    syscall
