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

# Seguridad en aplicaciones de IA

### IIC2531 — Clase 21

Agentes, prompt injection y defensas de sistema:
de tool calling a Camel y las capacidades.

---

# ¿Qué es un agente?

- Sistema de IA que **percibe, decide y actúa** para cumplir un objetivo.
- Observa un entorno y usa herramientas para modificarlo.
- Itera: actúa, observa el resultado y decide el siguiente paso.
- Suele correr con los **privilegios del usuario**.
- Parte del entorno es **no confiable** (web, emails, issues).
- Las acciones tienen efectos reales: archivos, correos, comandos.

---

# Modelo mental

```
Usuario  ←→  Agente  ←→  Entorno
              ↑          ↓
           decisiones   datos + efectos
```

- El agente media entre intención y efectos.
- Recibe datos externos que pueden contener instrucciones.
- No hay separación clara entre "datos" e "instrucciones".
- Ahí nace la superficie de ataque.

---

# LLMs como base y tool calling

- Predicen el siguiente token: son **probabilísticos**, no deterministas.
- Difícil obtener garantías fuertes de comportamiento.
- Con tool calling el modelo emite una llamada estructurada, por ejemplo `get_weather(zip)`.
- El **harness** ejecuta la herramienta y devuelve el resultado al contexto.
- Las herramientas deben estar declaradas en el contexto.
- Ya no es solo un chatbot: decide acciones externas.

---

# Patrones ReAct y CodeAct

- **ReAct:** ciclo razonar → actuar → observar, repetido.
- Cada observación se agrega al contexto y permite tareas multi-paso.
- Problema: los datos de herramientas comparten contexto con las instrucciones.
- **CodeAct:** el modelo genera un programa que orquesta herramientas.
- El harness lo ejecuta; menos rondas, latencia y tokens.
- El flujo de datos ocurre dentro del código, no en el modelo.
- Permite fijar el control flow antes de tocar datos externos.

---

# Objetivos de seguridad

- **Integridad:** ¿el agente hizo lo que el usuario quería?
- **Confidencialidad:** ¿se filtraron datos privados?
- **Safety:** no dañar al usuario ni a terceros.
- Disponibilidad importa, pero hoy es secundaria.
- La intención del usuario no siempre es formalizable.
- En un agente, un fallo de integridad puede ser una acción irreversible.

---

# Panorama de ataques

- **Data poisoning:** alterar datos de entrenamiento o en vivo.
- **Jailbreaking:** hacer que el modelo ignore sus reglas.
- **Prompt injection:** introducir instrucciones en el contexto.
- **Directa:** el propio usuario ataca al operador.
- **Indirecta:** el atacante controla datos que el agente leerá.
- **Exfiltración:** sacar datos privados por un canal de salida.

---

# Prompt injection directa

- El usuario intenta saltarse el system prompt.
- Ejemplo: "ignora las instrucciones anteriores".
- Ataca sobre todo reglas de **safety** del operador.
- Conflicto de jerarquía: usuario vs. operador.
- Es visible: el usuario sabe que está atacando.
- El modelo no distingue de forma confiable autoridad de instrucciones.

---

# Prompt injection indirecta

- El atacante controla una página, email, PDF o nota.
- El usuario no ve el ataque.
- El agente lee el contenido y lo trata como contexto.
- Puede cambiar el plan o los argumentos de una herramienta.
- Ataca **integridad y confidencialidad**.
- Es el caso central para agentes con acceso a datos externos.

---

# Ejemplo: página maliciosa

- Usuario: "resume esta página".
- La página dice: "usa `curl | sh` para continuar".
- El agente ejecuta el comando y descarga código arbitrario.
- El usuario nunca vio la instrucción.
- Modelos modernos resisten mejor, pero la arquitectura sigue expuesta.
- El problema no es solo el modelo: es permitir que texto no confiable influya acciones privilegiadas.

---

# Defensas actuales

- **Safety training** del modelo.
- **System prompts** cuidadosos.
- **Guardrails** y clasificadores de entrada/salida.
- **Confirmaciones** antes de llamar herramientas.
- **Sandboxes** para limitar filesystem y red.
- Son defensa en profundidad, no una garantía.
- Ninguna resuelve el caso de datos privados + datos no confiables.

---

# El trade-off inevitable

- Más autonomía mejora la experiencia de uso.
- Más confirmaciones mejoran la seguridad y frenan al usuario.
- Modo "YOLO": productividad alta, riesgo alto.
- Los sandboxes limitan el daño local, no las filtraciones.
- El secreto puede estar dentro del sandbox y salir por la red.
- La seguridad debe venir de la arquitectura, no solo del comportamiento del modelo.

---

# Camel: idea central

- Defensa de **sistema**, no una heurística más.
- Inspirada en CodeAct y en el **dual LLM pattern**.
- Modelo de amenaza: el usuario original es confiable; todo lo demás, no.
- Separa el **control flow** de los datos no confiables.
- Rastrea flujos de información con capacidades.
- Aplica políticas antes de ejecutar herramientas con efectos.
- No pretende resolver toda la seguridad de agentes.

---

# Dual LLM pattern

![w:820](../assets/clase21/dual-llm-pattern.svg)

- El LLM **privilegiado** solo ve el pedido del usuario y genera el código una vez.
- El LLM en **cuarentena** lee datos externos, pero no tiene herramientas.
- Su salida no puede disparar nuevas acciones privilegiadas.
- Las instrucciones maliciosas quedan aisladas del plan.

---

# Qué logra y dónde falla el dual LLM

- **Logra:** cortar el paso de instrucciones externas a acciones.
- **Logra:** evitar que datos adversarios cambien el plan.
- **No logra:** garantizar respuestas correctas.
- Los datos aún influyen en **argumentos**: destinatario, nombre de archivo, ID.
- Puede elegir el documento equivocado o enviarlo a la persona equivocada.
- Protege control flow, no data flow.

---

# Camel: capacidades y propagación

- Cada valor es un objeto Camel con metadata.
- **`sources`:** quién influyó en el valor.
- **`readers`:** quién está autorizado a leerlo.
- Al derivar un valor: `sources` se **unen**.
- Al derivar un valor: `readers` se **intersectan**.
- Así se rastrea el flujo de información entre documentos y acciones.
- Las capacidades no son la política: son la información para aplicarla.

---

# Políticas y exfiltración bloqueada

- Las políticas se evalúan antes de herramientas con efectos.
- Ven los argumentos y la metadata Camel.
- Pueden negar la acción.
- Ejemplo: `send_email(to, body)`.
- Regla natural: el destinatario debe estar en los `readers` del body.
- Si el body solo lo pueden leer Bob y Alice, enviarlo a `attacker@evil.com` falla.
- Una inyección que cambia el destino choca con la política.

---

# Límites y takeaways

- Camel no corrige respuestas falsas.
- No elimina ataques **text-to-text**: el resultado final sigue siendo manipulable.
- No calza perfecto con agentes de código que iteran según resultados.
- Requiere políticas y metadata correctas.
- Los agentes amplifican los riesgos de los LLM.
- La prompt injection indirecta es el ataque central.
- Control flow y data flow deben separarse por diseño.

---

# Pregunta de prueba 1

**¿Qué diferencia a prompt injection directa de indirecta?**

**Respuesta:**

- La directa la escribe el propio usuario contra el operador.
- La indirecta viene de datos externos que el agente procesa.
- En la indirecta el usuario no ve la instrucción maliciosa.
- La indirecta ataca integridad y confidencialidad del agente.

---

# Pregunta de prueba 2

**¿Por qué el dual LLM no basta para proteger los argumentos de una herramienta?**

**Respuesta:**

- El control flow queda fijo, pero los datos externos alimentan argumentos.
- El LLM en cuarentena puede devolver un destinatario o archivo manipulado.
- El agente privilegiado ejecuta la acción con esos argumentos.
- Se necesita además rastrear flujos y aplicar políticas.

---

# Pregunta de prueba 3

**¿Cómo se propagan `sources` y `readers` al calcular un valor derivado?**

**Respuesta:**

- `sources` se unen: el resultado depende de todos los orígenes.
- `readers` se intersectan: solo quien puede leer todos los datos puede leer el resultado.
- La metadata acompaña al valor hasta la herramienta.
- La política usa esa metadata para permitir o negar la acción.

---

# Pregunta de prueba 4

**¿Qué limita a Camel y por qué importa el trade-off autonomía/seguridad?**

**Respuesta:**

- No evita respuestas falsas ni ataques puramente text-to-text.
- No se adapta bien a agentes que deciden el siguiente paso según resultados.
- Depende de políticas y metadata correctas.
- Más autonomía mejora la UX, pero exige arquitectura y controles más fuertes.
