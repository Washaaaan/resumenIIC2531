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

# Certificados y confianza en la web

### IIC2531 — Clase 15

Certificados X.509, autoridades certificadoras y las defensas que surgieron cuando la confianza falló.

---

# Punto de partida: HTTPS

- A mediados de los 90 el comercio en línea recién comenzaba.
- ¿La gente confiaría su tarjeta de crédito a Internet?
- `https://` le indica al navegador usar HTTP dentro de TLS.
- TLS da confidencialidad e integridad sobre una red hostil.
- Pero el cliente también necesita saber con quién está hablando.

---

# SSL sin certificado: falta autenticación

- Intercambio simplificado: el servidor envía su clave pública y el cliente cifra una clave de sesión.
- Un atacante que intercepta puede enviar su propia clave pública.
- El cliente cifra todo para el atacante, que relee el tráfico.
- El cifrado sirve poco si no se autentica al servidor.
- Se necesita distribuir claves de forma confiable.

---

# ¿Qué contiene un certificado?

- Sujeto: nombre DNS del servidor (p. ej. `amazon.com`).
- Clave pública del sujeto.
- Fecha de expiración (habitualmente uno o dos años).
- Identificador de la CA emisora.
- Firma de la CA sobre todos esos datos.
- El navegador lo muestra al hacer clic en el candado.
- En conjunto, vincula un nombre DNS con una clave pública y lo respalda una CA.

---

# Cómo frena a un atacante en la red

- El atacante puede desviar paquetes por WiFi/LAN o manipular DNS y rutas.
- Si muestra el certificado real, no posee la clave privada correspondiente: el handshake falla.
- Si usa un certificado para `attacker.com`, el navegador lo rechaza por nombre.
- Si presenta el certificado de Amazon junto con la clave de Amazon, no puede descifrar la sesión.
- No protege contra phishing, HTTP forzado ni una CA engañada.

---

# Emisión: el trabajo de la CA

- El sitio genera su par de claves y protege la privada.
- Envía la clave pública y una prueba de control del dominio a la CA.
- La CA valida la prueba y puede rechazar la solicitud.
- Si todo está bien, firma el certificado y lo devuelve.
- El sitio lo usa hasta que expire.

---

# Validación en el navegador

- El nombre del sujeto coincide con la URL.
- La CA es reconocida y su clave pública está instalada.
- La firma de la CA es válida.
- El certificado no ha expirado.
- No está revocado.
- El servidor demuestra poseer la clave privada.
- Si algo falla: error y página bloqueada; si todo pasa: candado.

---

# ¿Qué garantiza el candado?

- Que la CA cree que ese servidor controla el nombre DNS de la URL.
- No dice "esta página es segura" ni que el comercio sea honesto.
- Si la URL y el candado son correctos, es razonable ingresar credenciales.
- Con CDN y claves compartidas, el vínculo sitio-servidor se vuelve borroso.
- El beneficio depende de que el usuario revise URL y candado.

---

# El eslabón humano

- Muchos usuarios no saben cuándo exigir HTTPS ni miran el candado.
- Desconocen cuál es el nombre DNS esperado.
- Por eso funcionan dominios como `www.g00gle.com`.
- Sus preguntas ("¿este comercio es confiable?") no coinciden con lo que TLS garantiza.
- Los navegadores ahora bloquean más y muestran menos diálogos confusos.

---

# ¿Cómo conoce el navegador a las CAs?

- Necesita la clave pública de cada CA confiable.
- Existen docenas de CAs globales.
- El navegador o el sistema operativo trae una lista de certificados raíz.
- No se consulta a la CA en línea en cada conexión: sería lento, frágil y permitiría registrar la actividad del usuario.
- El servidor prueba su identidad sin depender de la CA en tiempo real.

---

# DV vs. EV

- **DV (Domain Validated):** la CA verifica solo el control técnico del dominio.
  - Nonce en un archivo o registro DNS; proceso automatizado y barato (Let's Encrypt).
- **EV (Extended Validation):** intenta certificar a la entidad legal, no solo el dominio.
  - Muestra el nombre de la empresa y un indicador especial.
- EV resultó caro y poco efectivo: los usuarios no distinguen el indicador.
- Hoy predominan los certificados DV.

---

# Límites de la validación DV

- Depende del DNS y del enrutamiento; un atacante local puede influir en ambos.
- Buenas CAs consultan desde varias ubicaciones para mitigar ataques locales.
- No existe prueba 100% fiable de identidad ni de propiedad.
- Si aparecen dos certificados válidos para el mismo nombre, se necesita detección.
- Validar el dominio no valida la honestidad del negocio.

---

# Cuando la confianza en CAs falla

- El navegador confía en docenas o cientos de CAs.
- Cualquier CA puede emitir para cualquier nombre: útil al cambiar de proveedor, peligroso si falla.
- Riesgos: CA descuidada y engañada, robo de su clave privada, empleados sobornados o coaccionados.
- Un certificado falso más intercepción de tráfico da un MitM con candado y sesión aparentemente legítima.
- El atacante reenvía credenciales y contenido al sitio real mientras lee todo.

---

# Incidentes y lecciones

- En 1996 estos riesgos parecían lejanos.
- En 2011 dos CAs emitieron certificados maliciosos, entre ellos para `google.com`.
- Algunos se usaron para interceptar tráfico de Gmail.
- Un certificado falso puede circular mucho antes de ser detectado.
- El modelo offline dificulta el descubrimiento salvo que se use masivamente.
- Estos incidentes impulsaron pinning, CT y mejores esquemas de revocación.

---

# Key pinning

- Detecta cambios inesperados de clave respecto de visitas previas.
- Chrome mantiene listas de CAs autorizadas para dominios sensibles.
- **TOFU:** el navegador recuerda la clave y alerta si cambia; ¿qué pasa si el cambio es legítimo?
- **HPKP:** el servidor declara hashes de claves vía cabecera HTTP.
  - Es potente pero peligroso: una configuración errónea puede dejar el sitio inaccesible.
- El pinning por sí solo no detecta una emisión fraudulenta antes del primer uso.

---

# Certificate Transparency (CT)

- Registro público y replicado de los certificados emitidos.
- Las CAs deben registrar cada certificado.
- Los navegadores rechazan certificados que no aparecen en el log.
- Los dueños monitorean los logs para detectar emisiones falsas.
- Una CA maliciosa deja rastros visibles.
- Es menos propenso a errores que HPKP; Chrome exige CT para la mayoría de certificados.

---

# Revocación: el punto débil

- Si roban la clave privada o el dominio cambia de dueño, el certificado viejo sigue pareciendo válido.
- La expiración tarda uno o dos años: no es una respuesta oportuna.
- **CRL:** la CA publica una lista firmada de certificados revocados.
  - Listas grandes, servidores poco fiables y el navegador suele aceptar si no puede consultar.
- **OCSP:** el cliente pregunta en línea por cada certificado.
  - Lento, poco fiable y filtra la privacidad del usuario.
- **OCSP stapling:** la respuesta firmada viaja en el handshake; los certificados modernos pueden exigirla con "must staple".

---

# Resumen y trade-offs

- Certificados y TLS reducen espionaje y manipulación, pero no prueban que un sitio sea honesto.
- La confianza es delegada: cualquier CA del almacén puede romper el modelo.
- DV es barato y automatizable; EV no resolvió la percepción del usuario.
- Pinning y CT detectan fallas, con costos de configuración y disponibilidad.
- La revocación sigue siendo difícil: CRL, OCSP y stapling son compromisos.
- Diseñar PKI es complejo porque no hay verdad absoluta sobre identidad.

---

# Pregunta de prueba 1

**¿Qué datos incluye un certificado y quién los firma?**

**Respuesta:**

- Nombre DNS del sujeto, su clave pública y fecha de expiración.
- Identificador de la CA emisora.
- La firma de la CA cubre el conjunto de datos.
- Esa firma permite verificar el vínculo entre nombre y clave.

---

# Pregunta de prueba 2

**¿Qué comprueba el navegador antes de mostrar el candado?**

**Respuesta:**

- Que el nombre coincida con la URL y la CA sea reconocida.
- Que la firma, la vigencia y la revocación sean correctas.
- Que el servidor demuestre poseer la clave privada.
- Si algo falla, bloquea la página en vez de mostrar el candado.

---

# Pregunta de prueba 3

**¿Qué garantiza y qué no garantiza el candado?**

**Respuesta:**

- Garantiza que la CA asocia ese nombre DNS con esa clave.
- No garantiza que el sitio sea honesto ni que la página sea "segura".
- No protege contra phishing, HTTP forzado o una CA engañada.
- Su valor depende de que el usuario revise la URL.

---

# Pregunta de prueba 4

**¿Por qué Certificate Transparency es más robusto que HPKP y qué problema persiste?**

**Respuesta:**

- CT publica todos los certificados en logs replicados y auditables.
- Una CA maliciosa no puede emitir sin dejar un rastro visible.
- HPKP depende de configuración del servidor y puede romper el sitio.
- Persiste la revocación: detectar no equivale a invalidar de inmediato.
