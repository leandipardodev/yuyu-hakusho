# -*- coding: utf-8 -*-
"""
Vuelca la lista COMPLETA de moves por personaje desde la fuente externa,
corrigiendo lo que faltaba y lo que estaba mal en game_data.json.

Fuente: forum.gamer.com.tw sn=138 (招式表 完整版) + kakusi.jp/?p=54504 (supers).
Los nombres van tal cual aparecen en la fuente.

Ademas rellena con 0 los valores de danio de los especiales, porque la fuente
no los da: hay que medirlos. Los que ya venian medidos con BizHawk se conservan.

    python aplicar_moves.py
"""
import json
import collections
import io
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

AQUI = os.path.dirname(os.path.abspath(__file__))
P = os.path.join(AQUI, "..", "remake_godot", "data", "game_data.json")

MOVES = {
    1: ("特大裂蹴紅球波",
        ["裂蹴踢", "裂蹴紅球波", "空中裂蹴紅球波", "氣硬銃"], None),
    2: ("修羅突風擊",
        ["雙修羅旋風拳", "修羅旋風拳", "暴風障壁"], ["飛行: doble dirección en el aire"]),
    3: (None,
        ["雙連踢", "瞬間移動", "影手", "時間暫停"],
        ["時間暫停 = ↓+A+B, pausa temporal",
         "影手: A ataca, B cura, C cancela",
         "ÚNICO personaje sin super en la fuente"]),
    4: ("終極連擊",
        ["靈丸", "特大靈丸", "收回靈丸", "靈光彈", "昇龍拳", "空中昇龍拳"], None),
    5: ("靈劍連擊",
        ["靈劍", "靈劍突刺", "次元刀", "靈手裡劍"], None),
    6: ("魔人擊殺",
        ["痛毆", "靈丸", "空中靈丸", "特大靈丸", "收回靈丸", "閃彈靈丸"],
        ["特大靈丸 es cargable; 收回靈丸 lo cancela"]),
    7: ("樹靈妖斬拳",
        ["薔薇棘鞭刃", "玫瑰爆彈", "風華圓舞陣", "魔界植物召換"], None),
    8: ("炎殺黑龍波",
        ["邪王炎殺煉獄焦", "空中邪王炎殺煉獄焦", "邪王炎殺劍", "空中斬擊", "殘像"],
        ["炎殺黑龍波: la dirección modifica el trayectoria",
         "吸收黑龍波: usarlo contra uno mismo duplica la potencia"]),
    9: ("鐵頭功",
        ["痛毆", "醉拳閃身", "妖氣玉", "特大妖氣玉", "收回妖氣玉", "衝撞", "飛踢"], None),
    10: ("連環刺擊",
         ["觸手", "刺擊", "空中刺擊", "虛身移動", "地下觸手"], None),
    11: ("100%中的100% 120%突擊",
         ["爆肉鋼體", "空拳", "指彈"], None),
}


def main():
    with io.open(P, encoding="utf-8") as f:
        db = json.load(f, object_pairs_hook=collections.OrderedDict)

    for p in db["personajes"]:
        pid = p["id"]
        if pid not in MOVES:
            continue
        sup, esp, notas = MOVES[pid]
        nom = p["nombre"]
        viejo = p.get("super")

        if sup is None:
            p.pop("super", None)
            p["super_inexistente"] = True
            p["nota_super"] = "Sin super en la fuente externa"
            print("%-20s super %s -> (no existe)" % (nom, viejo))
        else:
            p["super"] = sup
            if viejo and viejo != sup:
                print("%-20s super %-10s -> %s" % (nom, viejo, sup))

        # conserva los danos ya medidos con BizHawk
        danio_previo = {}
        for k, v in p.get("especiales", {}).items():
            if isinstance(v, (int, float)) and v != 0:
                danio_previo[k] = v

        p["especiales"] = collections.OrderedDict((e, danio_previo.get(e, 0)) for e in esp)
        medidos = sum(1 for v in p["especiales"].values() if v)
        print("%-20s especiales: %-2d (con daño medido: %d)"
              % (nom, len(esp), medidos))

        if notas:
            p["notas_moves"] = notas

        conf = p.setdefault("_confianza", collections.OrderedDict())
        conf["super"] = "FUENTE_WEB(kakusi.jp / gamer.com.tw)"
        conf["especiales"] = "FUENTE_WEB(gamer.com.tw sn=138)"
        conf["especiales.danio"] = "BIZHAWK" if medidos else "PENDIENTE"

    db["_meta"]["nombres_moves"] = (
        "Lista de moves de fuentes externas japonesas: forum.gamer.com.tw "
        "sn=138 (招式表完整版) y kakusi.jp/?p=54504. Ver "
        "COMANDOS_MOVES_FUENTE.md. Los nombres previos venian de guias no "
        "verificadas y varios eran incorrectos."
    )
    db["_meta"]["botones"] = collections.OrderedDict([
        ("A", "ataque fuerte"),
        ("B", "ataque debil"),
        ("C", "defensa"),
        ("dash", "doble direccion"),
        ("linea", "arriba + C"),
        ("backstep", "B + C"),
        ("seis_botones", {"X": "backstep", "Y": "cambio de linea", "Z": "dash"}),
        ("requisito_super", "vida <= 50% y barra de espiritu (霊力) llena"),
    ])

    with io.open(P, "w", encoding="utf-8") as f:
        json.dump(db, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print()
    print("JSON actualizado correctamente: %d personajes" % len(db["personajes"]))


if __name__ == "__main__":
    main()
