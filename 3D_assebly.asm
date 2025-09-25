; Pyörivä 3D ASCII-kuutio Assemblyssä (Linux x86-64)
; nasm -f elf64 cube.asm && ld cube.o -o cube
; ./cube (Paina 'q' lopettaaksesi)

section .data
    ; 3D-kuution kärjet (x, y, z) 32-bit floatteina
    vertices: dd -1.0, -1.0, -1.0,  1.0, -1.0, -1.0,  1.0, 1.0, -1.0, -1.0, 1.0, -1.0
              dd -1.0, -1.0,  1.0,  1.0, -1.0,  1.0,  1.0, 1.0,  1.0, -1.0, 1.0,  1.0
    
    ; Reunat: kärkien indeksiparit
    edges: db 0,1, 1,2, 2,3, 3,0, 4,5, 5,6, 6,7, 7,4, 0,4, 1,5, 2,6, 3,7
    
    ; ANSI escape codes
    clear: db 27, '[2J', 27, '[H'
    clear_len equ $-clear
    green: db 27, '[32m'
    green_len equ $-green
    reset: db 27, '[0m'
    reset_len equ $-reset
    newline: db 10
    
    ; Matemaattiset vakiot
    angle: dq 0.0
    angle_inc: dq 0.05
    distance: dq 5.0
    scale: dq 20.0
    
    ; Näyttöparametrit
    SCREEN_WIDTH equ 80
    SCREEN_HEIGHT equ 24
    HALF_WIDTH equ 40
    HALF_HEIGHT equ 12
    
    ; Sleep time (16ms for ~60 FPS)
    timespec: dq 0, 16666667

section .bss
    buffer: resb SCREEN_WIDTH * SCREEN_HEIGHT
    zbuffer: resd SCREEN_WIDTH * SCREEN_HEIGHT
    sin_val: resq 1
    cos_val: resq 1
    projected: resq 16  ; x,y for 8 vertices
    input_char: resb 1
    termios_backup: resb 60
    termios_new: resb 60

section .text
global _start

_start:
    ; Initialize FPU
    finit
    
    ; Save terminal settings
    call save_terminal
    
    ; Set terminal to raw mode
    call setup_terminal

main_loop:
    ; Check for 'q' key
    call check_input
    test al, al
    jnz cleanup
    
    ; Clear screen
    call clear_screen
    
    ; Clear buffers
    call clear_buffers
    
    ; Calculate rotation
    call calculate_rotation
    
    ; Project vertices
    call project_vertices
    
    ; Draw edges
    call draw_edges
    
    ; Display buffer
    call display_buffer
    
    ; Update angle
    fld qword [angle]
    fadd qword [angle_inc]
    fstp qword [angle]
    
    ; Sleep
    mov rax, 35         ; sys_nanosleep
    lea rdi, [timespec]
    xor rsi, rsi
    syscall
    
    jmp main_loop

cleanup:
    call restore_terminal
    
    mov rax, 60         ; sys_exit
    xor rdi, rdi
    syscall

; Save terminal settings
save_terminal:
    mov rax, 16         ; sys_ioctl
    xor rdi, rdi        ; stdin
    mov rsi, 0x5401     ; TCGETS
    lea rdx, [termios_backup]
    syscall
    ret

; Setup terminal for raw mode
setup_terminal:
    ; Copy settings
    lea rsi, [termios_backup]
    lea rdi, [termios_new]
    mov rcx, 60/8
    rep movsq
    
    ; Disable canonical mode and echo
    mov eax, [termios_new + 12]  ; c_lflag
    and eax, ~(2 | 8)             ; ~ICANON & ~ECHO
    mov [termios_new + 12], eax
    
    ; Apply new settings
    mov rax, 16         ; sys_ioctl
    xor rdi, rdi        ; stdin
    mov rsi, 0x5402     ; TCSETS
    lea rdx, [termios_new]
    syscall
    
    ; Set non-blocking mode
    mov rax, 72         ; sys_fcntl
    xor rdi, rdi        ; stdin
    mov rsi, 3          ; F_GETFL
    syscall
    
    mov rdx, rax
    or rdx, 0x800       ; O_NONBLOCK
    mov rax, 72         ; sys_fcntl
    xor rdi, rdi
    mov rsi, 4          ; F_SETFL
    syscall
    ret

; Restore terminal settings
restore_terminal:
    mov rax, 16         ; sys_ioctl
    xor rdi, rdi        ; stdin
    mov rsi, 0x5402     ; TCSETS
    lea rdx, [termios_backup]
    syscall
    ret

; Check for input
check_input:
    mov rax, 0          ; sys_read
    xor rdi, rdi        ; stdin
    lea rsi, [input_char]
    mov rdx, 1
    syscall
    
    xor al, al
    cmp rax, 1
    jne .done
    cmp byte [input_char], 'q'
    jne .done
    mov al, 1
.done:
    ret

; Clear screen
clear_screen:
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    lea rsi, [clear]
    mov rdx, clear_len
    syscall
    ret

; Clear buffers
clear_buffers:
    ; Clear display buffer
    lea rdi, [buffer]
    mov rcx, SCREEN_WIDTH * SCREEN_HEIGHT
    mov al, ' '
    rep stosb
    
    ; Clear z-buffer
    lea rdi, [zbuffer]
    mov rcx, SCREEN_WIDTH * SCREEN_HEIGHT
    mov eax, 0x7FFFFFFF  ; Max int
    rep stosd
    ret

; Calculate sin and cos
calculate_rotation:
    fld qword [angle]
    fsincos
    fstp qword [cos_val]
    fstp qword [sin_val]
    ret

; Project vertices to 2D
project_vertices:
    xor r12, r12        ; vertex counter
    
.next_vertex:
    cmp r12, 8
    jge .done
    
    ; Load vertex (x, y, z)
    lea rsi, [vertices + r12*12]
    
    ; Load coordinates
    fld dword [rsi]     ; x
    fld dword [rsi+4]   ; y  
    fld dword [rsi+8]   ; z
    
    ; Rotate around Y axis: x' = x*cos - z*sin, z' = x*sin + z*cos
    fld st0             ; z z y x
    fld qword [sin_val] ; sin z z y x
    fmulp               ; z*sin z y x
    fld st3             ; x z*sin z y x
    fld qword [cos_val] ; cos x z*sin z y x
    fmulp               ; x*cos z*sin z y x
    fsubp               ; x' z y x
    fxch st2            ; y z x' x
    fxch st1            ; z y x' x
    fld qword [cos_val] ; cos z y x' x
    fmulp               ; z*cos y x' x
    fld st3             ; x z*cos y x' x
    fld qword [sin_val] ; sin x z*cos y x' x
    fmulp               ; x*sin z*cos y x' x
    faddp               ; z' y x' x
    fxch st3            ; x y x' z'
    fstp st0            ; y x' z'
    fxch st1            ; x' y z'
    
    ; Rotate around X axis: y' = y*cos - z*sin, z' = y*sin + z*cos
    fld st2             ; z' x' y z'
    fld qword [sin_val] ; sin z' x' y z'
    fmulp               ; z'*sin x' y z'
    fld st2             ; y z'*sin x' y z'
    fld qword [cos_val] ; cos y z'*sin x' y z'
    fmulp               ; y*cos z'*sin x' y z'
    fsubp               ; y' x' y z'
    fxch st2            ; y x' y' z'
    fld qword [sin_val] ; sin y x' y' z'
    fmulp               ; y*sin x' y' z'
    fld st3             ; z' y*sin x' y' z'
    fld qword [cos_val] ; cos z' y*sin x' y' z'
    fmulp               ; z'*cos y*sin x' y' z'
    faddp               ; z'' x' y' z'
    fxch st3            ; z' x' y' z''
    fstp st0            ; x' y' z''
    
    ; Perspective projection
    fld st2             ; z'' x' y' z''
    fadd qword [distance] ; z+d x' y' z''
    
    ; Check if behind camera
    fldz
    fcomip st1
    jae .skip_vertex
    
    ; Project x
    fld qword [scale]   ; scale z+d x' y' z''
    fdiv st1            ; scale/(z+d) z+d x' y' z''
    fmul st2            ; x_proj z+d x' y' z''
    fiadd dword [const_half_width]
    fistp qword [projected + r12*16]
    
    ; Project y
    fld qword [scale]   ; scale z+d x' y' z''
    fdiv st1            ; scale/(z+d) z+d x' y' z''
    fmul st3            ; y_proj z+d x' y' z''
    fiadd dword [const_half_height]
    fistp qword [projected + r12*16 + 8]
    
    ; Clean FPU stack
    fstp st0            ; z+d x' y' z''
    fstp st0            ; x' y' z''
    fstp st0            ; y' z''
    fstp st0            ; z''
    fstp st0            ; empty
    
    jmp .continue
    
.skip_vertex:
    ; Mark as invalid
    mov qword [projected + r12*16], -1
    mov qword [projected + r12*16 + 8], -1
    
    ; Clean FPU stack
    fstp st0
    fstp st0
    fstp st0
    fstp st0
    
.continue:
    inc r12
    jmp .next_vertex
    
.done:
    ret

const_half_width: dd 40
const_half_height: dd 12

; Draw edges
draw_edges:
    xor r12, r12        ; edge counter
    
.next_edge:
    cmp r12, 12
    jge .done
    
    ; Get vertex indices
    movzx rax, byte [edges + r12*2]
    movzx rdx, byte [edges + r12*2 + 1]
    
    ; Get coordinates
    mov r8, [projected + rax*16]
    mov r9, [projected + rax*16 + 8]
    mov r10, [projected + rdx*16]
    mov r11, [projected + rdx*16 + 8]
    
    ; Check validity
    cmp r8, 0
    jl .skip
    cmp r10, 0
    jl .skip
    
    ; Draw line
    call draw_line
    
.skip:
    inc r12
    jmp .next_edge
    
.done:
    ret

; Simple line drawing (r8,r9) to (r10,r11)
draw_line:
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    ; Calculate deltas
    mov rax, r10
    sub rax, r8         ; dx
    mov rbx, r11
    sub rbx, r9         ; dy
    
    ; Get absolute values
    mov r12, rax
    sar r12, 63
    xor rax, r12
    sub rax, r12        ; |dx|
    
    mov r12, rbx
    sar r12, 63
    xor rbx, r12
    sub rbx, r12        ; |dy|
    
    ; Determine step direction
    mov r12, 1          ; x_step
    cmp r8, r10
    jle .x_positive
    neg r12
.x_positive:
    
    mov r13, 1          ; y_step
    cmp r9, r11
    jle .y_positive
    neg r13
.y_positive:
    
    ; Current position
    mov r14, r8         ; x
    mov r15, r9         ; y
    
    ; Determine dominant axis
    cmp rax, rbx
    jge .x_dominant
    
    ; Y-dominant
    mov rcx, rbx        ; steps = |dy|
    neg rax
    sar rbx, 1          ; error = |dy|/2
    
.y_loop:
    call plot_point
    add rbx, rax        ; error += |dx|
    jle .y_no_x_step
    add r14, r12        ; x += x_step
    sub rbx, rax        ; error -= |dy|
    sub rbx, rax
    neg rax
.y_no_x_step:
    add r15, r13        ; y += y_step
    dec rcx
    jns .y_loop
    jmp .done
    
.x_dominant:
    ; X-dominant
    mov rcx, rax        ; steps = |dx|
    neg rbx
    sar rax, 1          ; error = |dx|/2
    
.x_loop:
    call plot_point
    add rax, rbx        ; error += |dy|
    jle .x_no_y_step
    add r15, r13        ; y += y_step
    sub rax, rbx        ; error -= |dx|
    sub rax, rbx
    neg rbx
.x_no_y_step:
    add r14, r12        ; x += x_step
    dec rcx
    jns .x_loop
    
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Plot point at (r14, r15)
plot_point:
    ; Bounds check
    cmp r14, 0
    jl .skip
    cmp r14, SCREEN_WIDTH
    jge .skip
    cmp r15, 0
    jl .skip
    cmp r15, SCREEN_HEIGHT
    jge .skip
    
    ; Calculate buffer offset
    mov rax, r15
    imul rax, SCREEN_WIDTH
    add rax, r14
    
    ; Set character
    mov byte [buffer + rax], '#'
    
.skip:
    ret

; Display buffer
display_buffer:
    ; Write green color code
    mov rax, 1
    mov rdi, 1
    lea rsi, [green]
    mov rdx, green_len
    syscall
    
    ; Display buffer line by line
    xor r12, r12        ; line counter
    
.next_line:
    cmp r12, SCREEN_HEIGHT
    jge .done
    
    ; Write line
    mov rax, 1
    mov rdi, 1
    mov rsi, r12
    imul rsi, SCREEN_WIDTH
    lea rsi, [buffer + rsi]
    mov rdx, SCREEN_WIDTH
    syscall
    
    ; Write newline
    mov rax, 1
    mov rdi, 1
    lea rsi, [newline]
    mov rdx, 1
    syscall
    
    inc r12
    jmp .next_line
    
.done:
    ; Reset color
    mov rax, 1
    mov rdi, 1
    lea rsi, [reset]
    mov rdx, reset_len
    syscall
    ret
