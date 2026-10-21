# Investigacion web - Yu Yu Hakusho: Makyou Toitsusen (Mega Drive)

Fuentes consultadas (chinas/taiwanesas, como sugeriste):

## Identidad del juego
- **Desarrollador:** Treasure (no SNK/Neo Geo)
- **Publisher:** SEGA
- **Fecha:** 1994-09-30 (Mega Drive) / 1999-12 Brasil (Tectoy, como "Sunset Fighters")
- **Tamano:** 24 Mbit
- **Controles:** 3 botones o 6 botones, 1-4 jugadores
- **Sistema:** 相杀系统 - cancelacion mutua entre技 normal / 必杀技 / 超霊撃技
- **Modos:** 含障碍赛 (obstacle race), 挑战赛 (challenge)
- **Fuente:** zh.wikipedia.org/zh-hans/幽游白书_魔强统一战 , baike.baidu.com/item/幽游白书-魔强统一战/2957641

## Roster real (11 personajes)

**Kuwabara (桑原一雄) y Kurama (蔵馬) son DOS personajes DISTINTOS** - confirmado por el usuario y por la lista de personajes. **No hay confusion de "dos formas de Kurama".**

| ID | Personaje | japones | chino | Alias |
|---|-----------|---------|-------|-------|
| 1 | Sensui | 仙水 | 仙水 | |
| 2 | Jin | 陣 | 阵 | |
| 3 | Itsuki | 樹 | 树 | |
| 4 | Genkai | 幻海 | 幻海 | super oculto: 灵光镜反冲 |
| 5 | **Kuwabara** | **桑原一雄** | 桑原 | (NO es Kurama) |
| 6 | Yusuke | 浦飯幽助 | 浦饭 | |
| 7 | **Kurama** | **蔵馬 (妖狐)** | 藏马 | demonio zorro |
| 8 | Hiei | 飛影 | 飞影 | |
| 9 | Chui | 酎 | 酎 | |
| 10 | Toguro mayor | 戶愚呂兄 | 户愚吕兄 | |
| 11 | Toguro menor | 戶愚呂弟 | 户愚吕弟 | |

Nota de traduccion importante: **桑原 = Kuwabara** (Kazuma Kuwabara, protagonista del primer arco), **蔵馬 = Kurama** (el zorro demoníaco). Son luchadores distintos.

Aparece tambien 审判 (Shinban) en Wikipedia - posible NPC/personaje no jugable.

Fuente: zh.wikipedia.org (seccion 登场人物) y forum.gamer.com.tw (招式表 完整版)

## SECRETOS / MECANICAS ocultas
1. **Modo oculto (unlock):** "将CPU困难度调到最高，在游玩第一个模式破关，会新增一个新模式"
   -> Poner la dificultad de CPU al MAXIMO, completar el primer modo, y se agrega un MODO NUEVO.
   -> Ademas: permite hasta **1 vs 3** en ese modo.
   Fuente: forum.gamer.com.tw (seccion PS)

2. **Toumei/Ou blend:** 蔵馬 es una forma alternativa de Kurama (妖狐 = zorro demonio).
   Kurama tiene dos entradas seleccionables: forma humana (桑原和真) y forma zorro (蔵馬).

3. Sistema de "超霊撃技" (super) por personaje con nombres propios listados arriba.

## Match con mi analisis del ROM (RESULTADO)
- **Kuwabara (ID 5) y Kurama (ID 7) son personajes distintos** - el usuario tiene razon, mi traduccion estaba mal.
- El **modo oculto** FUE encontrado en el codigo 68k: flag `$f550` bit 6 -> bit 7, en `0x3AD6`/`0x3ADE`, testeado en `0x39B0`.
- **Todos tienen la misma vida** (HP) - el HP es una constante global, no un stat por personaje.
- La tabla `0x109CA` NO es la lista de retratos (ningun modulo la referencia) - fue una inferencia erroneamia.

## Que buscar en el binario (para seguir)
- Movesets: los 超霊撃 de cada personaje estan en la logica de combate (11 bloques).
- El super oculto de Genkai ("灵光镜反冲") - solo existe en versiones modificadas segun fuentes.
