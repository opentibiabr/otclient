"""Tool for generating Lua files with spell information.
The script allows you to select (via dialog boxes or manual input)
one or more folders containing Lua scripts. It recursively traverses 
the directories, extracts the relevant data, organizes it using pandas,
and exports a Lua file that replicates the structure shown in modules/gamelib/spells.lua.
If any data is missing, a -- comment is added next to the parameter in the export to indicate its absence.

Warning: Code generated with AI
"""

from __future__ import annotations

import ast
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

try:
    import pandas as pd
except ImportError as exc:
    print(f"[ERROR] No se pudo importar pandas: {exc}")
    raise

try:
    import tkinter as tk
    from tkinter import filedialog, messagebox
except Exception:
    tk = None  # type: ignore
    filedialog = None  # type: ignore
    messagebox = None  # type: ignore


VOCATION_NAMES: Dict[int, str] = {
    0: "None",
    1: "Sorcerer",
    2: "Druid",
    3: "Paladin",
    4: "Knight",
    5: "Master Sorcerer",
    6: "Elder Druid",
    7: "Royal Paladin",
    8: "Elite Knight",
    9: "Monk",
    10: "Exalted Monk",
}


SPELL_GROUPS: Dict[int, str] = {
    1: "Attack",
    2: "Healing",
    3: "Support",
    4: "Special",
    5: "Conjure",
    6: "Crippling",
    7: "Focus",
    8: "Ultimate Strikes",
    9: "Great Beams",
    10: "Bursts of Nature",
    11: "Virtue",
}


VOCATION_NAME_TO_ID = {name.lower(): vid for vid, name in VOCATION_NAMES.items()}
SPELL_GROUP_NAME_TO_ID = {name.lower(): gid for gid, name in SPELL_GROUPS.items()}

FORZED_ELIMINED_SPELLS = [
    "Blank Rune",
    "House Door List",
    "House Guest List",
    "House Kick",
    "House Subowner List","Light Stone Shower Rune"
    ,"Lightest Missile Rune"
]

FORCED_SPELL_IDS: Dict[str, int] = {
    "Wild Growth Rune": 94,
    "Animate Dead Rune": 83,
    "Avalanche Rune": 115,
    "Chameleon Rune": 14,
    "Convince Creature Rune" : 12,
    "Cure Poison Rune": 31,
    "Destroy Field Rune": 30,
    "Disintegrate Rune": 78,
    "Druid familiar": 197,
    "Energy Bomb Rune": 55,
    "Energy Field Rune": 27,
    "Energy Wall Rune": 33,
    "Explosion Rune": 18,
    "Fire Bomb Rune": 17,
    "Fire Field Rune": 25,
    "Fire Wall Rune": 28,
    "Fireball Rune": 15,
    "Great Fireball Rune" : 16,
    "Heavy Magic Missile Rune" : 8,
    "Holy Missile Rune" : 130,
    "Icicle Rune" : 114,
    "Intense Healing Rune" : 4,
    "knight familiar" : 194,
    "Light Magic Missile Rune" : 7,
    "Lightest Magic Missile": 0,
    "Magic Wall Rune": 86,
    "Paladin familiar": 195,
    "Paralyze Rune": 54,
    "Poison Bomb Rune": 91,
    "Poison Field Rune": 26,
    "Poison Wall Rune": 32,
    "Sorcerer familiar": 196,
    "Soulfire Rune": 50,
    "Stalagmite Rune": 77,
    "Stone Shower Rune": 116,
    "Sudden Death Rune": 117,
    "Ultimate Healing Rune": 5,
    "Wild Growth Rune": 94,
    "Thunderstorm Rune": 117,
    "Sudden Death Rune": 21,
}


MAP_ICON_INDEX: Dict[str, Tuple[Optional[int], Optional[int]]] = {
    "exura": (5, 1),
    "exura gran": (6, 2),
    "exura vita": (0, 3),
    "adura gran": (73, 4),
    "adura vita": (61, 5),
    "utani hur": (100, 6),
    "adori min vis": (72, 7),
    "adori vis": (76, 8),
    "utevo res": (117, 9),
    "utevo lux": (116, 10),
    "utevo gran lux": (115, 11),
    "adeta sio": (89, 12),
    "exevo vis hur": (42, 13),
    "adevo ina": (90, 14),
    "adori flam": (78, 15),
    "adori mas flam": (77, 16),
    "adevo mas flam": (81, 17),
    "adevo mas hur": (82, 18),
    "exevo flam hur": (43, 19),
    "exiva": (113, 20),
    "adori gran mort": (63, 21),
    "exevo vis lux": (40, 22),
    "exevo gran vis lux": (41, 23),
    "exevo gran mas flam": (48, 24),
    "adevo grav flam": (80, 25),
    "adevo grav pox": (68, 26),
    "adevo grav vis": (84, 27),
    "adevo mas grav flam": (79, 28),
    "exana pox": (9, 29),
    "adito grav": (86, 30),
    "adana pox": (88, 31),
    "adevo mas grav pox": (67, 32),
    "adevo mas grav vis": (83, 33),
    "exura gran san": (59, 36),
    "utevo res ina": (99, 38),
    "utani gran hur": (101, 39),
    "exevo pan": (98, 42),
    "exevo gran frigo hur": (45, 43),
    "utamo vita": (123, 44),
    "utana vid": (93, 45),
    "exevo con flam": (108, 49),
    "adevo res flam": (66, 50),
    "exevo con": (105, 51),
    "adana ani": (70, 54),
    "adevo mas vis": (85, 55),
    "exevo gran mas tera": (47, 56),
    "exori gran con": (58, 57),
    "exori min": (19, 59),
    "exori ico": (22, 61),
    "exori gran ico": (23, 62),
    "utevo vis lux": (114, 75),
    "exani tera": (104, 76),
    "adori tera": (65, 77),
    "adito tera": (87, 78),
    "exori": (20, 80),
    "exani hur": (124, 81),
    "exura gran mas res": (8, 82),
    "adana mort": (92, 83),
    "exura sio": (7, 84),
    "adevo grav tera": (71, 86),
    "exori mort": (37, 87),
    "exori vis": (28, 88),
    "exori flam": (25, 89),
    "exana ina": (94, 90),
    "adevo mas pox": (69, 91),
    "exevo gran mort": (141, 92),
    "exeta res": (96, 93),
    "adevo grav vita": (60, 94),
    "exori gran": (21, 105),
    "exori mas": (24, 106),
    "exori hur": (18, 107),
    "exeta con": (103, 110),
    "exori con": (17, 111),
    "exori frigo": (31, 112),
    "exori tera": (34, 113),
    "adori frigo": (74, 114),
    "adori mas frigo": (91, 115),
    "adori mas tera": (64, 116),
    "adori mas vis": (62, 117),
    "exevo gran mas frigo": (49, 118),
    "exevo gran mas vis": (51, 119),
    "exevo tera hur": (46, 120),
    "exevo frigo hur": (44, 121),
    "exori san": (38, 122),
    "exura ico": (2, 123),
    "exevo mas san": (39, 124),
    "exura san": (1, 125),
    "utito mas sio": (119, 126),
    "utamo mas sio": (122, 127),
    "utura mas sio": (125, 128),
    "utori mas sio": (112, 129),
    "adori san": (75, 130),
    "utani tempo hur": (97, 131),
    "utamo tempo": (121, 132),
    "utito tempo": (95, 133),
    "utamo tempo san": (118, 134),
    "utito tempo san": (120, 135),
    "utori flam": (54, 138),
    "utori mort": (53, 139),
    "utori vis": (55, 140),
    "utori kor": (56, 141),
    "utori pox": (57, 142),
    "utori san": (52, 143),
    "exana kor": (11, 144),
    "exana flam": (12, 145),
    "exana vis": (13, 146),
    "exana mort": (10, 147),
    "exori moe ico": (16, 148),
    "exori amp vis": (50, 149),
    "exori gran flam": (26, 150),
    "exori gran vis": (29, 151),
    "exori gran frigo": (32, 152),
    "exori gran tera": (35, 153),
    "exori max flam": (27, 154),
    "exori max vis": (30, 155),
    "exori max frigo": (33, 156),
    "exori max tera": (36, 157),
    "exura gran ico": (3, 158),
    "utura": (14, 159),
    "utura gran": (15, 160),
    "exura dis": (127, 166),
    "exevo dis flam hur": (128, 167),
    "adori dis min vis": (129, 168),
    "exori min flam": (126, 169),
    "exori infir tera": (136, 172),
    "exevo infir frigo hur": (135, 173),
    "exura infir": (133, 174),
    "exura infir ico": (134, 175),
    "exevo infir con": (137, 176),
    "exori infir vis": (132, 177),
    "exevo infir flam hur": (131, 178),
    "adori infir vis": (None, 179),
    "adori infir mas tera": (None, 180),
    "utevo gran res eq": (142, 194),
    "utevo gran res sac": (144, 195),
    "utevo gran res ven": (145, 196),
    "utevo gran res dru": (143, 197),
    "exeta amp res": (111, 237),
    "exana amp res": (138, 238),
    "exura med ico": (4, 239),
    "exevo gran flam hur": (102, 240),
    "exura max vita": (107, 241),
    "exura gran sio": (106, 242),
    "exori moe": (109, 243),
    "exori kor": (110, 244),
    "exana vita": (146, 245),
    "exiva moe res": (147, 248),
    "exevo tempo mas san": (155, 258),
    "exevo max mort": (157, 260),
    "exori amp kor": (152, 261),
    "exevo ulus tera": (154, 262),
    "exevo ulus frigo": (153, 263),
    "uteta res eq": (148, 264),
    "uteta res sac": (150, 265),
    "uteta res ven": (151, 266),
    "uteta res dru": (149, 267),
    "utevo grav san": (158, 268),
    "exori infir con": (159, 270),
    "exori infir min": (160, 271),
    "exura gran tio": (161, 273),
    "utori virtu": (162, 274),
    "utito virtu": (163, 275),
    "utura tio": (164, 276),
    "uteta tio": (165, 277),
    "utevo mas sio": (166, 278),
    "utevo nia": (167, 279),
    "exori mas res": (168, 280),
    "utamo tio": (169, 281),
    "utevo gran res tio": (170, 282),
    "uteta res tio": (171, 283),
    "exori infir pug": (172, 284),
    "exori pug": (173, 285),
    "exori gran pug": (174, 286),
    "exori mas pug": (175, 287),
    "exori med pug": (176, 288),
    "exori gran mas pug": (177, 289),
    "exori amp pug": (178, 290),
    "exori infir nia": (179, 291),
    "exori nia": (180, 292),
    "exori gran nia": (181, 293),
    "exori mas nia": (182, 294),
    "exori gran mas nia": (183, 295),
    "exura mas nia": (184, 296),
    "exura tio sio": (185, 297),
}


@dataclass
class SpellRecord:
    name: str
    file_path: Path
    spell_type: str
    id: Optional[int] = None
    words: Optional[str] = None
    level: Optional[int] = None
    mana: Optional[int] = None
    soul: Optional[int] = None
    magic_level: Optional[int] = None
    icon: Optional[str] = None
    clientId: Optional[int] = None
    cooldown: Optional[int] = None
    group_name: Optional[str] = None
    group_cooldown: Optional[int] = None
    need_target: Optional[bool] = None
    has_params: Optional[bool] = None
    spell_range: Optional[int] = None
    premium: Optional[bool] = None
    vocations: List[int] = field(default_factory=list)
    special: Optional[bool] = None
    source_item: Optional[int] = None


@dataclass
class RuneRecord:
    rune_id: Optional[int]
    file_path: Path
    spell_id: Optional[int] = None
    name: Optional[str] = None
    group_name: Optional[str] = None
    cooldown: Optional[int] = None
    group_cooldown: Optional[int] = None


SAFE_NODES = {
    ast.Expression,
    ast.BinOp,
    ast.UnaryOp,
    ast.Num,
    ast.Constant,
    ast.Add,
    ast.Sub,
    ast.Mult,
    ast.Div,
    ast.FloorDiv,
    ast.Mod,
    ast.Pow,
    ast.USub,
    ast.UAdd,
    ast.Load,
    ast.Call,
    ast.Name,
}

ALLOWED_CALLS = {"int"}


def safe_eval(expr: str) -> Optional[int]:

    if expr is None:
        return None

    expr = expr.strip()
    if not expr:
        return None

    expr = expr.replace("true", "True").replace("false", "False")

    try:
        node = ast.parse(expr, mode="eval")
    except SyntaxError:
        return None

    if not all(isinstance(n, tuple(SAFE_NODES)) for n in ast.walk(node)):
        return None

    for sub in ast.walk(node):
        if isinstance(sub, ast.Call):
            if not isinstance(sub.func, ast.Name) or sub.func.id not in ALLOWED_CALLS:
                return None

    try:
        value = eval(compile(node, filename="<expr>", mode="eval"))
    except Exception:
        return None

    if isinstance(value, (int, float)):
        return int(value)
    return None


def parse_boolean(arg: str) -> Optional[bool]:
    arg = arg.strip().lower()
    if arg in {"true", "false"}:
        return arg == "true"
    return None


def normalize_words(words: Optional[str]) -> Optional[str]:
    if not words:
        return None
    cleaned = words.strip().lower()
    if not cleaned:
        return None
    cleaned = re.split(r"[\"'\{]", cleaned, 1)[0].strip()
    cleaned = re.sub(r"\s+", " ", cleaned)
    return cleaned or None


def lua_quote(value: str) -> str:
    if "'" in value and '"' in value:
        escaped = value.replace("\"", "\\\"")
        return f'"{escaped}"'
    if "'" in value:
        escaped = value.replace("\"", "\\\"")
        return f'"{escaped}"'
    escaped = value.replace("'", "\\'")
    return f"'{escaped}'"


def extract_vocations(arguments: Iterable[str]) -> List[int]:
    voc_ids: List[int] = []
    for raw in arguments:
        clean = raw.strip().strip("\"'")
        vocation_name = clean.split(";", 1)[0].strip().lower()
        voc_id = VOCATION_NAME_TO_ID.get(vocation_name)
        if voc_id is not None:
            voc_ids.append(voc_id)
    return sorted(set(voc_ids))


def detect_spell_type(base_type: str, content: str) -> str:
    base_type = base_type.strip().lower()
    if "conjureitem" in content.lower():
        return "Conjure"
    if base_type:
        return base_type.capitalize()
    return "Instant"


def parse_spell_file(path: Path):
    content = path.read_text(encoding="utf-8", errors="ignore")
    lines = [re.split(r"--", line, maxsplit=1)[0].strip() for line in content.splitlines()]

    spells: List[SpellRecord] = []
    runes: List[RuneRecord] = []

    spell_defs = re.findall(r"local\s+(\w+)\s*=\s*Spell\(\s*\"(.*?)\"\s*\)", content)
    name_to_type = {var: detect_spell_type(tp, content) for var, tp in spell_defs}

    conjure_match = re.search(r"conjureItem\(\s*(\d+)", content)
    conjure_source = int(conjure_match.group(1)) if conjure_match else None

    for var_name, spell_type in name_to_type.items():
        record = SpellRecord(name="", file_path=path, spell_type=spell_type, source_item=conjure_source)

        pattern = re.compile(rf"{var_name}:(\w+)\((.*?)\)")
        for line in lines:
            match = pattern.search(line)
            if not match:
                continue
            method, raw_args = match.groups()
            args = [arg.strip() for arg in raw_args.split(",") if arg.strip()]

            if method == "name" and args:
                record.name = args[0].strip("\"'")
            elif method == "id" and args:
                record.id = safe_eval(args[0])
            elif method == "words" and args:
                record.words = args[0].strip("\"'")
            elif method == "level" and args:
                record.level = safe_eval(args[0])
            elif method == "mana" and args:
                record.mana = safe_eval(args[0])
            elif method == "soul" and args:
                record.soul = safe_eval(args[0])
            elif method == "magicLevel" and args:
                record.magic_level = safe_eval(args[0])
            elif method == "icon" and args:
                record.icon = args[0].strip("\"'")
            elif method == "cooldown" and args:
                record.cooldown = safe_eval(args[0])
            elif method == "group" and args:
                record.group_name = args[0].strip("\"'")
            elif method == "groupCooldown" and args:
                record.group_cooldown = safe_eval(args[0])
            elif method == "needTarget" and args:
                record.need_target = parse_boolean(args[0])
            elif method == "hasParams" and args:
                record.has_params = parse_boolean(args[0])
            elif method == "range" and args:
                record.spell_range = safe_eval(args[0])
            elif method in {"isPremium", "premium"} and args:
                record.premium = parse_boolean(args[0])
            elif method == "vocation" and args:
                record.vocations.extend(extract_vocations(args))
            elif method == "needLearn" and args:
                record.special = parse_boolean(args[0])

        if record.words and record.words.startswith("##"):
            print(
                f"[DEBUG] Hechizo omitido por palabras marcadas (##): {record.words} en {path}"
            )
            continue

        if record.name and record.spell_type != "Rune":
            spells.append(record)

    rune_defs = re.findall(r"local\s+(\w+)\s*=\s*Spell\(\s*\"rune\"\s*\)", content)
    for var_name in {var for var, _ in spell_defs if name_to_type.get(var) == "Rune"} | set(rune_defs):
        record = RuneRecord(rune_id=None, file_path=path)
        pattern = re.compile(rf"{var_name}:(\w+)\((.*?)\)")
        for line in lines:
            match = pattern.search(line)
            if not match:
                continue
            method, raw_args = match.groups()
            args = [arg.strip() for arg in raw_args.split(",") if arg.strip()]

            if method == "runeId" and args:
                record.rune_id = safe_eval(args[0])
            elif method == "id" and args:
                record.spell_id = safe_eval(args[0])
            elif method == "name" and args:
                record.name = args[0].strip("\"'")
            elif method == "group" and args:
                record.group_name = args[0].strip("\"'")
            elif method == "cooldown" and args:
                record.cooldown = safe_eval(args[0])
            elif method == "groupCooldown" and args:
                record.group_cooldown = safe_eval(args[0])

        if record.rune_id is not None:
            runes.append(record)
        else:
            print(
                f"[DEBUG] Runa sin runeId en {path} (variable {var_name})"
            )

    return spells, runes


def select_directories() -> List[Path]:
    directories: List[Path] = []

    if tk is not None and filedialog is not None:
        try:
            root = tk.Tk()
            root.withdraw()
            while True:
                chosen = filedialog.askdirectory(title="Selecciona una carpeta con archivos Lua")
                if not chosen:
                    break
                directories.append(Path(chosen))
                if messagebox is None:
                    break
                if not messagebox.askyesno("Agregar otra carpeta", "¿Deseas seleccionar otra carpeta?"):
                    break
            root.destroy()
        except tk.TclError:  # type: ignore[attr-defined]
            pass

    if not directories:
        print("No fue posible abrir un cuadro de diálogo. Introduce rutas manualmente (vacío para terminar).")
        while True:
            manual = input("Carpeta: ").strip()
            if not manual:
                break
            directories.append(Path(manual))

    return directories


def collect_records(directories: Iterable[Path]) -> Tuple[pd.DataFrame, pd.DataFrame]:
    spell_records: List[SpellRecord] = []
    rune_records: List[RuneRecord] = []

    for directory in directories:
        if not directory.is_dir():
            continue
        for file in directory.rglob("*.lua"):
            print(f"[DEBUG] Procesando archivo: {file}")
            try:
                spells, runes = parse_spell_file(file)
            except Exception as exc:  # pragma: no cover - diagnósticos en tiempo de ejecución
                print(f"[ERROR] Fallo al procesar {file}: {exc}")
                continue
            spell_records.extend(spells)
            rune_records.extend(runes)

    spells_df = pd.DataFrame([vars(record) for record in spell_records])
    runes_df = pd.DataFrame([vars(record) for record in rune_records])

    return spells_df, runes_df


def drop_forzed_eliminated_spells(spells_df: pd.DataFrame) -> pd.DataFrame:
    if spells_df.empty or "name" not in spells_df.columns:
        return spells_df

    target_names = {name.lower() for name in FORZED_ELIMINED_SPELLS}

    def should_drop(value: object) -> bool:
        return isinstance(value, str) and value.lower() in target_names

    mask = spells_df["name"].apply(should_drop)
    removed = spells_df[mask]
    if not removed.empty:
        for dropped_name in removed["name"].dropna().unique():
            print(f"[INFO] Hechizo eliminado por configuración: {dropped_name}")
    return spells_df.loc[~mask].reset_index(drop=True)


def apply_forced_spell_ids(spells_df: pd.DataFrame) -> pd.DataFrame:
    if spells_df.empty:
        return spells_df

    spells_df = spells_df.copy()
    if "name" not in spells_df.columns:
        return spells_df

    lower_map = {name.lower(): value for name, value in FORCED_SPELL_IDS.items()}

    taken_ids: Dict[int, str] = {}
    id_series = spells_df["id"] if "id" in spells_df.columns else pd.Series(dtype="float64")
    for idx, value in id_series.items():
        if pd.notna(value):
            raw_name = spells_df.at[idx, "name"] if "name" in spells_df.columns else ""
            taken_ids[int(value)] = str(raw_name) if pd.notna(raw_name) else ""

    for idx, row in spells_df.iterrows():
        name = row.get("name")
        if not isinstance(name, str):
            continue

        forced = lower_map.get(name.lower())
        if forced is None:
            continue

        current_id = row.get("id") if pd.notna(row.get("id")) else None
        previous_holder = taken_ids.get(forced)
        if previous_holder and previous_holder.lower() != name.lower():
            print(
                "[WARN] ID forzado {id_forzado} reasignado de '{anterior}' a '{actual}'".format(
                    id_forzado=forced, anterior=previous_holder, actual=name
                )
            )
            conflict_mask = (spells_df.index != idx) & (spells_df["id"] == forced)
            spells_df.loc[conflict_mask, "id"] = pd.NA

        if current_id is None:
            print(f"[INFO] ID forzado {forced} asignado a '{name}' (sin ID previo)")
        elif current_id != forced:
            print(
                f"[WARN] ID para '{name}' cambiado de {int(current_id)} a ID forzado {forced}"
            )

        spells_df.at[idx, "id"] = forced
        taken_ids[forced] = name

    return spells_df


def apply_icon_index_mapping(spells_df: pd.DataFrame) -> pd.DataFrame:
    if spells_df.empty or "words" not in spells_df.columns:
        return spells_df

    spells_df = spells_df.copy()

    for idx, words in spells_df["words"].items():
        normalized = normalize_words(words if isinstance(words, str) else None)
        if not normalized:
            continue

        mapping = MAP_ICON_INDEX.get(normalized)
        if not mapping:
            continue

        icon_idx, expected_id = mapping
        if icon_idx is not None:
            spells_df.at[idx, "clientId"] = icon_idx
        else:
            spells_df.at[idx, "clientId"] = pd.NA

        if expected_id is not None:
            current_id = spells_df.at[idx, "id"] if "id" in spells_df.columns else None
            if pd.isna(current_id):
                print(
                    f"[WARN] El hechizo '{spells_df.at[idx, 'name']}' con palabras '{words}' no tiene ID para validar (esperado {expected_id})"
                )
            elif int(current_id) != expected_id:
                print(
                    f"[WARN] El hechizo '{spells_df.at[idx, 'name']}' con palabras '{words}' tiene ID {int(current_id)} distinto al esperado {expected_id}"
                )

    return spells_df


def sort_spells_by_id(spells_df: pd.DataFrame) -> pd.DataFrame:
    if spells_df.empty:
        return spells_df

    return (
        spells_df.sort_values(by=["id", "name"], na_position="last", kind="mergesort")
        .reset_index(drop=True)
    )


def group_info(record: pd.Series) -> Tuple[Optional[int], Optional[int]]:
    group_name = str(record.get("group_name") or "").lower()
    group_id = SPELL_GROUP_NAME_TO_ID.get(group_name)
    return group_id, record.get("group_cooldown") if pd.notna(record.get("group_cooldown")) else None


DEFAULT_SPELL_NUMBERS = {
    "id": 0,
    "level": 0,
    "mana": 0,
    "soul": 0,
    "maglevel": 0,
    "range": -1,
    "exhaustion": 1000,
    "source": 0,
    "clientId": 0,
}

DEFAULT_SPELL_STRINGS = {
    "name": "",
    "words": "",
    "type": "",
    "icon": "",
}

DEFAULT_SPELL_BOOLS = {
    "needTarget": False,
    "parameter": False,
    "premium": False,
    "special": False,
}


def render_spell_info(spells_df: pd.DataFrame) -> List[str]:
    lines: List[str] = []
    if spells_df.empty:
        return lines
    for _, row in spells_df.iterrows():
        name = row["name"]
        if not isinstance(name, str) or not name:
            continue
        lines.append(f"        [{lua_quote(name)}] = {{")

        def emit_number(label: str, value: Optional[int]) -> None:
            if pd.isna(value):
                default_value = DEFAULT_SPELL_NUMBERS.get(label, 0)
                lines.append(f"            {label} = {default_value}, -- no encontrado")
            else:
                lines.append(f"            {label} = {int(value)},")

        def emit_string(label: str, value: Optional[str]) -> None:
            if not value or pd.isna(value):
                default_value = DEFAULT_SPELL_STRINGS.get(label, "")
                lines.append(
                    f"            {label} = {lua_quote(str(default_value))}, -- no encontrado"
                )
            else:
                lines.append(f"            {label} = {lua_quote(str(value))},")

        def emit_bool(label: str, value: Optional[bool]) -> None:
            if pd.isna(value):
                default_value = DEFAULT_SPELL_BOOLS.get(label, False)
                lines.append(
                    f"            {label} = {'true' if default_value else 'false'}, -- no encontrado"
                )
            else:
                lines.append(f"            {label} = {'true' if value else 'false'},")

        emit_number("id", row.get("id"))
        emit_string("name", name)
        emit_string("words", row.get("words"))
        emit_string("type", row.get("spell_type"))
        emit_number("level", row.get("level"))
        emit_number("mana", row.get("mana"))
        emit_number("soul", row.get("soul"))
        emit_number("maglevel", row.get("magic_level"))
        emit_string("icon", row.get("icon"))
        emit_number("clientId", row.get("clientId"))

        group_id, group_cd = group_info(row)
        if group_id is None or group_cd is None:
            default_group_id = 0
            default_group_cd = 1000
            lines.append(
                f"            group = {{ [{default_group_id}] = {default_group_cd} }}, -- no encontrado"
            )
        else:
            lines.append(f"            group = {{ [{group_id}] = {int(group_cd)} }},")

        emit_bool("needTarget", row.get("need_target"))
        emit_bool("parameter", row.get("has_params"))
        emit_number("range", row.get("spell_range"))
        emit_number("exhaustion", row.get("cooldown"))
        emit_bool("premium", row.get("premium"))

        vocs = row.get("vocations")
        if isinstance(vocs, list) and vocs:
            vocs_str = ", ".join(str(int(v)) for v in sorted(vocs))
            lines.append(f"            vocations = {{{vocs_str}}},")
        else:
            lines.append("            vocations = {}, -- no encontrado")

        emit_bool("special", row.get("special"))

        if pd.notna(row.get("source_item")):
            lines.append(f"            source = {int(row['source_item'])},")
        else:
            lines.append(
                f"            source = {DEFAULT_SPELL_NUMBERS['source']}, -- no encontrado"
            )

        lines.append("        },")

    return lines


def render_spell_order(spells_df: pd.DataFrame) -> str:
    names = [lua_quote(name) for name in spells_df["name"].dropna() if isinstance(name, str) and name]
    return "{ " + ", ".join(names) + " }"


DEFAULT_RUNE_VALUES = {
    "id": 0,
    "group": 0,
    "name": "",
    "exhaustion": 1000,
}


def render_rune_data(runes_df: pd.DataFrame) -> List[str]:
    lines: List[str] = []
    if runes_df.empty:
        return lines
    if "rune_id" not in runes_df.columns:
        print("[DEBUG] La columna 'rune_id' no existe en el DataFrame de runas")
        return lines

    for _, row in runes_df.dropna(subset=["rune_id"]).sort_values("rune_id").iterrows():
        rune_id = int(row["rune_id"])
        lines.append(f"    [{rune_id}] = {{")
        if pd.notna(row.get("spell_id")):
            lines.append(f"        id = {int(row['spell_id'])},")
        else:
            lines.append(
                f"        id = {DEFAULT_RUNE_VALUES['id']}, -- no encontrado"
            )

        group_name = (row.get("group_name") or "").lower()
        group_id = SPELL_GROUP_NAME_TO_ID.get(group_name)
        if group_id is None:
            lines.append(
                f"        group = {DEFAULT_RUNE_VALUES['group']}, -- no encontrado"
            )
        else:
            lines.append(f"        group = {group_id},")

        if row.get("name") and not pd.isna(row.get("name")):
            lines.append(f"        name = {lua_quote(str(row['name']))},")
        else:
            lines.append(
                f"        name = {lua_quote(DEFAULT_RUNE_VALUES['name'])}, -- no encontrado"
            )

        if pd.notna(row.get("cooldown")):
            lines.append(f"        exhaustion = {int(row['cooldown'])},")
        else:
            lines.append(
                f"        exhaustion = {DEFAULT_RUNE_VALUES['exhaustion']}, -- no encontrado"
            )

        lines.append("    },")

    return lines


def export_lua(spells_df: pd.DataFrame, runes_df: pd.DataFrame, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)

    spells_df = drop_forzed_eliminated_spells(spells_df)
    spells_df = apply_forced_spell_ids(spells_df)
    spells_df = apply_icon_index_mapping(spells_df)
    spells_df = sort_spells_by_id(spells_df)

    lines: List[str] = []
    lines.append("SpelllistSettings = {")
    lines.append("    ['Default'] = {")
    lines.append(f"        spellOrder = {render_spell_order(spells_df)}")
    lines.append("    }")
    lines.append("}")
    lines.append("")

    lines.append("SpellInfo = {")
    lines.append("    Default = {")
    lines.extend(render_spell_info(spells_df))
    if lines[-1].endswith(","):
        lines[-1] = lines[-1][:-1]
    lines.append("    }")
    lines.append("}")
    lines.append("")

    lines.append("VocationNames = {")
    for vid, name in VOCATION_NAMES.items():
        lines.append(f"    [{vid}] = {lua_quote(name)},")
    if lines[-1].endswith(","):
        lines[-1] = lines[-1][:-1]
    lines.append("}")
    lines.append("")

    lines.append("SpellGroups = {")
    for gid, name in SPELL_GROUPS.items():
        lines.append(f"    [{gid}] = {lua_quote(name)},")
    if lines[-1].endswith(","):
        lines[-1] = lines[-1][:-1]
    lines.append("}")
    lines.append("")

    lines.append("SpellRunesData = {")
    lines.extend(render_rune_data(runes_df))
    if lines[-1].endswith(","):
        lines[-1] = lines[-1][:-1]
    lines.append("}")

    destination.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    directories = select_directories()
    if not directories:
        print("No se seleccionaron carpetas. Finalizando.")
        return

    spells_df, runes_df = collect_records(directories)
    if spells_df.empty and runes_df.empty:
        print("No se encontraron archivos Lua con datos de hechizos.")
        return

    output_path = Path.cwd() / "spells" / "SpellExport.lua"
    export_lua(spells_df, runes_df, output_path)
    print(f"Archivo generado en: {output_path}")


if __name__ == "__main__":
    main()

