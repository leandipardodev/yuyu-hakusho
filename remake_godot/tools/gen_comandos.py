# -*- coding: utf-8 -*-
"""
Genera data/comandos.json: los comandos de entrada REALES de cada especial.

Fuente: forum.gamer.com.tw sn=138 (招式表 完整版) + kakusi.jp/?p=54504.
Ver COMANDOS_MOVES_FUENTE.md para el texto original.

Notacion de direcciones (relativas al rival):
    f  = adelante
    b  = atras
    u  = arriba
    d  = abajo
    df = abajo+adelante
    db = abajo+atras
    uf = arriba+adelante
    ub = arriba+atras

Botones: A = fuerte, B = debil, C = defensa
(con mando de 6: X = backstep, Y = cambio de linea, Z = dash)
"""
import json
import io
import os

AQUI = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(AQUI), "data", "comandos.json")

# personaje: [(nombre, [direcciones], boton)]
DATOS = {
    1: [  # Sensui
        ("裂蹴踢",        ["f", "f"],                          "A"),
        ("裂蹴紅球波",    ["d", "df", "f"],                    "A"),
        ("空中裂蹴紅球波",["u", "d", "df", "f"],                "A"),
        ("氣硬銃",        ["d", "d"],                          "A"),
    ],
    2: [  # Jin
        ("雙修羅旋風拳",  ["d", "df", "f"],                    "A"),
        ("修羅旋風拳",    ["d", "df", "f"],                    "B"),
        ("暴風障壁",      ["d", "u"],                          "A"),
    ],
    3: [  # Itsuki
        ("雙連踢",        ["d", "df", "f"],                    "A"),
        ("瞬間移動",      ["d", "u"],                          "A"),
        ("影手",          ["d", "d"],                          "A"),
        ("時間暫停",      ["d"],                               "A"),
    ],
    4: [  # Genkai
        ("靈光彈",        ["d", "d"],                          "A"),
        ("昇龍拳",        ["d", "u"],                          "A"),
        ("空中昇龍拳",    ["u", "d", "u"],                      "A"),
    ],
    5: [  # Kuwabara
        ("靈劍",          ["f", "f"],                          "A"),
        ("靈劍突刺",      ["d", "df", "f"],                    "A"),
        ("次元刀",        ["d", "u"],                          "A"),
        ("靈手裡劍",      ["d", "d"],                          "A"),
    ],
    6: [  # Yusuke
        ("靈丸",          ["d", "df", "f"],                    "A"),
        ("空中靈丸",      ["u", "d", "df", "f"],                "A"),
        ("閃彈靈丸",      ["d", "d"],                          "A"),
    ],
    7: [  # Kurama
        ("薔薇棘鞭刃",    ["f", "f"],                          "A"),
        ("玫瑰爆彈",      ["d", "df", "f"],                    "A"),
        ("風華圓舞陣",    ["d", "u"],                          "A"),
        ("魔界植物召換",  ["d", "d"],                          "A"),
    ],
    8: [  # Hiei
        ("邪王炎殺煉獄焦",["d", "df", "f"],                    "A"),
        ("空中邪王炎殺煉獄焦", ["u", "d", "df", "f"],          "A"),
        ("邪王炎殺劍",    ["f", "f"],                          "A"),
        ("空中斬擊",      ["d", "d"],                          "A"),
        ("殘像",          ["f", "f", "f", "f"],                "B"),
    ],
    9: [  # Chui
        ("醉拳閃身",      ["f", "f"],                          "A"),
        ("妖氣玉",        ["d", "df", "f"],                    "A"),
        ("衝撞",          ["d", "d"],                          "A"),
        ("飛踢",          ["u", "d", "d"],                      "A"),
    ],
    10: [  # Toguro mayor
        ("觸手",          ["f", "f"],                          "A"),
        ("刺擊",          ["d", "df", "f"],                    "A"),
        ("空中刺擊",      ["u", "d", "df", "f"],                "A"),
        ("虛身移動",      ["d", "u"],                          "A"),
        ("地下觸手",      ["d", "d"],                          "A"),
    ],
    11: [  # Toguro menor
        ("爆肉鋼體",      ["f", "f"],                          "A"),
        ("空拳",          ["d", "df", "f"],                    "A"),
        ("指彈",          ["d", "d"],                          "A"),
    ],
}

# supers: (nombre, direcciones, boton)
SUPERS = {
    1:  ("特大裂蹴紅球波", ["d", "d", "f"],         "A"),
    2:  ("修羅突風擊",     ["d", "d"],               "A"),
    3:  (None,             [],                      ""),
    4:  ("終極連擊",       ["f", "d", "f"],         "A"),
    5:  ("靈劍連擊",       ["d", "d", "f"],         "A"),
    6:  ("魔人擊殺",       ["f", "d", "f"],         "A"),
    7:  ("樹靈妖斬拳",     ["f", "d", "d", "f"],     "A"),
    8:  ("炎殺黑龍波",     ["d", "df", "f", "d", "df", "f"], "A"),
    9:  ("鐵頭功",         ["d", "df", "f", "u"],   "A"),
    10: ("連環刺擊",       ["f", "d", "f", "d"],     "A"),
    11: ("100%中的100% 120%突擊", ["d", "f", "d"],  "A"),
}

NOMBRES = {
    1: "Sensui", 2: "Jin", 3: "Itsuki", 4: "Genkai", 5: "Kuwabara",
    6: "Yusuke", 7: "Kurama", 8: "Hiei", 9: "Chui",
    10: "Toguro (hermano mayor)", 11: "Toguro (hermano menor)",
}


def main():
    salida = {"_nota": "Comandos de entrada verificados. Direcciones relativas al rival. "
                       "Ver COMANDOS_MOVES_FUENTE.md", "personajes": {}}
    for pid, moves in DATOS.items():
        entrada = []
        for nombre, dirs, boton in moves:
            entrada.append({
                "nombre": nombre,
                "dirs": dirs,
                "boton": boton,
                "texto": "+".join(dirs) + "+" + boton if dirs else boton,
            })
        sup = SUPERS.get(pid)
        sup_d = None
        if sup and sup[0]:
            sup_d = {"nombre": sup[0], "dirs": sup[1], "boton": sup[2],
                     "texto": "+".join(sup[1]) + "+" + sup[2]}
        salida["personajes"][str(pid)] = {
            "nombre": NOMBRES.get(pid, str(pid)),
            "especiales": entrada,
            "super": sup_d,
        }

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with io.open(OUT, "w", encoding="utf-8") as f:
        json.dump(salida, f, ensure_ascii=False, indent=2)
        f.write("\n")

    tot = sum(len(v["especiales"]) for v in salida["personajes"].values())
    print("comandos.json generado")
    print("  personajes con especiales: %d" % len(DATOS))
    print("  total de especiales: %d" % tot)
    print("  supers: %d" % sum(1 for v in salida["personajes"].values() if v["super"]))


if __name__ == "__main__":
    main()

