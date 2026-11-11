#!/bin/sh
# Échoue si un fichier de l'addon, hors Compat*.lua et Libs, appelle directement une API
# réservée à Compat. Les appels Compat.GetItemStats restent permis.
# Usage : sh tools/check_direct_api.sh [dossier] (StuffPlanner par défaut)
root="${1:-StuffPlanner}"
pattern='(^|[^.[:alnum:]_]|_G\.|C_Item[.:])(C_TooltipInfo|TooltipDataProcessor|GetItemStats)([^[:alnum:]_]|$)'

matches=$(grep -rnE --include='*.lua' --exclude='Compat*.lua' --exclude-dir=Libs "$pattern" "$root")
if [ -n "$matches" ]; then
    echo "API reservee a Compat.lua appelee directement :"
    echo "$matches"
    exit 1
fi
