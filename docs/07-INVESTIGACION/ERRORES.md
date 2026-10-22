# Log de errores — Lessons learned

Registro de los errores que cometí durante la ingeniería inversa, con la causa
y el antidoto. **Existe porque no tengo memoria entre sesiones**: al retomar,
lo primero es leer este fichero.

Cómo usar: si voy a interpretar un dato, aquí está el error equivalente que ya
cometí. Si está, no lo repito.

---

## Categoría 1: interpretar antes de verificar

### E1 — Afirmé frame data sin leer el consumidor
**Qué hice:** vi que `$A030` recibía `#$7D` (125) y `#$A6` (166) y concluí que
eran duraciones en frames. Lo publiqué.
**Por qué falló:** no leí quién lo consume. Al hacerlo (`0xF5D6`) resultó que
era un **disparador de un solo disparo**: lee, llama a `$21960` y lo limpia.
**Lección:** un valor "que parece un contador" no lo es hasta que se lee su
productor.
**Antidoto:** antes de nombrar un campo, localizar el `jsr`/`btst`/`move` que lo
lee y comprobar si lo decrementa, lo limpia o lo compara.

### E2 — Llamé "id de comando" a un campo de bits
**Qué hice:** `$6C(a5)` viene de `b3` y lo llamé identificador de comando.
**Por qué falló:** el código lo lee con `btst.b #0/#1/#3/#4` y cada bit enruta a
un subsistema distinto (`$15CB0`, `$15DE6`, `$15E28`, `$15EFE`, `$15F24`).
**Lección:** antes de asumir "identificador", comprobar si se compara con
`cmpi` (entero) o se prueba con `btst` (bitfield).
**Antidoto:** `grep` de `cmpi.b ... $XX(a5)` vs `btst.b ... $XX(a5)`.

### E3 — Afirmé "195 moves por personaje"
**Qué hice:** construí un límite de tabla que aceptaba entradas mientras el
puntero cayera dentro del rango del contexto, y me dio 195. Lo documenté.
**Por qué falló:** el límite real son ~46 estados (IDs 0–177). Mi condición de
corte era demasiado laxa.
**Lección:** un conteo derivado de un heurístico es una hipótesis, no un dato.
**Antidoto:** validar el conteo contra una fuente independiente — en este caso,
extraer los IDs realmente usados en el código (`anclar_ids.py`) y comparar.

---

## Categoría 2: decodificación y aritmética

### E4 — Decodifiqué mal el prefijo de las instrucciones de bit
**Qué hice:** comprobé `((op >> 12) & 0xF) != 8` para detectar el prefijo
`0000 1xxx`. Para `0x08F9` eso da 0, así que la intercepción nunca disparaba.
Además antes había“人”mezclado BSET con BCLR/BCHG por el layout de bits.
**Por qué falló:** el prefijo está en los bits **11–8**, no 15–12.
**Antidoto:** cuando el valor "obvio" no funciona, **verificar el layout con un
caso conocido** en vez de razonar el binario de cabeza. Capstone dice
`tst.b` sobre el opcode real y ahí están los ground truth.

### E5 - Un parche con str.replace no aplico y no me aviso
**Qué hice:** reemplacé una comprobación de máscara por otra con `str.replace`
en un script y el script imprimió "corregido".
**Por qué falló:** **`str.replace` no avisa cuando el patrón no existe.** El
código parecía parcheado y no lo estaba. Perdi varias rondas creyendo que un
fix estaba aplicado.
**Lección crítica:** toda sustitución de código debe verificarse releyendo el
fichero.
**Antidoto:** después de parchear, `grep` del texto nuevo para confirmar que
existe. Nunca confiar en el "hecho" que imprime un script de parcheo.

### E6 — Conté la tabla mal por alineación
**Qué hice:** exigí que los registros estuvieran alineados a 8 bytes **en
absoluto**, y obtuve 0 entradas válidas. La tabla base (`$0BF75A`) no está
alineada; los registros solo están alineados **relativos a la base**.
**Lección:** en un ROM compilado, la alineación se Scheidet respecto a la base
de la tabla, no a la dirección 0.
**Antidoto:** cuando la alineación absoluta dé 0, probar relativa a la base.

### E7 — Aritmética de punteros: tres intentos fallidos
**Qué hice:** para la tabla índice de moves probé (a) el word tal cual, (b)
`base + word`, (c) `base + id*2 + word`, antes de llegar a lo correcto:
`destino = base + palabra[base + id*2]`.
**Por qué falló:** inventé candidatos en vez de **leer la instrucción**:
```
0x1EB48: movea.l $50(a5), a2      ; a2 = base
0x1EB4C: adda.w  (a2, d0.w), a2    ; a2 = base + palabra[base + d0]
```
Ahí estaba la respuesta, en dos instrucciones.
**Antidoto:** antes de probar una fórmula de punteros, **escribir a mano la
semántica del código que la calcula**.

---

## Categoría 3: desensamblado

### E8 — Desarmé desde offsets arbitrarios
**Qué hice:** desarmé desde `0xF5C0`, `0x2500`, `0x9480` esperando ver código,
y Capstone no decodificó nada porque esas direcciones caen **a mitad de una
instrucción**.
**Por qué falló:** `desensamblado_68000.asm` es un barrido lineal con huecos; solo es
fiable arrancar desde una dirección conocida como válida.
**Lección:** el desensamblado tiene regiones basura. Confiar en él sin ancla es
arriesgado.
**Antidoto:** desarmar desde la dirección de una instrucción que ya sé correcta
(por ejemplo, donde un `grep` encontró algo con bytes reconocibles).

### E9 — `desensamblado_z80.asm` no es confiable
**Qué hice:** leí el desensamblado del driver Z80 esperando la estructura.
**Por qué falló:** decodifica cosas inexistentes (`jp p`, `jp po`). El barrido
lineal se perdió.
**Antidoto:** para el Z80, verificar con el emulador `z80` en vez del
desensamblado estático.

---

## Categoría 4: herramientas

### E10 — Traté el índice 0 como transparente
**Qué hice:** en el decodificador de tiles 4bpp, salté los píxeles con índice 0.
**Por qué falló:** **en este juego el índice 0 es un color real** (fondo del
sprite), y ocupa ~50% de cada tile. Al saltarlo, la mitad de cada tile quedaba
en blanco y todo parecía ruido. **Me hizo concluir durante horas que "los
gráficos están comprimidos" cuando en realidad los estaba decodificando mal.**
**Antidoto:** al ver un render de tiles que parece ruido, comprobar **primero**
que la decodificación es correcta (probando una imagen conocida), antes de
concluir nada sobre el formato.

### E11 — Solo escaneé una variante del ROM
**Qué hice:** escaneé el ROM base (J) buscando tiles planos y no encontré nada.
**Por qué falló:** la variante **T+Chi** tiene los gráficos en 4bpp plano. No
la probé hasta mucho después.
**Antidoto:** cuando buscas un formato en un ROM y no aparece, **probar todas
las variantes** que tengas del mismo juego antes de concluir.

### E12 — Supuse que BizHawk podía leer memoria
**Qué hice:** escribí scripts Lua que volcaban VRAM "con éxito".
**Por qué falló:** el build es **NullHawk**, que no implementa dominios de
memoria. `memory.read_u8(addr, dom)` falla siempre. El volcado "salía" porque el
script escribía 0 cuando la lectura fallaba.
**Lección crítica:** un volcado que "funciona" puede estar lleno de ceros.
**Antidoto:** al escribir un script que vuelca a fichero, contar bytes no nulos y
verificar que no sea todo ceros.

---

## Categoría 5: proceso

### E13 — El emulador no produjo datos del juego
**Qué hice:** invertí muchas horas en un emulador 68000 (Unicorn) hoping a que
me diera los datos de las tablas.
**Por qué falló:** el emulador llega al arranque pero **no completa la
inicialización** (la cola de comandos es enorme), así que nunca ejecuta un
movimiento ni llena la VRAM. Netamente: cero datos del juego.
**Lección:** la herramienta correcta para leer un ROM es el **análisis
estático**. El emulador solo sirve si corre el juego entero, y eso es otro
proyecto.
**Antidoto:** antes de construir una herramienta grande, validar con un caso
pequeño que realmente responde la pregunta. Si en una hora no hay dato, la
herramienta es la equivocada.

### E14 — Interpreté una variable como un contador de cola
**Qué hice:** leí `$F554` = 4095 y `$F552` = 12796 y concluí que eran índices
de una cola de comandos. Luego descubrí que la cola real está en `$F700` y esos
dos valores son otra cosa (parecen código).
**Lección:** dos números que "se parecían" a contadores no son contadores.
**Antidoto:** verificar escribiendo/leyendo esos campos en el código, no
inferirlos por su forma.

---

## Reglas que sigo ahora

1. **Antes de interpretar un dato, leo quién lo consume.** (Evita E1, E2)
2. **Después de parchear, releo el fichero.** (Evita E5)
3. **Verifico el render antes de concluir sobre el formato.** (Evita E10)
4. **Si un conteo viene de un heurístico, lo valido por otra vía.** (Evita E3)
5. **Si una herramienta grande no da datos en una hora, cambio de herramienta.**
   (Evita E13)
6. **Pruebo todas las variantes del ROM antes de decir "no está".** (Evita E11)

---

## Para retomar

Antes de seguir, leer:
1. `INDICE.md` — estado maestro
2. `FISICAS-Y-MOVIMIENTO.md` — datos verificados
3. Este fichero — errores ya conhecidos

Siguiente tarea acordada: **implementar los datos en la remake de Godot**.
