# La camara y el scroll

---
## 3b. Camara y scroll

| Direccion | Que es | Evidencia |
|---|---|---|
| `$FFF408` / `$FFF40A` | origen de camara X / Y | `sub.w $f408.w,d5` en `0x1EDE` |
| `$FFA014` / `$FFA016` | base X / Y del stage (init `$360` / `$20`) | `0x457A`, `0x4586` |
| `$FFF566` | scroll vertical acumulado | `add.w $f566.w,d0` en `loc_0156F0` |
| `$FFA010` / `$FFA012` | limites del stage | `0x1EFE4`, `0x1EFF4` |

