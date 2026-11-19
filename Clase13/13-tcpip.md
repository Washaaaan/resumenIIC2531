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

# Seguridad TCP/IP

Ataques a los protocolos centrales de Internet

---

# Modelo de amenaza

- Internet es una red abierta, descentralizada: nadie está a cargo
- El adversario puede mirar los datos
- Puede enviar paquetes arbitrarios
- Puede modificar paquetes en tránsito
- Desafíos: autenticación, confidencialidad, liveness y privacidad

---

# El núcleo de Internet no da seguridad

- Muchos ISPs con acuerdos de peering; protocolos definidos en RFCs
- TCP, UDP, BGP, DHCP, DNS, telnet, FTP, IMAP
- Cambiar un protocolo es mucho más difícil que cambiar una implementación
  - IPv4 a IPv6 lo demuestra
- Progreso en capas superiores: Kerberos, SSH, SSL
- El diseño prioriza liveness y deja la seguridad en los extremos
- Funciona y soporta comercio electrónico, pero los ataques antiguos siguen vigentes

---

# Caso de estudio: telnet y rlogin (ca. 1980)

- telnet abre una conexión TCP al login, sin cifrado
  - El atacante puede espiar la contraseña
  - Puede modificar o inyectar datos
  - Puede redirigir la conversación vía enrutamiento
- rlogin no envía contraseña: confía en `.rhosts`
  - Permite entrar si el host de origen está en la lista
- Ethernet masificó el sniffing: el riesgo dejó de ser teórico

---

# Por qué rlogin parecía aceptable

- Los autores no habrían dicho "seguro", quizá "bastante bueno"
- Riesgo obvio: falsificar la IP del cliente confiable en el campo origen
- Pero TCP involucra ambas direcciones
- Si el atacante miente sobre la fuente, las respuestas no le llegan
- Sin recibir el SYN-ACK no puede completar el handshake correctamente
- La seguridad dependía de que adivinar el estado TCP fuera difícil

---

# Handshake TCP

- `C → S: SYN(SNc)`
- `S → C: SYN(SNs), ACK(SNc+1)`
- `C → S: ACK(SNs+1)`
- `C → S: data(SNc), ACK(SNs)`
- El objetivo es fijar los números de secuencia iniciales (ISN)
- Solo C debería recibir el segundo mensaje y, por tanto, conocer `SNs`
- El servidor acepta el tercer paquete solo si trae el `SNs` esperado

---

# Ataque: adivinar el número de secuencia

- A quiere simular una conexión a S desde C
- A conoce la IP de C: normalmente no es un secreto
- Envía `SYN(SNc)` con origen C; S responde a C con `SYN(SNs)`
- A necesita adivinar `SNs` para enviar `ACK(SNs+1)`
- Muchos hosts usaban un ISN global predecible: +128/s y +64 por conexión
- A hace una conexión normal, observa el ISN y suma 64
- El paquete real llega a C y provoca un RST, pero A puede competir antes

---

# Consecuencia 1: autenticación por IP

- El atacante se hace pasar por un host de la lista de rlogin
- Envía comandos sin conocer ninguna contraseña
- rlogin asumió que una conexión TCP desde una IP venía de ese host
- Peor aún: usaba DNS inverso para obtener el nombre
  - El dueño del dominio inverso puede declarar cualquier nombre
- Mitigación parcial: verificar que el nombre resuelva de vuelta a la misma IP
- Lección: la capa TCP no autentica la identidad del extremo

---

# Consecuencia 2: reset de conexiones

- Si se adivina `SNc`, se puede inyectar un paquete RST
- El servidor acepta un RST para cualquier secuencia dentro de la ventana
- Un reset no es solo una molestia: corta la comunicación
- Objetivo clásico: sesiones TCP entre enrutadores BGP
- Los enrutadores interpretan el corte como falla de enlace
- El tráfico puede verse afectado por minutos

---

# Consecuencia 3: secuestro de conexiones

- Adivinar números de secuencia permite inyectar datos en una conexión viva
- Se espera a que alguien inicie sesión y se toma el control
- El atacante puede insertar comandos sin autenticarse de nuevo
- Referencias: "Blind TCP/IP hijacking is still alive" (2007)
- Y ataques de secuestro reportados en USENIX Security 2016
- Es la versión activa del mismo problema: el estado TCP es adivinable

---

# Mitigación: no autenticar por IP

- **No usar autenticación basada en dirección IP**
- Preferir autenticación criptográfica extremo a extremo
  - SSH, SSL/TLS, Kerberos
- Los ISPs pueden filtrar paquetes con origen obviamente falsificado
- El núcleo de Internet no está diseñado para autenticar
- La seguridad debe vivir en los extremos
- Próxima clase: cómo SSL construye ese canal

---

# Fortalecer TCP: ISN por conexión

- Hacer más difícil adivinar el siguiente ISN
- No se puede elegir totalmente al azar sin violar TCP: evitar secuencias recientes del mismo par
- Incrementos aleatorios limitados: no conviene envolver muy rápido
- Los SN de pares src/dst distintos nunca interactúan
- `ISN = ISN_oldstyle + SHA1(srcip, srcport, dstip, dstport, secret)`
- Sin estado extra y el atacante ya no puede extrapolar el ISN de otro cliente
- Implementado en Linux (`secure_tcp_sequence_number`, hoy con SipHash)

---

# El mismo problema en DNS

- DNS corre sobre UDP: sin números de secuencia, solo puertos
- El puerto destino es fijo (53); el cliente hace verificaciones básicas
- Si el adversario sabe que hay una consulta, puede falsificar la respuesta
- Solo necesita adivinar el puerto de origen, a menudo predecible
- Ataque popular desde 2008 (Kaminsky)
- Defensa: aprovechar toda la aleatoriedad posible
  - ID de consulta de 16 bits más ~16 bits de puerto de origen

---

# DNSSEC y sus límites

- DNSSEC firma los registros DNS, incluidos los "no existe"
- Problema: distribución de claves; ¿quién puede firmar cada dominio?
- Problema: enumeración de nombres al firmar respuestas negativas
  - Mitigado en parte por NSEC3
- Adopción lenta: poco incentivo, costos de rendimiento y administración
- La cadena de confianza agrega complejidad operativa

---

# SYN flooding

- Liveness: dependemos de que la red entregue datos; el DoS puede ser molestia, extorsión o parte de un ataque mayor
- El servidor guarda estado de cada conexión medio abierta y espera el `ACK(SNs)` por minutos
- Mantiene, por ejemplo, 50 conexiones pendientes; si están llenas, ignora las nuevas
- Ataque: enviar SYN con IPs de origen aleatorias falsificadas
- Las víctimas falsas no responden y el servidor nunca recibe el tercer paquete
- Las ranuras se llenan y los clientes legítimos quedan fuera
- Difícil de rastrear: origen falsificado y tasa baja

---

# Defensa: SYN cookies

- Idea: el servidor no guarda estado hasta recibir el tercer paquete
- Complicación: el estado ayudaba a verificar que la IP de origen no era falsa
- Solución: codificar el estado en el número de secuencia con criptografía
- `ISNs = SNc + (timestamp || SHA1(src/dst addr+port, secret, timestamp))`
- Timestamp grueso (minutos); cada cliente tiene su propio hash
- El servidor valida el hash del ACK sin haber guardado nada
- Detuvo con éxito ataques de SYN flooding de baja tasa

---

# Amplificación de ancho de banda

- Objetivo: abrumar al servidor o su enlace para descartar tráfico legítimo
- Smurf: ICMP echo a la dirección de broadcast de una subred
  - Se falsifica el origen de la víctima y todas las máquinas le responden
  - Una subred de 100 equipos da amplificación de 100x
- Defensa: los enrutadores bloquean el broadcast dirigido
- Variantes modernas: DNS (más aún con DNSSEC), Memcached y middleboxes
- Común: UDP sin handshake y origen fácil de falsificar

---

# Enrutamiento: participantes demasiado confiados

- ARP: dentro de una red Ethernet se difunde "¿quién tiene esta IP?"
  - Cualquiera responde sin autenticación
  - El atacante se hace pasar por el enrutador e intercepta tráfico
- DHCP: el cliente pide IP por difusión, el servidor responde sin autenticación
  - Define IP, enrutador, servidor DNS y dominio; un servidor falso controla nuevos clientes
- BGP: los ISP confían en los anuncios de sus pares; uno incorrecto redirige o niega tráfico a gran escala

---

# Información pública: reconocimiento

- Internet abierta facilita descubrir objetivos
- Sondeo de puertos bien conocidos y banners iniciales
- nmap infiere el sistema operativo por detalles de implementación
- DNS inverso revela nombres de host y pistas de propósito
- traceroute descubre enrutadores en el camino, útiles para ataques BGP
- Ese reconocimiento alimenta ataques directos, indirectos y botnets

---

# Defensas y conclusiones

- Correcciones compatibles con el protocolo en las implementaciones TCP
- Firewalls: corrección parcial y ampliamente usada
  - El adversario puede estar dentro de la red protegida
  - Es difícil decidir si un paquete es malicioso
  - Aun los campos presentes (src/dst) son difíciles de autenticar
- Criptografía sobre TCP/IP: SSL/TLS, Kerberos, SSH
- Pendientes: diseño de protocolo, distribución de claves y confianza

---

# Preguntas de prueba (1/2)

**1. ¿Por qué un atacante puede completar un handshake TCP falsificando la IP de origen?**

**Respuesta:**
- No necesita recibir el SYN-ACK; solo adivinar el ISN del servidor.
- Si el ISN es predecible, puede enviar el ACK correcto a ciegas.
- Las respuestas del servidor van a la víctima, no al atacante.

**2. ¿Qué logran las SYN cookies y qué problema resuelven?**

**Respuesta:**
- Permiten al servidor no guardar estado de conexiones medio abiertas.
- Codifican el estado en el ISN con un hash por par de direcciones y puertos.
- Evitan que un SYN flooding agote las ranuras y bloquee clientes legítimos.

---

# Preguntas de prueba (2/2)

**3. ¿Por qué no basta con que TCP use números de secuencia para autenticar?**

**Respuesta:**
- Los números de secuencia protegen el orden, no la identidad del extremo.
- Si son predecibles, permiten falsificar origen, inyectar RST o secuestrar sesiones.
- La autenticación real requiere criptografía extremo a extremo.

**4. ¿Qué tienen en común Smurf, la amplificación DNS y los ataques con Memcached?**

**Respuesta:**
- Usan solicitudes pequeñas con origen falsificado.
- Generan respuestas mucho mayores dirigidas a la víctima.
- Se apoyan en UDP o broadcast, donde no hay handshake que valide el origen.
