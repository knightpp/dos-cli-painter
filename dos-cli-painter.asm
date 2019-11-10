use16
org 100h
    pusha
    mov dx, filename
    call create_file
    mov [filehandle], ax

    call set_block_cursor
    mov [printing], enable_print
    mov ah, 0x0
    mov al, 0x3  ; text mode 80x25 16 colours
    int 0x10
    popa
main:
enable_print = $
    call print_char_coloured
skip_print = $
    call set_block_cursor ; Why do i need to set the cursor shape every time?
    call get_curos_pos
    mov [cursor_position],dx
    mov [previous_cursor_position],dx
    call read_key
    mov dx, [cursor_position]
@@:
    cmp al, 'w'
    jne @f
    dec dh
@@:
    cmp al, 'a'
    jne @f
    dec dl
@@:
    cmp al, 's'
    jne @f
    inc dh
@@:
    cmp al, 'd'
    jne @f
    inc dl
@@:
    cmp al, 'z'
    jne @f
    inc [colour]
@@:
    cmp al, 'x'
    jne @f
    dec [colour]
@@:
    cmp al, 'q'     ; disable coloured output
    jne @f
    mov [printing], skip_print
@@:
    cmp al, 'e'     ; enable coloured output
    jne @f
    mov [printing], enable_print
@@:
    cmp al, 'f'     ; print to file
    jne @f
    call terminal_to_buffer
    mov dx,filename
    call create_file ; ax filehandle
    mov bx,ax
    mov dx,buffer
    mov cx,2025
    call write_to_file
    call close_file
@@:

    call set_cursor_pos

    jmp [printing]
.main_exit:@@:
    call read_key
    mov ax,4C00h
    int      21h

.vars:
    cursor_position dw 0x0
    previous_cursor_position dw 0x0
    colour db 0x0
    printing dw 0x0
    filename db "file.txt",0
    filehandle dw 0x0
    buffer db 2025 dup(0) ; 80*24 = 1920s


terminal_to_buffer:
    mov bx, buffer
    ;mov cx,2
    mov cx,25
.lp:
    push cx
    mov cx,80
    ;mov cx,3
.nested_loop:
    mov dl,cl
    pop ax
    mov dh,al
    push ax
    call set_cursor_pos    ; dh, dl
    call get_char_info     ; ax
    mov byte[bx],al
    inc bx
    cmp cx,0x1
    jne .continue
    mov byte[bx], 10 ; line feed (*unix)
    inc bx
.continue:
    loop .nested_loop
    pop cx      ; stack pointer overflow/underflow
    loop .lp
    RET


; Write to filehandle
; <- AH - 0x40
; <- BX - file handle
; <- DS:DX - buffer
; <- CX - number of bytes to be writted
; -> AX - if CF=1 => error
write_to_file:
    push bx
    push dx
    push cx
    mov ah,0x40
    int 0x21
    pop cx
    pop dx
    pop bx
    RET

; <- AH - 0x3E => const
; <- BX - file handle
; ?-> AX - error code if CF
close_file:
    push ax
    mov ah,0x3E
    int 0x21
    pop ax
    RET


; Create file, AX = 0 if error
; <- AH - 0x3C
; <- DS:DX - filename \0 terminated string ( "file.txt",0 )
; <- CX - file attribute
; -> AX - if CF it's error else file handle
create_file:
    push dx
    push cx
    mov ah, 0x3C
    mov cx,0 ; no special attributes
    int 0x21
    pop cx
    pop dx
    jc .error
    RET
.error:
    mov ax, 0x0
    RET


; Get char/attribute in cursor position
; <- BH - video page => const(0)
; -> AL - char
; -> AH - attribute 
get_char_info:
    push bx
    mov ah, 0x8
    mov bh, 0
    int 0x10
    pop bx
    RET


; Print char/attribue in cursor position
; <- BH - video page
; <- AL - char
; <- CX - repeat CX times
; <- BL - attribute or colour
print_char_coloured:
    mov ah, 0x9
    mov bh, 0
    mov al,219
    mov cx, 1
    mov bl, [colour]
    int 0x10
    RET

; <- DH - row
; <- DL - column
set_cursor_pos:
    push ax
    push bx        
    mov  ah, 0x2      ; set cursor pos
    mov  bh, 0      ; video page            
    int  0x10
    pop bx
    pop ax
    RET

; Read cursor position and size
; <- const -- BH - video page
; -> DH - row, DL - column
; -> CH - start pos, CL - end pos
get_curos_pos:
    push ax
    push bx
    mov ah, 0x3
    mov bh, 0
    int 0x10
    pop bx
    pop ax
    RET

; No echo read key
; -> AL - char
read_key:         
    mov ah,0x8
    int 0x21
    RET

; <- DL - char to print
print_char:
    mov ah, 0x02
    int 0x21
    RET

; Set cursor scanlines
; <- CH - start line
; <- CL - end line
set_block_cursor:
    mov cx,0x0007
    mov ah,0x1
    int 0x10
    RET