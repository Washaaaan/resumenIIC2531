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

# Seguridad Web

### IIC2531 — Clase 18

OWASP Top 10 2021: las vulnerabilidades más comunes
y cómo prevenirlas.

---

# OWASP Top 10 2021

- **OWASP**: Open Web Application Security Project, comunidad abierta.
- Es un documento de concientización y priorización, no un estándar certificable.
- Se construye con datos de incidentes y se apoya en las CWE (*Common Weakness Enumeration*).
- La versión 2021 incorpora diseño inseguro, integridad de software/datos y SSRF.
- Sirve para ordenar esfuerzos, no para reemplazar el modelado de amenazas.
- Las categorías se solapan: un mismo fallo puede habilitar varios ataques.

---

# A01 — Control de acceso roto

- **Definición.** Los controles se aplican de forma inconsistente y se permite acceder a recursos o acciones fuera del rol del usuario.
- **Ejemplo.** Cambiar `?acct=notmyacct` en la URL y ver la cuenta ajena (IDOR); llamar a `admin_getappInfo` sin ser admin.
- **Ejemplo.** API que acepta POST, PUT y DELETE sin verificar autorización.
- **Prevención.** Denegar por defecto, salvo recursos explícitamente públicos.
- **Prevención.** Centralizar el control de acceso en un mecanismo reutilizable.
- Verificar la propiedad del registro en el modelo, no confiar en el cliente.
- Registrar los fallos y limitar la tasa de peticiones.

---

# A02 — Fallos criptográficos

- **Definición.** Datos sensibles protegidos con criptografía débil, mal usada o directamente ausente.
- **Ejemplo.** Cifrado automático de base de datos que descifra al leer: una inyección SQL obtiene tarjetas en claro.
- **Ejemplo.** Contraseñas con hashes sin sal o funciones rápidas: tablas arcoíris o GPU las revierten.
- **Prevención.** Clasificar los datos y no almacenar lo que no se necesita.
- Cifrar en reposo y en tránsito; TLS actualizado, sin FTP ni SMTP heredados.
- Contraseñas con Argon2, scrypt, bcrypt o PBKDF2 (sal + factor de trabajo).
- Gestión y rotación de claves; nunca claves en repositorios.

---

# A03 — Inyección

- **Definición.** Datos no confiables llegan a un intérprete (SQL, shell, LDAP, ORM) y se ejecutan como código.
- **Causa.** Concatenar strings y usar consultas dinámicas sin escape consciente del contexto.
- **Ejemplo.** `"... WHERE custID='" + id + "'"` con `id = ' UNION SELECT SLEEP(10);--`.
- **Impacto.** Leer o alterar datos, saltarse la autenticación, ejecutar comandos.
- **Prevención.** Consultas parametrizadas u ORM: evitan el intérprete por completo.
- Validación positiva del lado del servidor como defensa complementaria, no única.
- Escape específico del intérprete solo en consultas dinámicas residuales.

---

# A04 — Diseño inseguro

- **Definición.** Faltan controles de diseño ("diseño de control faltante o ineficaz"); el sistema no modela el abuso.
- **Distinción.** Diseño inseguro ≠ implementación insegura: causas raíz y remedios distintos.
- Un buen diseño puede tener bugs; un buen código no arregla un mal diseño.
- **Ejemplo.** Descuento grupal hasta 15 asistentes: el atacante reserva 600 butacas en pocas peticiones.
- **Ejemplo.** E-commerce sin defensa contra bots que agotan el stock para revender.
- **Prevención.** Negociar requisitos de negocio y de seguridad (CIA + autenticidad).
- Modelado de amenazas continuo, patrones y bibliotecas seguras (secure SDLC).

---

# A05 — Configuración insegura

- **Definición.** Endurecimiento incompleto o permisos mal configurados en cualquier capa de la pila.
- **Síntomas.** Puertos, servicios y cuentas innecesarias; credenciales por defecto sin cambiar.
- Errores verbosos (stack traces) y listado de directorios habilitado.
- **Ejemplo.** Consola de administración de ejemplo con `admin/admin` en producción.
- **Ejemplo.** Clases Java descargables por listado de directorios: se decompilan y revelan fallos.
- **Prevención.** Plataforma mínima; eliminar componentes, ejemplos y documentación no usados.
- Configuración automatizada e idéntica en dev/QA/prod, con credenciales distintas; segmentar la red.

---

# A06 — Componentes vulnerables y desactualizados

- **Definición.** Se usan componentes con vulnerabilidades conocidas, sin soporte o desactualizados.
- Incluye SO, servidor web, framework, DBMS y dependencias transitivas.
- **Riesgo.** El componente corre con los privilegios de la app: un fallo escala rápido.
- **Ejemplo.** CVE-2017-5638 en Struts 2: ejecución remota de código.
- **Ejemplo.** Shodan encuentra dispositivos aún vulnerables a Heartbleed.
- **Prevención.** Inventario continuo (Dependency-Check, retire.js) y SBOM.
- Gestión de parches basada en riesgo; descargar de fuentes oficiales y firmadas.

---

# A07 — Fallos de identificación y autenticación

- **Definición.** Debilidades en identificación, autenticación o gestión de sesión.
- Permite *credential stuffing*, fuerza bruta y contraseñas por defecto (`admin/admin`).
- Recuperación débil ("preguntas de conocimiento") y MFA ausente o ineficaz.
- **Ejemplo.** Sesión que sigue válida tras cerrar la pestaña en un computador público.
- **Prevención.** MFA, sin credenciales por defecto, chequeo contra las peores contraseñas.
- Mensajes uniformes para evitar enumeración de cuentas; limitar intentos sin crear DoS.
- Sesión del lado del servidor: ID aleatorio, fuera de la URL, invalidado al salir o expirar.

---

# A08 — Fallos de integridad de software y datos

- **Definición.** Código, datos o pipeline sin protección frente a violaciones de integridad.
- **Vectores.** Dependencias de fuentes no confiables, CI/CD inseguro, auto-update sin firma.
- **Ejemplo.** Firmware de routers que no verifica actualizaciones firmadas.
- **Ejemplo.** SolarWinds: actualización maliciosa distribuida a ~18.000 organizaciones.
- **Ejemplo.** Deserialización Java (firma `rO0`) que termina en ejecución remota de código.
- **Prevención.** Firmas digitales, repositorios internos verificados y revisión de cambios.
- Asegurar la cadena de suministro y no enviar datos serializados sin firma o MAC.

---

# A09 — Fallos de logs y monitoreo de seguridad

- **Definición.** Ausencia de registro, detección, alerta y respuesta ante eventos de seguridad.
- No se registran logins, fallos ni transacciones de alto valor; logs solo locales.
- Sin monitoreo no hay detección: una brecha puede pasar años inadvertida.
- **Ejemplo.** Proveedor de salud con 3,5 millones de niños afectados y sin logs desde 2013.
- **Prevención.** Registrar con contexto de usuario y retención suficiente para forense.
- Formato consumible y datos codificados para evitar inyección en los logs.
- Trazabilidad íntegra de transacciones de alto valor y plan de respuesta a incidentes.

---

# A10 — Server-Side Request Forgery (SSRF)

- **Definición.** La aplicación obtiene un recurso remoto usando una URL controlada por el usuario.
- El atacante apunta a servicios internos, `localhost` o metadatos de la nube.
- **Ejemplo.** `?url=http://169.254.169.254/latest/meta-data/...` filtra credenciales de instancia.
- Permite escanear la red interna y saltarse el firewall perimetral.
- **Prevención.** Allowlist de destinos y esquemas; no seguir redirecciones a ciegas.
- Segmentar la red y exigir autenticación a los servicios internos.
- Validar y normalizar la URL; bloquear IP privadas y endpoints de metadatos.

---

# Patrones transversales

- Denegar por defecto y verificar siempre en el servidor, nunca en el cliente.
- Parametrizar en vez de concatenar; escapar según el contexto de salida.
- Mínimo privilegio y separación de componentes y de red.
- Inventario y parcheo continuos; integridad verificable mediante firmas.
- Observabilidad: logs, alertas y trazas de auditoría con retención.
- Diseño y modelado de amenazas antes de escribir código.

---

# Priorizar y aceptar trade-offs

- No todas las categorías pesan igual: depende del activo y del modelo de amenaza.
- Primero los controles baratos y transversales: deny by default, parametrización, parches.
- Seguridad vs usabilidad: MFA y verificación de claves agregan fricción.
- Complejidad vs mantenibilidad: cifrar mal puede ser peor que no cifrar.
- Medir cobertura de parches, tiempo de detección y tasa de revisiones.
- El Top 10 prioriza; el riesgo real se estima con contexto.

---

# Los "almost"

- **Calidad de código.** Bugs, condiciones de carrera y lógica incorrecta que habilitan otras categorías.
- **DDoS.** Afecta la disponibilidad; se mitiga con arquitectura, rate limiting y proveedores.
- **Manejo de memoria.** En lenguajes nativos lleva a corrupción y RCE (ver Clase 08).
- Quedan fuera del Top 10 por ser heterogéneos, no por ser menos importantes.
- Complementan el Top 10, no lo reemplazan.

---

# Pregunta 1

¿Por qué el control de acceso roto (A01) es la categoría más crítica y cómo se previene?

**Respuesta:**
- Porque cualquier usuario autenticado puede actuar fuera de su rol y acceder a datos ajenos cambiando un parámetro.
- El fallo está en la verificación, no en la criptografía: no sirve cifrar si igual se autoriza mal.
- Se previene con deny by default y un control centralizado y reutilizable.
- Además se valida la propiedad del registro en el modelo y se registran los fallos.

---

# Pregunta 2

Compare inyección (A03) y fallo criptográfico (A02): causa raíz y prevención.

**Respuesta:**
- A03 es un problema de confusión de datos y código: el input del usuario se interpreta como instrucción.
- Su prevención estructural son las consultas parametrizadas u ORM, no el escape manual.
- A02 es un problema de protección de datos: algoritmo débil, mala gestión de claves o texto plano.
- Se previene clasificando datos, cifrando en reposo/tránsito y usando hashes lentos con sal.

---

# Pregunta 3

Un equipo usa una dependencia con CVE conocido y su pipeline descarga paquetes sin verificar firma. ¿Qué categorías aplican y qué haría primero?

**Respuesta:**
- A06 por el componente vulnerable y desactualizado sin gestión de parches.
- A08 por la cadena de suministro sin verificación de integridad.
- Primero inventariar dependencias y parchear según riesgo; luego fijar versiones y firmas.
- A mediano plazo: SBOM, repositorio interno confiable y revisión de cambios en CI/CD.

---

# Pregunta 4

¿Por qué el OWASP Top 10 no basta como programa de seguridad?

**Respuesta:**
- Es una lista de concientización basada en datos agregados, no un catálogo exhaustivo ni certificable.
- No cubre calidad de código, DDoS ni manejo de memoria, y las categorías se solapan.
- No conoce el contexto: activos, modelo de amenaza y requisitos regulatorios de cada sistema.
- Se complementa con modelado de amenazas, secure SDLC, pruebas y monitoreo continuo.
