---
marp: true
theme: default
paginate: true
backgroundColor: #fff
backgroundImage: url('../assets/hero-background.svg')
style: |
  section {
    font-size: 28px;
    display: flex;
    flex-direction: column;
    justify-content: flex-start;
    align-items: flex-start;
    padding-top: 50px;
  }

  img[alt~="align-right"] {
    margin-left: 400px;
  }

  img[alt~="align-center"] {
    position: absolute;
    left: 50%;
    transform: translateX(-50%);
  }
  
  /* Right-align terminal commands */
  .terminal-commands {
    text-align: right;
    margin-left: 400px;
  }
  
  /* Make sub-bullets lighter and smaller */
  ul ul li, ol ol li {
    color: #666666;
    font-size: 0.9em;
  }
  
  /* Make nested sub-bullets even lighter, italic, and smaller */
  ul ul ul li, ol ol ol li {
    color: #666666;
    font-style: italic;
    font-size: 0.8em;
  }
  
  /* Alternative: Use opacity for a more subtle effect */
  ul ul, ol ol {
    opacity: 0.8;
  }

---

# Canal Seguro

Criptografía y TLS sobre TCP/IP

---

# Por qué necesitamos un canal seguro

- TCP/IP no proporciona autenticidad ni confidencialidad
- Con criptografía superponemos un canal seguro sobre TCP/IP
- Caso de estudio: TLS/SSL, ubicado entre la aplicación y TCP
- HTTP sobre SSL hace la Web "segura"; lo mismo con SMTP, IMAP y POP
- Objetivos: autenticar al servidor, mantener confidencialidad, detectar modificaciones y repeticiones
- Es un área de seguridad bien entendida y base sólida para aplicaciones

---

# Criptografía simétrica

- Una sola clave privada `K`, que debe llegar a ambos participantes
- Cifrado: `Encrypt(K, m) -> c` y `Decrypt(K, c) -> m`
- Firma o etiqueta: `MAC(K, m) -> t`
- Confidencialidad e integridad son propósitos distintos
- Las claves para cifrado y MAC deben ser diferentes
- Si se necesitan ambas cosas, se necesitan dos claves
- Es rápida: se usa para proteger el grueso del tráfico

---

# Criptografía asimétrica

- `KeyGen() -> PK, SK`: la pública se comparte, la privada es secreta
- Cifrado: `Encrypt(PK, m) -> c`; solo `Decrypt(SK, c)` recupera `m`
- Firma: `Sign(SK, m) -> sig`; `Verify(PK, m, sig)` la valida
- Las dos claves cumplen funciones complementarias
- Conocer `PK` no permite obtener `SK` en tiempo práctico
- Es más lenta: se usa para datos pequeños o para iniciar la conexión
- Idea de RSA: `n = p·q`; factorizar `n` es inviable con primos grandes

---

# Firmas digitales

- El emisor firma con su clave privada
- Cualquiera verifica con la clave pública correspondiente
- Primero hay que confiar en que esa clave pertenece al emisor
- Una firma válida demuestra autoría y que el mensaje no fue modificado
- Firmar no oculta el mensaje: no da confidencialidad
- En TLS, las firmas autentican al servidor y protegen el handshake

---

# Construir el canal: primer intento

- Objetivo: acordar una clave compartida para criptografía simétrica

```
C → S: conectar
C ← S: mi clave pública es PK_S
C → S: Encrypt(PK_S, freshKey)
C ↔ S: Encrypt(freshKey, m...)
```

- `freshKey` viaja cifrada y solo el servidor puede leerla
- Funciona contra un espía pasivo
- Pero no autentica al servidor: cualquier adversario puede enviar su propia `PK`

---

# Problema 1: ataque de hombre en el medio

- Un adversario intercepta los mensajes dirigidos al servidor
- La vista del cliente es exactamente la misma
- El cliente acuerda una clave con el adversario, no con el servidor
- El adversario se conecta al servidor real y reenvía mensajes
- Los mensajes posteriores parecen correctos para ambas partes
- Hace falta vincular `PK_S` con la identidad del servidor

---

# Solución: certificados

- Una autoridad de certificación (CA) mantiene pares nombre principal → clave pública
- El nombre principal suele ser el nombre DNS del servidor
- Todos confían en el mapeo de la CA y conocen su clave pública para arrancar
- La CA firma: `Sign(SK_CA, {servidor, PK_server})`
- El servidor envía el certificado; el cliente verifica la firma con `PK_CA`
- El adversario no puede fabricar un certificado válido para su propia clave
- Alternativa TOFU (SSH): confiar en la primera conexión y recordar el vínculo; más fácil, pero un primer MITM fija el error

---

# Problema 2: autenticar los mensajes

- El cifrado da confidencialidad, pero no integridad
- `Decrypt()` siempre "tiene éxito": no detecta manipulación
- El adversario altera el texto cifrado y obtiene otro texto plano
- A veces el efecto es predecible: voltear un bit del cifrado voltea un bit del mensaje
- Ejemplo: "Transferir $1 a Bob" puede convertirse en $129
- La confidencialidad no se rompe, pero la integridad sí

---

# Solución: cifrado autenticado

- Enviar `c = Encrypt(K1, m)` y `t = MAC(K2, c)`
- Usar claves distintas para cifrado y MAC
- El receptor verifica `t` antes de aceptar el mensaje
- Tras una manipulación la etiqueta es incorrecta y el mensaje se rechaza
- Esto se llama cifrado autenticado
- En TLS moderno, AEAD combina cifrado e integridad en una sola operación

---

# Replay: reenviar mensajes válidos

- El adversario no modifica nada: solo reenvía el mismo mensaje 129 veces
- Desde la perspectiva del servidor son 129 mensajes válidos
- La integridad y el cifrado no bastan: falta detectar repeticiones
- Solución: registrar mensajes ya vistos
  - Número de secuencia: descartar los menores al último visto (protocolos de flujo)
  - Expiración o ID de sesión: descartar duplicados dentro de la ventana (protocolos de mensajes)

---

# Problema 3: compromiso futuro

- Un atacante puede comprometer el servidor más adelante
- Con `SK_S` puede descifrar paquetes de red antiguos que haya grabado
- Eso revela la `freshKey` de esas sesiones
- Todo el tráfico pasado queda expuesto
- El problema aparece si la clave de sesión se cifró con la clave permanente
- Necesitamos que el pasado quede fuera del alcance de una clave robada después

---

# Solución: secreto hacia adelante

- Forward secrecy: por cada conexión se crean claves temporales
- Cliente y servidor intercambian solo la parte pública
- El servidor autentica el intercambio con su certificado
- Ambos calculan la misma clave de sesión; esta nunca viaja por la red
- Al terminar la conexión se eliminan las claves temporales
- Robar la clave permanente permite ataques futuros, no descifrar sesiones grabadas
- ECDHE es el mecanismo más común en TLS moderno

---

# SSL 2.0: por qué falló el primer intento

- Partes del handshake no estaban autenticadas
  - Un MITM podía borrar las opciones fuertes y forzar un algoritmo débil
- Usaba la misma clave para cifrado e integridad
  - Romper el cifrado permitía además falsificar mensajes
- Autenticaba con MD5, hoy criptográficamente débil
- Las sesiones se podían terminar con un TCP FIN insertado por un MITM
- Lección: usar criptografía no basta; hay que autenticar la negociación y separar claves

---

# SSL 3.0: el rediseño que sirvió de base

- Autenticó el handshake completo con mensajes **Finished** que detectan cambios
- Separó claves por dirección y propósito: distintas para cifrado e integridad
- Agregó números de secuencia a cada registro
  - Detecta alteraciones, replay y reordenamiento
- Incorporó alertas autenticadas: **close_notify** distingue cierre legítimo de truncamiento
- Separó el protocolo en Handshake, Record, Alert y ChangeCipherSpec

---

# De SSL 3.0 a TLS 1.0 y 1.1

- SSL nació en Netscape; la IETF lo tomó como base para un estándar abierto
- El nombre cambió a Transport Layer Security
- TLS 1.0 (1999): sucesor directo de SSL 3.0
  - Estandarizó el protocolo e introdujo HMAC; no era compatible byte a byte
- TLS 1.1 (2006): corrigió una debilidad de CBC
  - TLS 1.0 usaba el último bloque cifrado como IV del siguiente registro
  - TLS 1.1 envía un IV nuevo e impredecible por registro

---

# Qué salió mal en SSL y TLS antiguo

- **Downgrades:** forzar una versión o algoritmo débil manipulando la negociación
- **CBC y padding oracles:** errores o tiempos distintos filtran información
  - Permiten recuperar el texto plano byte a byte
- **Algoritmos heredados:** RC4, 3DES, MD5 y SHA-1 envejecieron mal
- **RSA key transport:** sin secreto hacia adelante
  - Robar después la clave del servidor descifra sesiones grabadas
- **Complejidad:** demasiadas versiones, opciones y combinaciones peligrosas

---

# TLS 1.2: transición hacia diseños modernos

- Permite algoritmos más fuertes, como SHA-256 y mejores firmas
- Permite proteger sesiones pasadas con intercambio temporal (ECDHE)
- Permite cifrar y verificar integridad en una sola operación (AEAD, AES-GCM)
- Problema: las mejoras eran opcionales
- Conserva RSA key transport, CBC y muchas configuraciones antiguas
- Resultado: puede ser seguro, pero depende de configurarlo bien
- La lección es hacer lo seguro el comportamiento por defecto

---

# TLS 1.3: seguridad moderna por defecto

- Elimina opciones peligrosas: RSA key transport, CBC, RC4, 3DES y compresión
- Hace normal el secreto hacia adelante con claves temporales (ECDHE)
- Exige AEAD: AES-GCM o ChaCha20-Poly1305
- Autentica el transcript del handshake y cifra gran parte de él
- Reduce latencia y complejidad: un solo viaje de ida y vuelta
- SSL 2.0, SSL 3.0, TLS 1.0 y TLS 1.1 están obsoletos

---

# TLS no resuelve todo

- Protege los datos **en tránsito** entre los extremos de la conexión
- No protege contra un servidor o cliente comprometido
- No corrige vulnerabilidades de la aplicación
- No evita phishing ni un dominio engañoso con certificado válido
- No protege datos robados antes de cifrar o después de descifrar
- TLS 1.3 0-RTT permite replay: la aplicación debe manejarlo
- Un canal seguro no convierte automáticamente a la aplicación en segura

---

# Preguntas de prueba (1/2)

**1. ¿Por qué el primer protocolo con clave pública no basta para autenticar al servidor?**

**Respuesta:**
- Cualquiera puede enviar su propia clave pública al cliente.
- Un MITM acuerda una clave con el cliente y reenvía hacia el servidor real.
- Falta vincular la clave pública con la identidad del servidor, y eso hacen los certificados.

**2. ¿Por qué el cifrado por sí solo no garantiza integridad?**

**Respuesta:**
- `Decrypt()` no detecta manipulación: siempre produce algún resultado.
- Cambiar bits del texto cifrado puede cambiar bits predecibles del texto plano.
- Se necesita un MAC con clave separada, o AEAD, para rechazar mensajes alterados.

---

# Preguntas de prueba (2/2)

**3. ¿Qué problema resuelve el secreto hacia adelante y cómo se logra?**

**Respuesta:**
- Evita que robar la clave permanente descifre sesiones antiguas grabadas.
- Se usan claves temporales por conexión, intercambiadas con ECDHE.
- La clave de sesión no viaja por la red y se elimina al terminar.

**4. ¿Qué cambia TLS 1.3 respecto de versiones anteriores y qué queda fuera de su alcance?**

**Respuesta:**
- Elimina RSA key transport, CBC y algoritmos débiles; exige AEAD y forward secrecy.
- Autentica el handshake completo y reduce el handshake a un viaje de ida y vuelta.
- Sigue sin proteger extremos comprometidos, fallos de aplicación ni phishing.
