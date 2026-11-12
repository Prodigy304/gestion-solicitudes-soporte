#!/usr/bin/env python3
"""Registra tiempo real de la prueba en TIME_LOG.csv, con presupuesto total de 120 min."""
from __future__ import annotations

import argparse
import csv
import json
import sys
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATE_FILE = ROOT / ".time-tracker.json"
CSV_FILE = ROOT / "TIME_LOG.csv"
BLOCKS = ["A1", "A2", "A3", "B1", "B2"]
BUDGET = 120


def now() -> datetime:
    return datetime.now().astimezone()


def load_state() -> dict:
    if not STATE_FILE.exists():
        raise SystemExit("No hay temporizador iniciado. Ejecuta: python3 scripts/time_tracker.py start")
    return json.loads(STATE_FILE.read_text(encoding="utf-8"))


def save_state(state: dict) -> None:
    STATE_FILE.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")


def load_rows() -> list[dict]:
    with CSV_FILE.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def save_rows(rows: list[dict]) -> None:
    fields = ["Bloque", "Actividad", "Presupuesto_min", "Inicio_real", "Fin_real", "Duracion_real_min", "Estado"]
    with CSV_FILE.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def elapsed_minutes(start: str, end: datetime) -> float:
    return round((end - datetime.fromisoformat(start)).total_seconds() / 60, 1)


def close_block(state: dict, end: datetime) -> None:
    block = state.get("current_block")
    if not block:
        return
    rows = load_rows()
    for row in rows:
        if row["Bloque"] == block:
            row["Inicio_real"] = state["segment_started_at"]
            row["Fin_real"] = end.isoformat(timespec="seconds")
            row["Duracion_real_min"] = str(elapsed_minutes(state["segment_started_at"], end))
            row["Estado"] = "Registrado"
            break
    save_rows(rows)


def cmd_start(_: argparse.Namespace) -> None:
    if STATE_FILE.exists():
        state = json.loads(STATE_FILE.read_text(encoding="utf-8"))
        if state.get("running"):
            raise SystemExit("El temporizador ya está activo. Usa status o next.")
        raise SystemExit("Ya existe un registro finalizado. Respáldalo o elimina .time-tracker.json para iniciar otro.")
    stamp = now().isoformat(timespec="seconds")
    state = {"running": True, "total_started_at": stamp, "segment_started_at": stamp, "current_block": "A1"}
    save_state(state)
    print(f"Temporizador iniciado: {stamp}")
    print("Bloque actual: A1. Presupuesto: 120 minutos.")


def cmd_status(_: argparse.Namespace) -> None:
    state = load_state()
    if not state.get("running"):
        print("Temporizador detenido.")
        return
    current = now()
    total = elapsed_minutes(state["total_started_at"], current)
    segment = elapsed_minutes(state["segment_started_at"], current)
    print(f"Bloque: {state['current_block']} | tiempo del bloque: {segment:.1f} min")
    print(f"Tiempo total: {total:.1f}/{BUDGET} min | restante: {max(0, BUDGET-total):.1f} min")
    if total >= BUDGET:
        print("ALERTA: se alcanzó o superó el límite de 120 minutos.")


def cmd_next(args: argparse.Namespace) -> None:
    state = load_state()
    if not state.get("running"):
        raise SystemExit("El temporizador está detenido.")
    block = args.block.upper()
    if block not in BLOCKS:
        raise SystemExit("Bloque no válido. Usa A1, A2, A3, B1 o B2.")
    current_index = BLOCKS.index(state["current_block"])
    if BLOCKS.index(block) != current_index + 1:
        raise SystemExit(f"Siguiente bloque esperado: {BLOCKS[min(current_index + 1, len(BLOCKS)-1)]}.")
    stamp = now()
    close_block(state, stamp)
    state["current_block"] = block
    state["segment_started_at"] = stamp.isoformat(timespec="seconds")
    save_state(state)
    print(f"Bloque registrado. Ahora: {block} ({stamp.isoformat(timespec='seconds')})")


def cmd_stop(_: argparse.Namespace) -> None:
    state = load_state()
    if not state.get("running"):
        print("El temporizador ya está detenido.")
        return
    end = now()
    close_block(state, end)
    total = elapsed_minutes(state["total_started_at"], end)
    rows = load_rows()
    for row in rows:
        if row["Bloque"] == "TOTAL":
            row["Inicio_real"] = state["total_started_at"]
            row["Fin_real"] = end.isoformat(timespec="seconds")
            row["Duracion_real_min"] = str(total)
            row["Estado"] = "Dentro del límite" if total <= BUDGET else "Excedió 120 min"
            break
    save_rows(rows)
    state["running"] = False
    state["stopped_at"] = end.isoformat(timespec="seconds")
    state["total_minutes"] = total
    save_state(state)
    print(f"Temporizador detenido. Tiempo total real: {total:.1f} minutos.")
    if total > BUDGET:
        print(f"Se excedió el límite por {total-BUDGET:.1f} minutos.")
    else:
        print(f"Tiempo restante del presupuesto: {BUDGET-total:.1f} minutos.")
    print("TIME_LOG.csv actualizado.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Control de tiempo de la prueba técnica (120 minutos)")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("start", help="Iniciar el tiempo total y el bloque A1").set_defaults(func=cmd_start)
    sub.add_parser("status", help="Consultar tiempo transcurrido y restante").set_defaults(func=cmd_status)
    next_parser = sub.add_parser("next", help="Cerrar bloque actual y comenzar el siguiente")
    next_parser.add_argument("block", choices=BLOCKS[1:])
    next_parser.set_defaults(func=cmd_next)
    sub.add_parser("stop", help="Cerrar el último bloque y registrar el total real").set_defaults(func=cmd_stop)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
