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

# Seguridad en Mensajería

### IIC2531 — Clase 19

De PGP a Signal: confianza, conversaciones,
metadatos y trade-offs.

---

# ¿Por qué mensajería?

- Importa en la práctica y hay fallos reales: análisis de Zoom por Citizen Lab (2020).
- El problema es acotado: conocemos muchas técnicas y aún aparecen ideas nuevas.
- Los usuarios suelen estar online: handshake y secretos efímeros son posibles.
- Pero en mensajería no siempre ambos están online: hay almacenamiento y asincronía.
- **Confidencialidad.** Solo Alice y Bob leen M.
- **Autenticidad.** Bob confirma que Alice lo envió; también importa la integridad.
- Otras propiedades: negabilidad, forward secrecy y privacidad de metadatos.

---

# Correo: muchos actores y saltos

- Es antiguo, ubicuo y muy expuesto: esperaríamos alta seguridad y no la tiene.
- Ruta típica: usuario → proveedor → listas → redirecciones → filtros → archivo → destinatario.
- Cada salto usa DNS y servidores distintos; 10 a 20 hops es normal.
- **STARTTLS** protege enlace por enlace, normalmente de forma oportunista.
- **POP/IMAP sobre TLS** evita espionaje del buzón; **DKIM** firma por organización origen.
- **ARC** conserva resultados de autenticación al reenviar; **BIMI/VMC** autentican logos.
- La seguridad se agregó gradualmente por la enorme base instalada.

---

# Hop-by-hop vs extremo a extremo

- Hop-by-hop no compone: proteger cada enlace no garantiza el extremo a extremo.
- Cada servidor ve el mensaje en claro y puede leerlo o modificarlo.
- Garantizar TLS en todos los saltos es frágil: depende de configuraciones y personas.
- **E2E.** Solo dependen los usuarios y sus dispositivos finales.
- El remitente cifra y firma; el destinatario verifica y descifra; los intermediarios son irrelevantes.
- Lo adoptan WhatsApp, iMessage, Signal y Keybase.
- **Precio.** La gestión de claves y dispositivos recae en los usuarios.

---

# Marco de análisis y primitivas

- Tres ejes: **establecimiento de confianza**, **protocolo de conversación**, **privacidad de transporte**.
- `h = Hash(m)`, `tag = MAC(K, m)`, `c = E(K, m)`.
- Cifrado asimétrico: `c = E(PK_Bob, m)` y `m = D(SK_Bob, c)`.
- Firma: `s = Sign(SK_Alice, m)` y `Verify(PK_Alice, m, s)`.
- Cada eje enfrenta adversarios distintos y resuelve un problema distinto.
- Los ejes interactúan: una clave mal establecida arruina el mejor cifrado.

---

# Mensaje único seguro (tipo PGP)

- **Objetivo.** Confidencialidad y autenticidad para un mensaje almacenado.
- Alice calcula `c = E(PK_Bob, m)` y `s = Sign(SK_Alice, c)`; envía `(c, s)`.
- Bob verifica la firma y descifra con `SK_Bob`.
- **Preguntas.** ¿Firmar `c` o `m`? ¿Incluir identidades y contexto dentro de `m`?
- **Replay.** El adversario puede reinyectar `(c, s)` sin modificarlo.
- La autenticidad depende de que Bob conozca la PK correcta de Alice.
- **Sin forward secrecy.** Quien robe `SK_Bob` descifra grabaciones antiguas.

---

# Canales seguros

- Motivo: chat, voz y video requieren ida y vuelta; el handshake se amortiza.
- `A→B`: `E(PK_B, A||B||r_A)` más firma; `B→A` análogo con `r_B`.
- Comparten `r_A||r_B` y derivan `K_x = Hash(r_A||r_B||x)`.
- Datos: `E(K1, M)` con `MAC(K2, M)` y nonces o contadores.
- Incluir las identidades evita reflexión y confusión de contexto.
- **Pendientes.** Replay de mensajes, forward secrecy y negabilidad.
- Firmas de largo plazo dejan evidencia transferible y no dan FS por sí solas.

---

# Establecimiento de confianza: panorama

- Problema central: vincular la identidad "Alice" con la clave pública correcta.
- **Oportunista.** Claves en claro al inicio; sirve contra pasivos, falla ante un activo.
- **TOFU.** Fijar la clave en el primer uso, como `known_hosts` en SSH.
- **Fuera de banda.** Verificar en persona o por otro canal seguro.
- **Servidor central.** Cómodo, pero puede devolver la clave del atacante.
- **Key Transparency y Keybase.** Reducen esa confianza con verificabilidad.
- Cada opción mueve el costo entre seguridad y usabilidad.

---

# TOFU e intercambio fuera de banda

- TOFU asume que la primera conexión es honesta; el cliente "adhiere" la PK.
- Es conveniente y resiste pasivos y ataques nuevos.
- Es débil ante adversarios persistentes y ante cambios legítimos de clave.
- Un cambio legítimo aparece como advertencia: "¿usar nueva clave?".
- OOB es muy seguro si es presencial, pero poco práctico: casi nadie lo hace.
- Debe repetirse tras pérdida o renovación de dispositivos.
- **Usabilidad.** Si el sistema ultra seguro es impráctico, nadie lo usa.

---

# Servidor central de claves

- **Objetivo.** Mejorar la usabilidad evitando intercambios manuales.
- El servidor devuelve la clave pública del contacto bajo demanda.
- **Riesgo.** Un servidor deshonesto o comprometido entrega la PK de Eve.
- TLS protege el canal, pero no garantiza que la clave sea la correcta.
- Se necesitan controles: transparencia, pruebas sociales y pinning.
- La confianza se desplaza del usuario al operador del servicio.
- Es la base de iMessage, WhatsApp y muchos directorios corporativos.

---

# iMessage: registro, envío y amenazas

- El dispositivo genera el par de claves; solo él conoce `SK`.
- El usuario se autentica con iCloud y registra su PK en Apple (vía TLS).
- Al enviar, Alice pide `PK_Bob`, cifra y firma, y sube el mensaje.
- Apple no posee `SK`: no puede leer ni falsificar el contenido.
- Es conveniente y maneja bien dispositivos nuevos o perdidos.
- **Riesgo.** Ataques basados en la contraseña de la cuenta iCloud.
- **Riesgo.** Un servidor que devuelve la PK de Eve (MITM de directorio).

---

# Key Transparency

- **Meta.** Combinar un servidor de claves con verificabilidad pública.
- El servidor mantiene un log append-only de eventos de claves.
- "Bob añadió PK_x", "Bob quitó PK_z" quedan registrados.
- Los dueños revisan que su clave registrada sea la correcta.
- Los solicitantes verifican que la respuesta coincida con el log.
- Si el servidor devuelve `PK_Eve`, debe publicarla (Bob alerta) o Alice nota que no está.
- **Desafíos.** Eficiencia, privacidad y evitar bifurcaciones del log (equivocation).

---

# Keybase: verificación social

- Reduce la confianza en el servidor usando pruebas en servicios externos.
- Guarda `PK_Alice` y registros como `Sign(PK_Alice, "soy alice177 en Twitter")`.
- Bob descarga las pruebas (tweets, repos) y verifica que estén firmadas.
- El cliente pregunta: "¿es la Alice correcta?".
- **Ataque.** Comprometer las cuentas de prueba (Twitter, GitHub).
- **Pinning.** La clave se fija al primer uso; la rotación se firma con la anterior.
- Usabilidad aceptable salvo en configuración inicial y revocaciones.

---

# Secreto hacia adelante (forward secrecy)

- Evita descifrar grabaciones antiguas si se comprometen claves de largo plazo.
- Alice genera una clave temporal y envía `PK_temp`; Bob cifra con ella.
- Alice descifra y borra `SK_temp` de forma permanente.
- El atacante necesita `SK_temp`, que ya no está en dispositivos ni en la red.
- Requiere autenticar la clave temporal con TLS u otro canal.
- TLS moderno, WhatsApp y Signal usan variantes con ratchets.
- **Costo.** Más estado, sincronización y complejidad multi-dispositivo.

---

# Autenticidad negable

- **Objetivo dual.** Convencer al destinatario y poder negarlo ante terceros.
- No usar firmas públicas: dejan evidencia transferible.
- Preferir MAC simétricos, que el propio par podría haber generado.
- **SKEME simplificado.** Bob elige `K` y envía `E(PK_Alice, K)`.
- Alice descifra, envía `M` con `MAC(K, M)` y puede publicar `K` al finalizar.
- Cualquiera con `K` puede fabricar los mismos artefactos: hay negabilidad.
- OTR y Signal implementan versiones avanzadas de mensajería negable.

---

# Tensiones de la conversación

- Autenticidad vs negabilidad: no dejar pruebas transferibles.
- Confidencialidad vs moderación: ¿cómo denunciar abuso si el servidor no ve nada?
- **Message franking.** El servidor verifica un mensaje denunciado sin leer todos.
- Grupos: claves por grupo, altas y bajas, y consistencia de miembros.
- Adjuntos y metadatos también necesitan protección.
- Las decisiones definen qué puede hacer la plataforma y qué puede exigir un tribunal.
- Ningún protocolo maximiza todas las propiedades a la vez.

---

# Múltiples dispositivos

- Se quiere el mismo historial en teléfono, laptop y tablet.
- ¿Qué dispositivo guarda las claves de descifrado? ¿Y si está offline?
- Agregar dispositivos exige distribuir claves y actualizar la confianza.
- Sincronizar historial choca con forward secrecy: ¿guardar claves antiguas?
- Soluciones: claves por dispositivo, sesiones propias y respaldos cifrados.
- La recuperación de cuenta suele ser el eslabón más débil.
- **Trade-off.** Comodidad, disponibilidad y seguridad real.

---

# Metadatos y resumen

- **Metadatos.** Quién habla con quién, cuándo y con qué frecuencia.
- Un servidor central observa el tráfico cliente-servidor aunque haya TLS.
- **Tor/onion routing.** Capas de cifrado por varios relays; mejor que un servidor único.
- Adversarios globales aún correlacionan tiempos; mixnets y difusión son costosas.
- No hay solución barata: muchos sistemas minimizan, no eliminan.
- **Resumen.** Criptografía más arquitectura; ningún diseño cumple todos los objetivos.
- Cada decisión es un trade-off entre seguridad, privacidad y usabilidad.

---

# Pregunta 1

¿Qué gana y qué pierde el correo al usar seguridad hop-by-hop en vez de extremo a extremo?

**Respuesta:**
- Gana protección incremental y compatible: STARTTLS, DKIM, ARC y BIMI funcionan sobre la infraestructura existente.
- Pierde confidencialidad real: cada servidor ve el mensaje en claro y puede modificarlo.
- La autenticidad queda repartida entre muchos operadores y configuraciones.
- E2E lo resuelve en los extremos, pero exige gestionar claves y complica el uso.

---

# Pregunta 2

Compare TOFU, un servidor central de claves y Key Transparency frente a un servidor malicioso.

**Respuesta:**
- TOFU es cómodo y detecta cambios, pero el primer contacto puede ser el ataque.
- El servidor central es aún más cómodo, pero puede entregar directamente la clave del atacante.
- Key Transparency obliga a publicar los cambios en un log verificable: el engaño se detecta.
- Keybase añade pruebas sociales firmadas, aunque depende de cuentas externas.

---

# Pregunta 3

¿Cómo funciona el forward secrecy y qué problema no resuelve?

**Respuesta:**
- Se usa una clave temporal por sesión y se borra la privada tras descifrar.
- Si roban claves de largo plazo después, las grabaciones antiguas siguen protegidas.
- No evita que un dispositivo comprometido en el momento lea los mensajes actuales.
- Tampoco protege metadatos ni resuelve la autenticación de la clave temporal.

---

# Pregunta 4

¿Por qué la negabilidad y la denuncia de abuso están en tensión, y cómo se aborda?

**Respuesta:**
- Las firmas públicas prueban autoría ante cualquiera y eliminan la negabilidad.
- Los MAC simétricos permiten negar, pero el servidor no puede moderar contenido.
- Message franking permite verificar un mensaje denunciado sin leer toda la conversación.
- El equilibrio depende del contexto: privacidad, moderación y requisitos legales.
