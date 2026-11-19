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

# RLBox: sandboxing de bibliotecas

### IIC2531 — Clase 09

Qué pasa cuando el código aislado está comprometido:
la frontera de confianza y su interfaz.

---

# Idea central

- Aislar un componente **no basta**: hay que controlar todo lo que cruza la frontera.
- RLBox es un caso de estudio sobre interfaces entre código confiable y no confiable.
- Los principios aplican a sandboxes, procesos, RPCs y cualquier límite de confianza.
- La meta no es memorizar una API, sino reconocer **errores recurrentes de diseño**.

---

# Objetivo: sandboxear bibliotecas

- Bibliotecas grandes (códecs, fuentes, descompresores) tienen errores de seguridad.
- Un fallo en la biblioteca no debe convertirse en compromiso de la aplicación.
- Podemos perder calidad o funcionalidad, pero no el control del host.
- Necesitamos **aislamiento + intercambio controlado** de datos.
- RLBox = aislamiento (Wasm, NaCl, procesos) + mecanismos de interfaz.

---

# Escenario conductor: un JPEG malicioso

- Alicia abre en Firefox una imagen `foto.jpg` controlada por el atacante.
- El decoder JPEG tiene un bug de corrupción de memoria y es explotado.
- Supuesto: **todo el código del decoder está comprometido**.
- La biblioteca devuelve dimensiones, offsets, punteros o callbacks maliciosos.
- Pregunta: ¿cómo evitamos que el compromiso cruce la interfaz?

---

# Modelo de amenaza del escenario

- **Objetivo:** un decoder comprometido no debe leer, modificar ni controlar el navegador.
- **Adversario:** controla el archivo, ejecuta código arbitrario en el decoder y elige toda respuesta.
- **Supuestos:** el código fuera del decoder es correcto; el decoder solo accede a datos compartidos.
- **Fuera de alcance:** DoS por cuelgues y errores en el resto del navegador.
- La frontera debe sobrevivir incluso si la biblioteca miente siempre.

---

# De aislar un proceso a aislar cada biblioteca

- Aislar todo el multimedia en un proceso reduce daño, pero comparte dominio de confianza.
- Un códec comprometido podría manipular `gzip` y producir JavaScript malicioso.
- Mejor frontera: **una biblioteca por sandbox**, según mínimo privilegio.
- El paper agrupa por `<renderer, biblioteca, origen, tipo de contenido>` para amortizar costos.
- Cada sandbox cuesta ~1–2 ms; conviene reutilizar, no crear uno por operación.

---

# La interfaz es el verdadero desafío

- La interfaz aplicación–biblioteca se diseñó para código **confiable**.
- Al aislar, la aplicación debe revisar qué entrega y validar qué recibe.
- Aislar el decoder no sirve si el renderer cree en sus respuestas.
- Los contratos antiguos ya no describen la realidad de seguridad.
- Hay que hacer explícitos los cruces peligrosos.

---

# Antes y después: el mismo error

- **Antes:** `jpeg_decode(...)` llena `info`; se usa `width * height` directamente.
- **Después (mal):** se ejecuta en sandbox, pero se copian y usan las respuestas sin validar.
- El aislamiento impide acceso directo, pero la interfaz devuelve capacidad al atacante.
- Un status, tamaño, offset o puntero malicioso corrompe **el host**.
- Moraleja: el sandbox no reemplaza la validación.

---

# Errores: datos sin sanitizar y punteros

- La biblioteca pide saltar N bytes; N puede exceder el buffer y causar acceso fuera de límites.
- Status o flags inesperados rompen suposiciones del código llamador.
- Los punteros de una memoria no significan nada en otra: hay que copiar explícitamente.
- Un puntero basura corrompe memoria; uno válido filtrado debilita ASLR.
- Pasar punteros entre dominios sin conversión explícita es un error de diseño.

---

# Errores: doble-fetch

- La aplicación lee dos veces el mismo dato compartido.
- Ejemplo: valida `width = 800` y luego copia píxeles; el decoder cambió el valor a `0xffffffff`.
- Entre verificación y uso hay una condición de carrera controlada por el atacante.
- Ocurre con structs, offsets y cualquier dato que se revalide o recopie.
- La solución debe garantizar una **instantánea coherente**, no solo chequear dos veces.

---

# Errores: callbacks

- La biblioteca puede necesitar llamar a la aplicación (por ejemplo, pedir más bytes).
- La API tradicional solo pasa un puntero de 64 bits: puede apuntar a cualquier función.
- Los argumentos también son peligrosos: punteros arbitrarios desde el sandbox.
- El *timing* puede ser inesperado; el callback puede llegar en otro hilo.
- Resultado: corrupción de memoria, condiciones de carrera o flujos lógicos inválidos.

---

# Mecanismos RLBox

- **Sandbox:** bloquea el acceso directo a memoria fuera de su dominio.
- **Tipos *tainted*:** impiden usar valores no confiables como valores normales.
- **Copia + `verify`:** obliga a un punto explícito de copia y validación.
- **Callbacks registrados:** restringen qué funciones se pueden invocar y con qué tipos.
- RLBox hace visibles los cruces y bloquea clases de error **en compilación**.

---

# Valores *tainted*

- *Tainted* = dato originado en el sandbox; *untainted* = dato confiable del host.
- No se puede pasar un valor untainted al sandbox ni usar uno tainted afuera.
- Las operaciones aritméticas conservan el taint.
- No se permiten operaciones con efectos secundarios sobre tainted.
- Deshacerse del taint exige una verificación explícita.

---

# `copy_and_verify`

```cpp
tainted<int> t_width = sandbox_invoke(jpeg_sbx, get_width);
int w = t_width.copy_and_verify([](int v) {
  return (v > 0 && v <= 8192) ? v : 0;
});
```

- Copia el valor a memoria del host y aplica una política elegida por el desarrollador.
- Evita releer un dato que la biblioteca podría cambiar después.
- Un validador incompleto sigue siendo un validador: RLBox no adivina invariantes.
- En el JPEG faltan overflow, consistencia de buffer y formato.

---

# Punteros tainted y congelamiento

- `tainted<T*>` apunta a memoria del sandbox; `T*` apunta al host; no se convierten libremente.
- La memoria se asigna explícitamente y se copia con funciones controladas.
- **Freeze:** declara un grupo de datos como unidad coherente (por ejemplo, un struct).
- Leer un tipo freezable exige congelarlo primero: copia una instantánea completa.
- Así se elimina la ventana de doble-fetch entre campos relacionados.

---

# Callbacks en RLBox

- WebAssembly no permite importar funciones nuevas en tiempo de ejecución.
- Solución: un **trampolín** importado; recibe qué callback llamar y sus argumentos.
- El trampolín verifica que el callback esté registrado y sea válido.
- `register_callback()` exige argumentos tainted y retorno tainted o `void`.
- La vida del callback se limita por scope o `unregister` explícito.

---

# Rendimiento y costo de adopción

- Overhead de CPU modesto: ~3% con SFI/NaCl y ~13% con procesos.
- El costo de cambio de contexto se mitiga con optimizaciones.
- Memoria adicional moderada; los sandboxes no son de larga duración.
- Sandboxear una biblioteca toma ~1–3 días-persona y pocos cientos de LOCs.
- Lo más difícil son los **validadores**: requieren entender app y biblioteca.

---

# Límites de RLBox y resumen

- RLBox no decide si una respuesta tiene sentido para la aplicación.
- No detecta invariantes olvidadas ni valida orden, frecuencia o estado de callbacks.
- No corrige un aislamiento mal configurado.
- Garantía final = sandbox correcto + mecanismos + validadores semánticos correctos.
- Previene uso accidental de datos no confiables; no sustituye el razonamiento de seguridad.

---

# Pregunta de prueba 1

**¿Por qué aislar el decoder JPEG en un proceso separado no es suficiente?**

**Respuesta:**
- El proceso puede contener otras bibliotecas y datos valiosos.
- Un códec comprometido puede manipular esas otras bibliotecas.
- La frontera sigue siendo demasiado amplia; falta mínimo privilegio.
- Además, el host aún debe validar todo lo que devuelve.

---

# Pregunta de prueba 2

**¿Qué es un valor *tainted* y qué impide?**

**Respuesta:**
- Representa un dato que proviene del sandbox y no es confiable.
- Impide usarlo como `int`, puntero u otro valor normal del host.
- Las operaciones conservan el taint; no hay efectos secundarios sobre él.
- Para usarlo hay que copiarlo y pasar por un validador explícito.

---

# Pregunta de prueba 3

**¿Qué problema resuelve el congelamiento (*freeze*) y cómo?**

**Respuesta:**
- Evita el doble-fetch: que el atacante cambie un valor entre validación y uso.
- Declara un conjunto de datos como unidad coherente.
- Congelar copia una instantánea completa fuera del sandbox.
- Así dimensiones, stride y punteros provienen del mismo estado.

---

# Pregunta de prueba 4

**¿Qué garantiza RLBox y qué queda en manos del desarrollador?**

**Respuesta:**
- Garantiza aislamiento de memoria y bloquea cruces implícitos de tipos.
- Obliga a registrar callbacks y a validar valores con `copy_and_verify`.
- No garantiza que el validador exprese bien la política semántica.
- No valida timing, hilos ni el orden lógico de los callbacks.
