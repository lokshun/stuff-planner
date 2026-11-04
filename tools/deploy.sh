#!/bin/sh
# Copie l'addon vers les dossiers AddOns renseignés dans .env :
#   WOW_ADDONS_VANILLA="<dossier _classic_era_>/Interface/AddOns"
#   WOW_ADDONS_FOREVER="<dossier _forever_>/Interface/AddOns"
# ENV_FILE désigne un autre fichier de configuration.
set -eu

ENV_FILE=${ENV_FILE:-.env}

if [ ! -f "$ENV_FILE" ]; then
    echo "Fichier $ENV_FILE introuvable : y définir WOW_ADDONS_VANILLA et WOW_ADDONS_FOREVER" >&2
    exit 1
fi

WOW_ADDONS_VANILLA=
WOW_ADDONS_FOREVER=
case "$ENV_FILE" in
    */*) . "$ENV_FILE" ;;
    *) . "./$ENV_FILE" ;;
esac

if [ -z "$WOW_ADDONS_VANILLA" ] && [ -z "$WOW_ADDONS_FOREVER" ]; then
    echo "Aucun dossier AddOns renseigné dans $ENV_FILE" >&2
    exit 1
fi

sh tools/fetch_libs.sh

copy_to() { # dossier AddOns
    mkdir -p "$1"
    for addon in StuffPlanner StuffPlanner_Data; do
        if [ -d "$addon" ]; then
            rm -rf "${1:?}/$addon"
            cp -R "$addon" "$1/$addon"
        fi
    done
    echo "Déployé vers $1"
}

if [ -n "$WOW_ADDONS_VANILLA" ]; then
    copy_to "$WOW_ADDONS_VANILLA"
fi
if [ -n "$WOW_ADDONS_FOREVER" ]; then
    copy_to "$WOW_ADDONS_FOREVER"
fi
