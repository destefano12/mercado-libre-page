#!/usr/bin/env bash
# Guarda automáticamente el trabajo en GitHub cada vez que Claude termina de responder.
# Hace commit de todos los cambios y los sube a la rama actual.
cd "${CLAUDE_PROJECT_DIR:-$(pwd)}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
git remote get-url origin >/dev/null 2>&1 || exit 0

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
[ -z "$branch" ] || [ "$branch" = "HEAD" ] && exit 0

if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -q -m "Auto-guardado: $(date '+%Y-%m-%d %H:%M')" || exit 0
fi

# Subir solo si hay commits sin publicar
if [ -n "$(git log "origin/$branch..HEAD" --oneline 2>/dev/null)" ] || ! git rev-parse --verify -q "origin/$branch" >/dev/null; then
  for wait in 0 2 4 8; do
    sleep "$wait"
    git push -q -u origin "$branch" 2>/dev/null && exit 0
  done
  echo "auto-push: no se pudo subir a GitHub (rama $branch)" >&2
fi
exit 0
