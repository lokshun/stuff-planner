#!/bin/sh
# Télécharge les bibliothèques dans StuffPlanner/Libs/ (non versionné), à des commits figés.
# Ne fait rien si les versions demandées sont déjà en place.
set -eu

ACE3_COMMIT=d295b12f8b889a30e86e0e901c5494df4b149c49       # Release-r1403
LIBDEFLATE_COMMIT=650e91c8000b38a3659c78e871c6d8647e6ac297 # 1.0.2-release
LDB_COMMIT=1a63ede0248c11aa1ee415187c1f9c9489ce3e02        # v1.1.4
HBD_COMMIT=90a7b2d8c065010dfb866e2b6bd56f5bc930029b        # 2.18-release
LIBDBICON_REV=168                                          # SVN WowAce, MINOR 57

ACE3_LIBS="LibStub CallbackHandler-1.0 AceAddon-3.0 AceBucket-3.0 AceConsole-3.0 AceDB-3.0 AceEvent-3.0 AceLocale-3.0 AceSerializer-3.0 AceTimer-3.0"

LIBS_DIR=StuffPlanner/Libs
STAMP="$LIBS_DIR/.versions"
WANTED="ace3=$ACE3_COMMIT libdeflate=$LIBDEFLATE_COMMIT ldb=$LDB_COMMIT hbd=$HBD_COMMIT libdbicon=$LIBDBICON_REV"

if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$WANTED" ]; then
    exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fetch() { # dépôt, commit
    curl -fsSL "https://github.com/$1/archive/$2.tar.gz" -o "$TMP/archive.tar.gz"
    tar -xzf "$TMP/archive.tar.gz" -C "$TMP"
}

fetch WoWUIDev/Ace3 "$ACE3_COMMIT"
fetch SafeteeWoW/LibDeflate "$LIBDEFLATE_COMMIT"
fetch tekkub/libdatabroker-1-1 "$LDB_COMMIT"
fetch Nevcairiel/HereBeDragons "$HBD_COMMIT"
curl -fsSL "https://repos.wowace.com/wow/libdbicon-1-0/!svn/bc/$LIBDBICON_REV/trunk/LibDBIcon-1.0/LibDBIcon-1.0.lua" -o "$TMP/LibDBIcon-1.0.lua"

rm -rf "$LIBS_DIR"
mkdir -p "$LIBS_DIR/LibDeflate" "$LIBS_DIR/LibDataBroker-1.1" "$LIBS_DIR/LibDBIcon-1.0" "$LIBS_DIR/HereBeDragons-2.0"

for lib in $ACE3_LIBS; do
    cp -R "$TMP/Ace3-$ACE3_COMMIT/$lib" "$LIBS_DIR/$lib"
done

for file in LibDeflate.lua lib.xml LICENSE.txt; do
    cp "$TMP/LibDeflate-$LIBDEFLATE_COMMIT/$file" "$LIBS_DIR/LibDeflate/"
done

cp "$TMP/libdatabroker-1-1-$LDB_COMMIT/LibDataBroker-1.1.lua" "$LIBS_DIR/LibDataBroker-1.1/"
cp "$TMP/LibDBIcon-1.0.lua" "$LIBS_DIR/LibDBIcon-1.0/"
for file in HereBeDragons-2.0.lua HereBeDragons-Pins-2.0.lua; do
    cp "$TMP/HereBeDragons-$HBD_COMMIT/$file" "$LIBS_DIR/HereBeDragons-2.0/"
done

printf '%s\n' "$WANTED" > "$STAMP"
echo "Bibliothèques installées dans $LIBS_DIR"
