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

  .terminal-commands {
    text-align: right;
    margin-left: 400px;
  }

  ul ul li, ol ol li {
    color: #666666;
    font-size: 0.9em;
  }

  ul ul ul li, ol ol ol li {
    color: #666666;
    font-style: italic;
    font-size: 0.8em;
  }

  ul ul, ol ol {
    opacity: 0.8;
  }

---

# Seguridad de la cadena de suministro

### IIC2531 — Clase 22

Open source, dependencias y ataques modernos:
de XZ a GitHub Actions y los gusanos de paquetes.

---

# ¿Qué es un ataque de cadena de suministro?

- Alteración maliciosa de software confiable **antes de la entrega**.
- La víctima recibe algo que parece legítimo.
- La confianza en el canal se convierte en vector.
- Ejemplos: hardware manipulado (Crypto AG), Xcode falsificado (XcodeGhost).
- Estándares débiles (Juniper/Dual EC), updates firmados con malware (SolarWinds).
- No es un ataque directo a tu máquina: compromete a tu proveedor.

---

# La cadena es un grafo

- Código fuente, dependencias, herramientas de build.
- Repositorios, registries, CI/CD, binarios y contenedores.
- Cada nodo es una posible entrada.
- Un proyecto usa miles de paquetes: `kubernetes` ronda los 3000.
- La cadena cambia con cada versión.
- Cada borde del grafo implica confianza.

---

# Vulnerabilidad vs. ataque

- **Vulnerabilidad:** debilidad explotable en una dependencia.
- **Ataque:** alguien la explota o introduce código malicioso.
- La seguridad de cadena cubre ambos casos.
- Open source ataque: alterar un componente confiable usado por un programa confiable.
- Open source vulnerabilidad: falla explotable en un paquete confiable.
- La distinción evita confundir bugs accidentales con campañas.

---

# Caso: event-stream

- Librería npm ampliamente usada.
- El maintainer original estaba cansado y cedió el paquete.
- El nuevo dueño agregó `flatmap-stream` con código malicioso.
- Robaba criptomonedas desde una aplicación específica (Copay).
- Pasó **dos meses** sin ser detectado.
- Lección: la confianza en maintainers y dependencias transitivas es frágil.

---

# Vulnerabilidades en open source

- **NSO / FORCEDENTRY:** un GIF que era PDF, con imagen JBIG2.
- El decodificador JBIG2 de Xpdf (open source, C) no validaba tablas.
- Eso habilitó una CPU virtual y la toma del iPhone sin clicks.
- **Log4j / Minecraft:** un mensaje de chat disparaba descarga y ejecución.
- El bug estaba en Log4j, no en Minecraft.
- Lección: software cerrado hereda fallas de componentes open source.

---

# Tres tareas y reducir vulnerabilidades

- **Entender** la cadena: dependencias, builds, credenciales, máquinas.
- **Fortalecerla** contra ataques.
- **Monitorearla** para encontrar vulnerabilidades.
- Evitar C/C++ en código crítico: undefined behavior, use-after-free, OOB.
- Usar lenguajes seguros en memoria (Go, Rust).
- Fuzzing continuo (OSS-Fuzz, syzkaller) y revisión de dependencias.
- Actualizar con criterio y seguir CVEs.

---

# Firmas, checksums y builds reproducibles

- Las firmas verifican que el artefacto no cambió.
- Los checksums inmutables eliminan mirrors y proxies como punto de ataque.
- Problema pendiente: ¿qué llave o checksum confiamos?
- **Builds reproducibles:** mismo código y herramientas → mismo binario bit a bit.
- Permiten que terceros reconstruyan y comparen.
- La checksum database de Go fija el significado de cada versión.
- Modelo trust-on-first-use para versiones públicas.

---

# Control de cambios y monitoreo

- Nadie debería tener poder unilateral: autor + reviewer.
- Acceso privilegiado solo desde dispositivos confiables.
- Builds y producción con autorización fuerte.
- Inventario de dependencias y versiones.
- Alertas ante CVEs o ataques.
- Capacidad de rotar secretos y reconstruir.
- Sin inventario, la respuesta es lenta y artesanal.

---

# Ataques básicos

- **Cuenta de maintainer comprometida:** publican como alguien confiable.
- **Versión maliciosa:** una release legítima incluye código del atacante.
- **Typosquatting:** `request` en vez de `requests`.
- **Dependencias transitivas:** la librería que nadie revisa.
- **Tags reescritos:** un nombre de versión apunta después a otro código.
- **Phishing npm:** correo casi legítimo, dominio casi correcto, credenciales robadas.
- La economía favorece al atacante: poco esfuerzo, impacto masivo.

---

# Ataques sofisticados

- **Compiler backdoor:** el fuente está limpio; el binario del compilador inserta la trampa.
- Recompilar el compilador vuelve a infectarlo.
- Los builds reproducibles permiten detectarlo.
- **Domain name resurrection:** un dominio expira y el atacante lo compra.
- Viejas referencias vuelven a resolver como proveedor "confiable".
- GitHub también lo permitía, con limitaciones recientes.
- La confianza queda pegada a nombres que ya no controla el original.

---

# XZ: el ataque paciente (confianza)

- Objetivo final: OpenSSH, vía `sshd → systemd → liblzma → xz`.
- Lasse Collin mantenía xz como hobby desde 2005.
- Oct. 2021: Jia Tan envía un patch inocuo.
- 2022: más parches útiles y cuentas falsas presionan al maintainer.
- Jun. 2022: Jia Tan parece casi co-maintainer.
- Nov. 2022: el README y el email lo reconocen oficialmente.
- Primero se comprometió el proceso humano, no el código.

---

# XZ: la puerta trasera

- Feb. 2024: archivos de prueba "corruptos" que reconstruyen scripts.
- 5.6.0: el payload aparece en los **tarballs de release**, no en el repo.
- Objetivo técnico: interceptar RSA en `sshd`.
- Mar. 4 2024: Red Hat ve fallas bajo Valgrind.
- Mar. 9 2024: 5.6.1 actualiza la backdoor.
- El payload estaba repartido entre tests, scripts y artefactos.
- "Revisar el diff" no bastaba.

---

# XZ: descubrimiento y lecciones

- Mar. 27: Debian acepta 5.6.1 tras presión de sock puppets.
- Mar. 28: Ubuntu ya no lo toma desde Debian.
- Mar. 29: Andres Freund publica el hallazgo.
- Señal clave: `ssh` consumía más CPU de lo esperado.
- Lo humano es parte del sistema: maintainers críticos necesitan apoyo.
- Los tarballs no deben diferir del repo; las releases deben ser reproducibles.
- La ventana se cerraba: systemd removía la dependencia de liblzma.

---

# GitHub Actions como cadena de suministro

- El CI ejecuta código en runners con tokens y secretos.
- Puede publicar paquetes, comentar, firmar y desplegar.
- Comprometer un workflow equivale a comprometer el proyecto.
- `pull_request`: código no confiable, sin secretos.
- `pull_request_target`: permisos del repo; peligroso si ejecuta código del PR.
- Patrón de falla: checkout del PR → script con secretos → token exfiltrado.
- El nombre del trigger no comunica el riesgo.

---

# Inyección en workflows y caso NX

```yaml
run: echo "${{ github.event.pull_request.title }}"
```

- Sustitución de texto: el shell interpreta caracteres especiales.
- El título del PR puede ejecutar código.
- La documentación no es defensa suficiente.
- **NX:** workflow inseguro para validar títulos.
- La vulnerabilidad quedó en ramas viejas aunque se revirtió en main.
- El atacante robó tokens de GitHub y npm y publicó versiones maliciosas.

---

# Gusanos y ataques a defensas

- **Supply chain worm:** el paquete roba credenciales.
- Usa esas credenciales para publicar más paquetes.
- Se propaga por los permisos de los maintainers.
- Intenta persistir en runners de GitHub y exfiltrar repos privados.
- Ataca también scanners y herramientas de seguridad (Trivy, Checkmarx).
- Mayor impacto porque corren con privilegios.
- La defensa se vuelve vector.

---

# Decisiones de producto y qué exigir

- `pull_request_target` es una trampa: los exploits se llaman **pwn requests**.
- npm instala "lo último" por defecto y amplifica el daño.
- Tags mutables rompen el significado de una versión.
- Tokens de un factor contradicen el 2FA.
- Exigir: versiones inmutables, passkeys, tokens cortos y limitados.
- Workflows seguros por defecto y secretos fuera del código no confiable.
- Para un equipo: inventariar, pinnear, auditar Actions, rotar secretos, separar build/release/deploy.

---

# Pregunta de prueba 1

**¿Qué distingue un ataque de cadena de suministro de un ataque directo?**

**Respuesta:**

- El ataque ocurre **antes de la entrega**, en el proveedor o el canal.
- La víctima recibe e instala algo que parece legítimo.
- No se compromete primero la máquina de la víctima.
- Se explota la confianza en repositorios, builds o registries.

---

# Pregunta de prueba 2

**¿Por qué las firmas y los builds reproducibles no resuelven todo por sí solos?**

**Respuesta:**

- Una firma prueba integridad, no que el software sea bueno.
- Queda el problema de qué llave o checksum se confía.
- Los builds reproducibles detectan alteraciones, pero requieren herramientas independientes.
- Si el compilador está comprometido, ambos builds pueden coincidir.

---

# Pregunta de prueba 3

**Explica el error central de `pull_request_target` y cómo se explota.**

**Respuesta:**

- Corre con permisos del repositorio y acceso a secretos.
- Si además hace checkout del código del PR, ejecuta código no confiable.
- Ese código puede leer y exfiltrar tokens.
- Con los tokens robados, el atacante publica versiones maliciosas.

---

# Pregunta de prueba 4

**¿Qué lecciones deja XZ sobre la cadena de suministro humana?**

**Respuesta:**

- El ataque empezó ganando confianza durante dos años, no con malware.
- Un maintainer agotado es infraestructura crítica sin financiamiento.
- Los tarballs de release deben coincidir con el repositorio.
- Las releases reproducibles y la observabilidad permiten detectar anomalías.
