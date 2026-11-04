#!/bin/sh
# Résume une sortie TAP lue sur stdin : détails des échecs puis « N ok, M échecs ».
# Code de sortie non nul en cas d'échec, ou si aucun test n'a tourné (busted planté).
tr -d '\r' | awk '
    /^ok /     { ok++; inFailure = 0; next }
    /^not ok / { failed++; inFailure = 1; print; next }
    /^1\.\./   { inFailure = 0; next }
    inFailure  { print; next }
    !/^#/ && NF { other[++nOther] = $0 }
    END {
        total = ok + failed
        if (total == 0) {
            for (i = 1; i <= nOther; i++) print other[i]
            print "Aucun test exécuté"
            exit 1
        }
        printf "%d ok, %d %s\n", ok, failed, (failed > 1 ? "échecs" : "échec")
        exit (failed > 0)
    }
'
