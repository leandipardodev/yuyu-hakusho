# Investigación: cómo se desarrolló *Makyou Toitsusen* (Treasure, 1994)

Recopilación de fuentes públicas. Objetivo: entender la estructura del ROM y
por qué los gráficos no están en plano.

## 1. El juego se llamaba "Axion" antes de ser de YuYu

**Dato clave.** Treasure lo بدأ como un juego de lucha **original** titulado
**Axion** en 1993, y después lo rearmó con assets de *Yu Yu Hakusho*.

- Conceptualizado en 1993, cuando Treasure notó que faltaban títulos de lucha
  exclusivos para Mega Drive.
- La producción se frenó porque otro juego con mundo y conceptos parecido iba a
  salir antes. Luego se replanteó muchas veces hasta meter la licencia de YuYu.
- Según el presidente de Treasure **Masato Maegawa**, **los controles y la
  mecánica de juego —incluidos los escenarios multiplanar— ya estaban hechos
  para Axion** antes del replanteo.

**Consecuencia para nosotros:** el motor de juego (combate, planos, 4 jugadores)
es un motor de lucha **original de Treasure**, no un motor con licencia. Eso
explica por qué no hay documentación pública: nunca fuereleased como tal.

## 2. Créditos

| Rol | Persona |
|---|---|
| Director y diseñador gráfico principal | **Tetsuhiko Kikuchi** |
| Programadores | **Masaki Ukyo**, Mitsuru Yaida |
| Artistas | Makoto Ogino, **Hiroshi Iuchi** |
| Música y efectos | **Satoshi Murata** (con K. Suzuki, A. Hata, N. Hanzawa) |
| Supervisor | Masato Maegawa (presidente de Treasure) |

Fuentes: entrevista en *Beep! MegaDrive* nº 58 (julio 1994) y la revista
personal de Kikuchi 『はんの個人誌 落描帳総集編』 (1996).

## 3. La pista que más nos sirve: presión de VRAM por los sprites

En esa entrevista, Kikuchi dice que agradecía a los animadores el uso de
**sombras de los sprites**, pero que **su despreocupación por cuánta memoria
necesitaban los sprites-chief les creó dificultades**.

Traducción técnica: los personajes ocupan **mucha VRAM** (sprite + sombra, y con
**4 personajes a la vez en dos planos** la cosa se multiplica). Eso explica
directamente por qué el ROM **no guarda los gráficos en plano** y el juego
**los descomprime/expande al arrancar** — que es exactamente el bucle de
descompresión que encontramos en el código (`0x37C48`).

**Confirma nuestra hipótesis** de que la compresión no es capricho del
programador sino una necesidad de memoria de hardware.

## 4. El reto de programación declarado

**Masaki Ukyo** dijo que lo más difícil fue programar **tener 4 personajes en
pantalla simultáneamente** y que pudieran **cambiar libremente la orientación
que miran**.

Consistente con el `movea.l` + tabla de saltos por índice que vimos en `0x37D18`.

## 5. Linaje del motor

La mecánica de este juego fue la base de:

- **Guardian Heroes** (Saturn, 1996) — Maegawa dijo que querían "evolucionar"
  lo de Makyou Toitsusen.
- Los juegos de lucha de **Bleach** para Nintendo DS (4 jugadores, dos planos).

## 6. El prototipo de junio de 1994

Existe un **prototipo** fechado en **junio de 1994** (un mes antes de la versión
final) hallado en un disco de desarrollo de Sega Channel de enero de 1996.

- El BIN original faltaba, pero había **dos copias comprimidas con LZSS**
  (`YU_YU.GI` y `YU_YU.SA`).
- **Ojo: ese LZSS es el del formato del disco Sega Channel, NO la compresión
  propia del juego.** No confundir.
- El prototipo tiene diferencias con la versión final.

## 7. Lanzamientos

- Japón: **30 de septiembre de 1994** (publicado por Sega).
- Brasil: **1999**, por Tectoy, como **Yu Yu Hakusho: Sunset Fighters**. Es la
  versión que/"T+Chi" que tenés en la carpeta podría derivar.
- Mega Drive Mini (2019), solo versión japonesa.

## 8. Lo que NO encontramos

- **No hay documentación pública del formato interno del ROM**: ni el algoritmo
  de compresión de gráficos, ni la disposición de las tablas de moves. Ni TCRF,
  ni Sega Retro, ni GDRI tienen una ficha técnica de este juego.
- La página de TCRF del prototipo menciona LZSS, pero es del disco, no del juego
  (ver arriba).

**Conclusión:** la ingeniería inversa del formato interno sigue siendo trabajo
nuestro. Lo que la investigación confirma es **por qué** está comprimido
(presión de VRAM por sprites con sombra y 4 jugadores) y que el motor es
original de Treasure.

## Fuentes

- Wikipedia (EN): *Yu Yu Hakusho Makyō Tōitsusen* — sección Desarrollo
- Mizuumi Wiki:Yu Yu Hakusho: Makyou Toitsusen
- TCRF: Proto:Yuu Yuu Hakusho: Makyou Toitsusen (bloqueado por antibot; vía snippet)
- Beep! MegaDrive nº 58, julio 1994 (entrevista a Kikuchi) — archivada
- Wikipedia referencia: Masaki Ukyo, Tetsuhiko Kikuchi, Guardian Heroes
