#!/bin/bash
set -euo pipefail

if [[ $# -ne 3 || ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Uso: $0 VERSAO CAMINHO_DO_DMG CAMINHO_DO_GENERATE_APPCAST" >&2
    exit 2
fi

version=$1
dmg=$2
generate_appcast=$3
if [[ ! -f $dmg || ! -x $generate_appcast ]]; then
    echo "O DMG e o executável generate_appcast precisam existir." >&2
    exit 2
fi

if ! codesign --verify --strict "$dmg" || ! xcrun stapler validate "$dmg"; then
    echo "Assine e notarize o DMG antes de gerar o appcast." >&2
    exit 1
fi

project_root=$(cd "$(dirname "$0")/.." && pwd)
release_dir=${POKEDOCK_RELEASE_DIR:-"$project_root/dist/releases/v$version"}
mkdir -p "$release_dir"
release_dmg="$release_dir/PokeDock.dmg"
if [[ ! -e $release_dmg || ! $dmg -ef $release_dmg ]]; then
    cp "$dmg" "$release_dmg"
fi

"$generate_appcast" \
    --account com.guilhermecunha.pokeTab \
    --download-url-prefix "https://github.com/Guizera/PokeDock/releases/download/v$version/" \
    -o "$release_dir/appcast.xml" \
    "$release_dir"

if ! rg -q 'sparkle:edSignature=' "$release_dir/appcast.xml"; then
    echo "O appcast não contém uma assinatura Ed25519 para o DMG." >&2
    exit 1
fi
if ! rg -Fq "https://github.com/Guizera/PokeDock/releases/download/v$version/PokeDock.dmg" "$release_dir/appcast.xml"; then
    echo "O appcast não aponta para o DMG desta release." >&2
    exit 1
fi

echo "Arquivos gerados para a release v$version (confirme a notarização do DMG antes de publicar):"
echo "$release_dir/PokeDock.dmg"
echo "$release_dir/appcast.xml"
