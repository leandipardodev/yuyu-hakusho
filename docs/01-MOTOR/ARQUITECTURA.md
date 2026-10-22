# La arquitectura del motor

*Hardware, bancos de ROM, el bucle principal, los secretos del juego.*

---
## 1. Hardware

| Dato | Valor | Fuente |
|---|---|---|
| Plataforma | Sega Mega Drive / Genesis, 68000 + Z80 | lectura del ROM |
| ROM | 3.145.728 bytes (3 MB) | fichero |
| Pistas de codigo 68000 | $000200 - $291ADD (111.420 bytes) | desensamblado |
| Instrucciones 68000 desensambladas | 28.168 | `desensamblado_68000.asm` |
| Driver Z80 | ROM $393FE, $C00 bytes | `desensamblado_z80.asm` |
| Resolucion | 320 x 224 | cabecera del ROM |

## 6. Secretos y modos

| Dato | Detalle |
|---|---|
| Flag modo oculto | `$F550` bit 7; establecido en `0x3ADE`, testeado en `0x39B0` |
| Flag modo completado | `$F55A`, establecido en `0xFEBC` |
| Debug | Opciones + `START` + `A` + `C` |

