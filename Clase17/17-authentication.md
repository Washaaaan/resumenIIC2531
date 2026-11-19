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
    position: absolute;
    margin-top:0px
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

# Autenticación de usuarios

### IIC2531 — Clase 17

Contraseñas, almacenamiento seguro, factores adicionales y por qué el phishing lo cambia todo.

---

# Identificar, autenticar, autorizar

- **Identificación:** declarar quién se dice ser (nombre de usuario).
- **Autenticación:** probar esa identidad con un secreto o factor.
- **Autorización:** decidir qué puede hacer ese principal.
- El guardia verifica cada solicitud: registro, verificación y recuperación.
- Mediación completa: aislamiento del servidor y guardia en todas las solicitudes.
- Pregunta central: ¿qué principal originó esta solicitud?

---

# Principales intermedios e identidad

- El usuario casi nunca emite la solicitud directamente: cliente, balanceador, servidor de aplicaciones.
- Esos intermediarios "hablan por" el usuario y deben tratarse como principales.
- Si el dispositivo está comprometido, malware o keyloggers roban el secreto.
- Un atacante en el medio puede grabar la contraseña y reutilizarla después.
- Normalmente no se verifica la identidad real: se establece que quien inicia sesión posee el secreto del registro.
- Para muchos servicios (Amazon) eso basta; para otros, no.

---

# Registro y recuperación

- Registro: primero en llegar; arranque desde otro mecanismo (correo); creado por un administrador.
- Recuperación: preguntas de seguridad, verificación por correo, datos de pago, cuenta nueva, soporte, 2FA.
- Las preguntas de seguridad suelen tener respuestas adivinables o investigables.
- El soporte humano es un canal frecuente de ingeniería social.
- La recuperación puede ser más débil que el login y anular sus garantías.
- Conviene diseñarla con el mismo rigor que la autenticación.

---

# Contraseñas: el secreto compartido

- Usuario y guardia comparten un conjunto secreto de bits.
- Ventajas: fácil de usar, fácil de implementar, no requiere hardware.
- Desventajas: son valiosas y el factor humano produce secretos débiles y reutilizados.
- Defensa: usarlas lo mínimo; tras autenticar, usar cookies o claves de sesión.
- Acorralar el secreto con gestores, SSO, 2FA y biometría.
- Limitar intentos es parte del diseño, no un extra.

---

# Entropía, no "complejidad"

- 20% de las cuentas usan alguna de las 5.000 contraseñas más comunes.
- No se puede permitir probar 5.000 veces por usuario ni probar "123456" contra todos.
- Reglas de mayúsculas y dígitos no garantizan fuerza: `1Password!` es predecible.
- Lo que importa es la entropía: cuán común es la contraseña.
- 16 bits de entropía implican hasta 2^16 intentos.
- Los requisitos de caracteres explotan el sesgo de lo que parece "raro", no la aleatoriedad real.

---

# Rotación, reutilización y gestores

- Cambiar contraseñas con frecuencia inutiliza un secreto filtrado, pero cansa y fomenta anotarlas o elegir peores.
- No hay política de rotación claramente ganadora; depende de la amenaza.
- Reutilizar es peligroso: una filtración compromete varias cuentas.
- Un gestor genera contraseñas de alta entropía y distintas por sitio.
- El usuario solo recuerda una contraseña maestra fuerte.
- El gestor debe ser confiable: se convierte en un objetivo de alto valor.

---

# Adivinación y límites de tasa

- El espacio de claves es pequeño frente a la información disponible: filtraciones, frases populares, sesgos humanos.
- Datos cifrados con contraseña son vulnerables a adivinación offline: no hay servidor que limite.
- Limitar intentos por usuario no basta: el atacante prueba la misma contraseña contra muchos usuarios.
- Se necesitan timeouts, heurísticas y límites por IP o dispositivo.
- Los CAPTCHA ayudan poco: resolverlos tiene bajo costo económico.
- La defensa debe cubrir el login en línea y los hashes filtrados.

---

# Almacenamiento: hashing

- Plan ingenuo: guardar `(usuario, contraseña)`; un compromiso del servidor revela todas.
- Obliga a resetear todas las cuentas y permite probar esas contraseñas en otros servicios.
- Alternativa: guardar `(usuario, H(contraseña))`.
- Para verificar, se hashea lo ingresado y se compara.
- El hash criptográfico es unidireccional: no se puede invertir.
- Pero un hash rápido aún permite probar diccionarios offline.

---

# Salting

- Las rainbow tables precomputan hashes de contraseñas comunes.
- Se guarda `(usuario, salt, H(salt || contraseña))`.
- El salt se conoce; no es secreto, solo único.
- La misma contraseña produce hashes distintos en cada cuenta.
- Un salt grande encarece precomputar todas las combinaciones.
- El salt no sustituye a una función lenta ni a una contraseña fuerte.

---

# Hashing costoso (KDF)

- Los hashes criptográficos comunes están diseñados para ser rápidos.
- Contra una lista filtrada, el atacante no tiene límite de tasa.
- Se usa una función de derivación de claves intencionalmente costosa.
- Ejemplos: bcrypt, scrypt, PBKDF2, Argon2.
- El costo se ajusta para que un login sea tolerable y millones de intentos sean caros.
- No elimina el riesgo: solo lo hace económicamente inviable por más tiempo.

---

# 2FA: qué aporta y qué no

- Ayuda contra contraseñas débiles y reutilizadas.
- Un secreto robado no basta: se requiere el segundo factor.
- Puede ayudar contra MITM y phishing, según el tipo de factor.
- No arregla un cliente comprometido ni una recuperación débil.
- Los factores difieren en comodidad, costo, dependencia de terceros y resistencia al phishing.
- Más factores no siempre significan mejor seguridad si aumentan la fricción.

---

# 2FA por SMS

- El servidor guarda el número y envía un código temporal.
- Ventajas: fácil de adoptar, recuperación simple, portabilidad y externalización al operador.
- Desventajas: depende de la red celular y del proveedor; requiere cobertura.
- Es vulnerable a SIM swapping, intercepción y phishing en tiempo real.
- El código puede reenviarse a un atacante que lo espere.
- Mejor que nada, pero no es el estándar fuerte.

---

# TOTP

- Servidor y dispositivo acuerdan un secreto al registrar (p. ej. código QR).
- El dispositivo calcula `H(secreto || tiempo actual)`.
- El servidor verifica el código para la ventana de tiempo.
- Ventajas: no depende de la red celular ni del operador.
- Desventajas: instalar y configurar una app; migrar de dispositivo requiere recargar el secreto.
- Sigue siendo vulnerable a phishing en tiempo real.

---

# U2F: desafío-respuesta

- El dongle tiene un par de claves pública/privada; el servidor guarda la pública.
- El servidor envía un desafío aleatorio (nonce) al navegador.
- El navegador lo pasa al dongle junto con la identidad del servidor.
- El dongle firma `(desafío, identidad)` con su clave privada.
- El servidor verifica la firma contra la clave pública.
- El navegador nunca ve la clave privada: ni un navegador comprometido puede robarla.

---

# U2F: replay y phishing

- Un replay falla: el atacante graba una firma vieja, pero el servidor envía un nonce nuevo y `Verify` no cuadra.
- En el protocolo simplificado, `bad.com` podía reenviar el desafío del banco y obtener una firma válida.
- La defensa es firmar `CD = (desafío, origen)`, con origen = hash de protocolo, host y puerto.
- El navegador en `bad.com` produce otro origen, así que la firma no sirve en el banco.
- Esto vincula criptográficamente la respuesta al sitio correcto.

---

# U2F: privacidad y otros ataques

- Sin protección, los servidores podrían comparar claves públicas y vincular usuarios entre sitios.
- U2F registra una clave nueva por sitio; la privada se guarda cifrada con una `Kwrap` del dispositivo.
- El "handle" es esa clave cifrada; al autenticar se descifra y se verifica el origen.
- Cliente comprometido: puede robar la cookie post-login o engañar para firmar en otro sitio.
- Robo del dispositivo: aún se necesita la contraseña si es fuerte.
- Dispositivo malicioso: la atestación puede detectarlo y bloquear el registro.

---

# Resumen

- Autenticación es difícil porque combina tecnología, usuarios y operaciones.
- Las contraseñas persisten por su comodidad y facilidad de implementación.
- Entropía, límites de intentos y gestores atacan el problema humano.
- Hashing, salt y KDF protegen las contraseñas almacenadas, no las débiles.
- 2FA agrega un factor; SMS y TOTP son útiles pero phishables.
- U2F resiste phishing y replay vinculando la firma al origen.
- Ningún factor elimina el riesgo del cliente comprometido o la recuperación débil.

---

# Pregunta de prueba 1

**¿Cuál es la diferencia entre identificación, autenticación y autorización?**

**Respuesta:**

- Identificación es declarar una identidad, como un nombre de usuario.
- Autenticación es demostrar que se posee el secreto o factor asociado.
- Autorización decide qué acciones permite esa identidad ya autenticada.
- El guardia debe mediar todas las solicitudes para que el orden se respete.

---

# Pregunta de prueba 2

**¿Por qué almacenar `H(contraseña)` no basta y qué agregan el salt y una KDF?**

**Respuesta:**

- Un hash rápido permite probar diccionarios y rainbow tables offline.
- El salt único evita hashes precomputados y que dos cuentas coincidan.
- La KDF encarece cada intento y frena el cracking masivo.
- Aun así, una contraseña muy común sigue siendo adivinable.

---

# Pregunta de prueba 3

**Compara SMS, TOTP y U2F en dependencia externa y resistencia al phishing.**

**Respuesta:**

- SMS depende del operador y es vulnerable a SIM swapping y phishing.
- TOTP no depende de la red celular, pero un código puede reenviarse en tiempo real.
- U2F no depende de un tercero y firma el origen del sitio.
- Por eso U2F resiste phishing; SMS y TOTP no por sí solos.

---

# Pregunta de prueba 4

**¿Cómo evita U2F los ataques de replay y de phishing?**

**Respuesta:**

- El servidor envía un nonce nuevo en cada intento, así que una firma vieja no sirve.
- El dispositivo firma el desafío junto con el origen del servidor.
- En un sitio falso el origen cambia y la firma no valida en el sitio real.
- La clave privada nunca sale del dispositivo, incluso si el navegador está comprometido.
