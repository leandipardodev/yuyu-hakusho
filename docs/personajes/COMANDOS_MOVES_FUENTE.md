# Comandos de moves — fuente externa (verificada)

Recopilado de:
- Kakusi (kakusi.jp/?p=54504) — comandos de 超霊撃 por personaje
- forum.gamer.com.tw (巴哈姆特, sn=138) — 招式表 完整版, los 11 personajes

**No existe frame data publicado de este juego.** Busqué en varios idiomas
y no hay tablas de startup/active/recovery de nadie. El juego salió solo en
Japón y en 1994 no había cultura de datamining. **El ROM sigue siendo la
única fuente de frame data.**

## Mapeo de botones (Kakusi)

| Acción | Mando de 3 botones |
|---|---|
| Ataque débil | **B** |
| Ataque fuerte | **A** |
| Defensa | **C** |
| Dash | ←← o →→ |
| Cambio de plano/línea | ↑ + C |
| Backstep | B + C |

Con mando de 6 botones: **X** = backstep, **Y** = línea, **Z** = dash.

**Requisito del 超霊撃 (super):** vida a la mitad o menos **y** barra de
espíritu espiritual (霊力) llena.

## Lista por personaje

| Personaje | Normales / especiales | Super (必殺技) |
|---|---|---|
| **浦飯幽助** Yusuke | 痛毆 (A o B連打), 靈丸 ↓↘→+A/B, 空中靈丸 ↑+↓↘→+A/B, 特大靈丸 (cargable), 收回靈丸, 閃彈靈丸 ↓↓+A/B | **魔人擊殺** →↓→+A |
| **幻海** Genkai | 靈丸 ↓↘→+A/B, 特大靈丸, 收回靈丸, 靈光彈 ↓↓+A/B, 昇龍拳 ↓↑+A/B, 空中昇龍拳 ↑+↓↑+A/B | **終極連擊** →↓→+A |
| **飛影** Hiei | 邪王炎殺煉獄焦 ↓↘→+A/B, 空中邪王炎殺煉獄焦 ↑+↓↘→+A/B, 邪王炎殺劍 A+B, 空中斬擊 ↓↓+A/B, 殘像 →→→→ | **炎殺黑龍波** ↓↘→↓↘→+A |
| **桑原** Kuwabara | 靈劍 A+B, 靈劍突刺 ↓↘→+A/B, 次元刀 ↓↑+A/B/C, 靈手裡劍 ↓↓+A/B | **靈劍連擊** ↓↓→+A |
| **藏馬** Kurama | 薔薇棘鞭刃 A+B, 玫瑰爆彈 ↓↘→+A/B, 風華圓舞陣 ↓↑+A/B, 魔界植物召換 ↓↓+A/B/C | **樹靈妖斬拳** →↓→↓+A |
| **仙水** Sensui | 裂蹴踢 A+B, 裂蹴紅球波 ↓↘→+A/B/C, 空中裂蹴紅球波 ↑+↓↘→+A/B/C, 氣硬銃 ↓↓+A/B | **特大裂蹴紅球波** ↓↓→+A/B/C |
| **樹** Itsuki | 雙連踢 ↓↘→+A/B, 瞬間移動 ↓↑+A/B/C, 影手 ↓↓+A/B/C (A ataca, B cura, C cancela) | **no figura** (es único con 時間暫停 ↓+A+B) |
| **陣** Jin | 飛行 (doble dirección en el aire), 雙修羅旋風拳 ↓↘→+A, 修羅旋風拳 ↓↘→+B, 暴風障壁 ↓↑+A/B | **修羅突風擊** ↓↓+A+B |
| **酎** Chui | 痛毆 (A o B連打), 醉拳閃身 A+B, 妖氣玉 ↓↘→+A/B, 特大妖氣玉, 收回妖氣玉, 衝撞 ↓↓+A/B, 飛踢 ↑+↓↓+A/B | **鐵頭功** ↓↗→↑+A |
| **戶愚呂兄** Toguro mayor | 觸手 A+B, 刺擊 ↓↘→+A/B, 空中刺擊 ↑+↓↘→+A/B, 虛身移動 ↓↑+A/B/C, 地下觸手 ↓↓+A/B/C | **連環刺擊** →↓→↓+A |
| **戶愚呂弟** Toguro menor | 爆肉鋼體 A+B, 空拳 ↓↘→+A/B, 指彈 ↓↓+A/B | **100%中的100% 120%突擊** ↓→↓+A |

## ERRORES detectados en nuestro `game_data.json`

Al comparar, **varios nombres de super y de especiales en nuestro JSON están
mal**. Correcciones:

| Personaje | Nuestro JSON | Correcto |
|---|---|---|
| Yusuke | super `霊光突撃` | **魔人擊殺** |
| Genkai | super `霊光亂打` | **終極連擊** |
| Sensui | super `巨大裂蹴紅球波` | **特大裂蹴紅球波** |
| Chui | super `醉風連脚` | **鐵頭功** |
| Kurama | `魔界含羞草` | **魔界植物召換** |
| Itsuki | `暗黑之手` | **影手** |
| Itsuki | falta el especial **時間暫停** (↓+A+B) y **no tiene super listado** | |
| Toguro mayor | super `乱風剣` | **連環刺擊** |
| Toguro menor | `力量衝擊上勾拳/下勾拳/空中爆落` | **空拳** e **指彈** |
| Genkai | `霊光亂打` | super real: **終極連擊** |

También hay una diferencia de nombres menor: `爆風障壁` (nuestro JSON) vs
**暴風障壁** (fuente).

## Secretos confirmados

- **Modo debug**: en OPTIONS mantener **A + C + START** (coincide con lo
  encontrado en el ROM: flags `$F550` bit 7 y `$F55A`).
- Cheats con debug: dirección + X/Y/Z para vida llena / vida crítica por jugador.
- **Modo ハンデ戦 (Handicap)** oculto: se desbloquea limpiando el modo
  勝抜き戦 o activando el debug en OPTIONS.
- Con CPU en dificultad máxima y completando el primer modo aparece un modo
  nuevo (1 vs 3).
