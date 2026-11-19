# IIC2531 — Resúmenes de clases (2026-2)

Presentaciones en PDF con los contenidos principales de las clases 08 a 22 del curso **IIC2531: Seguridad de Sistemas Computacionales**.

Cada deck fue resumido a partir del material original de la clase, conservando su estilo Marp (tema, fondo y reglas CSS) y agregando:

- idea central y modelo de amenaza;
- definiciones y mecanismos clave;
- ejemplos para entender;
- defensas y limitaciones;
- **4 preguntas de prueba con su respuesta inmediatamente debajo**;
- un cierre con lo esencial.

## Contenido

| Clase | Tema | PDF | Fuente |
|---|---|---|---|
| 08 | Buffer overflows | [08-buffer-overflow.pdf](Clase08/08-buffer-overflow.pdf) | `Clase08/buffer-overflow.md` |
| 09 | RLBox y sandboxing de bibliotecas | [09-rlbox.pdf](Clase09/09-rlbox.pdf) | `Clase09/rlbox-revised.md` |
| 10 | Hardware confiable y BitLocker | [10-trusted-hardware.pdf](Clase10/10-trusted-hardware.pdf) | `Clase10/trusted-hardware.md` |
| 11 | Seguridad de iOS | [11-ios.pdf](Clase11/11-ios.pdf) | `Clase11/ios.md` |
| 12 | Bugs y ejecución simbólica | [12-exe.pdf](Clase12/12-exe.pdf) | `Clase12/exe.md` |
| 13 | Seguridad TCP/IP | [13-tcpip.pdf](Clase13/13-tcpip.pdf) | `Clase13/tcpip.md` |
| 14 | TLS y canales seguros | [14-tls.pdf](Clase14/14-tls.pdf) | `Clase14/tls.md` |
| 15 | Certificados y CAs | [15-certs.pdf](Clase15/15-certs.pdf) | `Clase15/certs.md` |
| 16 | Seguridad web y Same-Origin Policy | [16-web-security.pdf](Clase16/16-web-security.pdf) | `Clase16/web-security.md` |
| 17 | Autenticación de usuarios | [17-authentication.pdf](Clase17/17-authentication.pdf) | `Clase17/authentication.md` |
| 18 | OWASP Top 10 | [18-top-web-attacks.pdf](Clase18/18-top-web-attacks.pdf) | `Clase18/top-web-attacks.md` |
| 19 | Seguridad en mensajería | [19-messaging.pdf](Clase19/19-messaging.pdf) | `Clase19/messaging.md` |
| 20 | Tor y onion routing | [20-tor.pdf](Clase20/20-tor.pdf) | `Clase20/tor.md` |
| 21 | Seguridad en aplicaciones de IA | [21-security-in-ai.pdf](Clase21/21-security-in-ai.pdf) | `Clase21/security-in-ai.md` |
| 22 | Seguridad de la cadena de suministro | [22-supply-chain-security.pdf](Clase22/22-supply-chain-security.pdf) | `Clase22/supply-chain-security.md` |

Cada carpeta `ClaseXX/` contiene el `.md` fuente del resumen y el `.pdf` generado. Las imágenes y diagramas usados están en `assets/`.

## Estructura

```text
.
├── README.md
├── build.ps1
├── assets/
│   ├── hero-background.svg
│   ├── clase08/
│   ├── clase10/
│   └── ...
├── Clase08/
│   ├── 08-buffer-overflow.md
│   └── 08-buffer-overflow.pdf
├── Clase09/
│   └── ...
└── Clase22/
```

## Regenerar los PDF

Requisitos:

- Node.js y npm;
- Google Chrome o Microsoft Edge instalado (para renderizar Marp).

En Windows:

```powershell
./build.ps1
```

El script instala `@marp-team/marp-cli` en una carpeta temporal y regenera todos los PDF. También se puede compilar un solo deck:

```powershell
npx @marp-team/marp-cli "Clase08/08-buffer-overflow.md" --pdf --allow-local-files --pdf-outlines -o "Clase08/08-buffer-overflow.pdf"
```

## Notas

- La Clase09 usa `rlbox-revised.md`, que es la versión más completa del material.
- No se incluyeron las diapositivas extra (`ExtraSlides`).
- El repositorio está inicializado en Git y listo para publicarse. Para subirlo a GitHub:

```bash
git remote add origin <URL_DEL_REPOSITORIO>
git push -u origin main
```
