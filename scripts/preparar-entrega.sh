#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf '\n== 1. Pruebas Java ==\n'
"$ROOT/java/run-tests.sh"

printf '\n== 2. Revisión de whitespace ==\n'
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$ROOT" diff --check
  git -C "$ROOT" status --short
else
  echo 'La carpeta aún no es un repositorio Git. Inicializar con: git init'
fi

printf '\n== 3. Verificación básica de secretos ==\n'
if grep -RniE '(password|passwd|secret|api[_-]?key|token)[[:space:]]*[:=][[:space:]]*[^<[:space:]]+' \
  "$ROOT" --exclude-dir=.git --exclude='*.pdf' --exclude='preparar-entrega.sh'; then
  echo 'Revisar coincidencias anteriores manualmente.'
else
  echo 'No se encontraron patrones obvios de secretos.'
fi

printf '\nListo. La revisión automática no sustituye la inspección manual.\n'
