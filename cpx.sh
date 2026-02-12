#!/bin/bash

# =============================================
# Auteur: Bruno DELNOZ
# Email: bruno.delnoz@protonmail.com
# Path complet: /mnt/data2_78g/Security/scripts/Projects_utility/cpx/cpx.sh
# Target usage: Déplacement conditionnel de fichiers avec filtres d'extension (inclusion/exclusion) et exclusion de répertoires, utilisant | comme séparateur.
# Version: v2.4.3 – Date: 2026-02-12
# =============================================
# Changelog:
# v2.4.3 (2026-02-12) – Utilisation de | comme séparateur pour --ext, --excf, --exc. Arguments entre guillemets.
# v2.4.2 (2026-02-12) – Clarification du comportement par défaut des filtres.
# =============================================

# --- Variables globales ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LOG_DIR="$SCRIPT_DIR/logs"
RESULTS_DIR="$SCRIPT_DIR/results"
INFOS_DIR="$SCRIPT_DIR/infos"
SIMULATE=true
INSTALL_DEPS=false
SHOW_CHANGELOG=false
EXEC_MODE=false
OVERWRITE=false
VERSION="v2.4.3"
REPORT_FILE="$RESULTS_DIR/rapport_$(date +%Y-%m-%d_%H-%M-%S).txt"
EXTENSIONS=()
EXCLUDE_DIRS=()
EXCLUDE_EXTENSIONS=()
USE_EXT_FILTER=false
USE_EXCF_FILTER=false

# --- Initialisation des répertoires ---
mkdir -p "$LOG_DIR" "$RESULTS_DIR" "$INFOS_DIR"

# --- Fonctions internes ---
log_step() {
    echo "[Étape $1/$2] $3"
}

calculate_checksum() {
    sha256sum "$1" | awk '{ print $1 }'
}

write_report() {
    echo "$1" >> "$REPORT_FILE"
}

is_excluded_dir() {
    local dir="$1"
    for exc in "${EXCLUDE_DIRS[@]}"; do
        if [[ "$dir" == *"$exc"* ]]; then
            return 0
        fi
    done
    return 1
}

has_valid_extension() {
    local file="$1"
    if $USE_EXT_FILTER; then
        for ext in "${EXTENSIONS[@]}"; do
            if [[ "$file" == *.$ext ]]; then
                return 0
            fi
        done
        return 1
    fi
    return 0
}

has_excluded_extension() {
    local file="$1"
    if $USE_EXCF_FILTER; then
        for ext in "${EXCLUDE_EXTENSIONS[@]}"; do
            if [[ "$file" == *.$ext ]]; then
                return 0
            fi
        done
    fi
    return 1
}

process_file() {
    local source_file="$1"
    local dest_file="$2"
    local step="$3"
    local total_steps="$4"
    local action=""

    log_step "$step" "$total_steps" "Traitement du fichier: $(basename "$source_file")"

    if [ -f "$dest_file" ]; then
        source_sum=$(calculate_checksum "$source_file")
        dest_sum=$(calculate_checksum "$dest_file")

        if [ "$source_sum" = "$dest_sum" ]; then
            if [ "$OVERWRITE" = true ]; then
                echo "  -> Fichier identique (checksum) : suppression du source (overwrite activé)."
                action="SUPPRESSION (overwrite) – Checksum: $source_sum"
                if [ "$SIMULATE" = false ]; then
                    rm "$source_file"
                    action="$action – [EXÉCUTÉ]"
                else
                    action="$action – [SIMULÉ]"
                fi
            else
                echo "  -> Fichier identique (checksum) : ignoré (overwrite désactivé)."
                action="IGNORÉ (déjà présent) – Checksum: $source_sum"
            fi
        else
            echo "  -> Fichier différent (checksum) : renommage de la cible en .old et déplacement du source."
            action="RENOMMAGE + DÉPLACEMENT – Source: $source_sum, Cible: $dest_sum"
            if [ "$SIMULATE" = false ]; then
                mv "$dest_file" "${dest_file}.old"
                mv "$source_file" "$dest_file"
                action="$action – [EXÉCUTÉ]"
            else
                action="$action – [SIMULÉ]"
            fi
        fi
    else
        echo "  -> Nouveau fichier : déplacement simple."
        action="DÉPLACEMENT – Checksum: $(calculate_checksum "$source_file")"
        if [ "$SIMULATE" = false ]; then
            mv "$source_file" "$dest_file"
            action="$action – [EXÉCUTÉ]"
        else
            action="$action – [SIMULÉ]"
        fi
    fi

    write_report "Fichier: $(basename "$source_file") – $action"
}

check_prerequisites() {
    local missing_deps=0
    for cmd in mv sha256sum; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Erreur: La commande '$cmd' est manquante."
            missing_deps=$((missing_deps + 1))
        fi
    done
    return $missing_deps
}

install_prerequisites() {
    echo "Installation des dépendances manquantes..."
    sudo apt-get update && sudo apt-get install -y coreutils
}

show_changelog() {
    echo "=== Changelog ==="
    grep -A100 "Changelog:" "$0" | head -n 100
    echo "================"
}

show_help() {
    echo "Usage: $0 [OPTIONS] --dir_source <source> --dir_target <target>"
    echo "Version: $VERSION"
    echo "Options:"
    echo "  --help          Affiche cette aide."
    echo "  --exec          Exécute le script (défaut: simulation)."
    echo "  --simulate      Mode simulation (défaut: true)."
    echo "  --ov            Active l'overwrite des fichiers identiques (défaut: false)."
    echo "  --ext \"ext1|ext2\" Extensions à inclure (ex: \"csv|json\")."
    echo "  --excf \"ext1|ext2\" Extensions à exclure (ex: \"txt|md|pdf\")."
    echo "  --exc \"dir1|dir2\" Répertoires à exclure (ex: \"temp|backup\")."
    echo "  --prerequis     Vérifie les prérequis."
    echo "  --install       Installe les dépendances manquantes."
    echo "  --changelog     Affiche le changelog."
    echo "  --dir_source    Répertoire source."
    echo "  --dir_target    Répertoire cible."
    exit 0
}

# --- Gestion des arguments ---
if [ "$#" -eq 0 ]; then
    show_help
fi

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --help) show_help ;;
        --exec) EXEC_MODE=true; SIMULATE=false ;;
        --simulate) SIMULATE=true ;;
        --ov) OVERWRITE=true ;;
        --ext)
            if $USE_EXCF_FILTER; then
                echo "Erreur: --ext et --excf sont mutuellement exclusifs."
                exit 1
            fi
            USE_EXT_FILTER=true
            IFS='|' read -ra EXTENSIONS <<< "$2"; shift ;;
        --excf)
            if $USE_EXT_FILTER; then
                echo "Erreur: --ext et --excf sont mutuellement exclusifs."
                exit 1
            fi
            USE_EXCF_FILTER=true
            IFS='|' read -ra EXCLUDE_EXTENSIONS <<< "$2"; shift ;;
        --exc) IFS='|' read -ra EXCLUDE_DIRS <<< "$2"; shift ;;
        --prerequis) check_prerequisites; exit $? ;;
        --install) INSTALL_DEPS=true ;;
        --changelog) SHOW_CHANGELOG=true ;;
        --dir_source) dir_source="$2"; shift ;;
        --dir_target) dir_target="$2"; shift ;;
        *) echo "Argument inconnu: $1"; show_help ;;
    esac
    shift
done

# --- Affichage du changelog si demandé ---
if [ "$SHOW_CHANGELOG" = true ]; then
    show_changelog
    exit 0
fi

# --- Vérification des prérequis ---
if [ "$INSTALL_DEPS" = true ]; then
    install_prerequisites
    exit 0
fi

# --- Vérification des répertoires ---
if [ -z "$dir_source" ] || [ -z "$dir_target" ]; then
    echo "Erreur: --dir_source et --dir_target sont obligatoires."
    show_help
fi

if [ ! -d "$dir_source" ] || [ ! -d "$dir_target" ]; then
    echo "Erreur: Un des répertoires n'existe pas."
    exit 1
fi

# --- Initialisation du rapport ---
echo "=== RAPPORT D'ACTIONS – $(date '+%Y-%m-%d %H:%M:%S') ===" > "$REPORT_FILE"
echo "Version: $VERSION" >> "$REPORT_FILE"
echo "Source: $dir_source" >> "$REPORT_FILE"
echo "Cible: $dir_target" >> "$REPORT_FILE"
echo "Mode: $(if $SIMULATE; then echo "Simulation"; else echo "Exécution"; fi)" >> "$REPORT_FILE"
echo "Overwrite: $(if $OVERWRITE; then echo "Oui"; else echo "Non"; fi)" >> "$REPORT_FILE"
$USE_EXT_FILTER && echo "Extensions incluses: ${EXTENSIONS[*]}" >> "$REPORT_FILE"
$USE_EXCF_FILTER && echo "Extensions exclues: ${EXCLUDE_EXTENSIONS[*]}" >> "$REPORT_FILE"
[ ${#EXCLUDE_DIRS[@]} -gt 0 ] && echo "Répertoires exclus: ${EXCLUDE_DIRS[*]}" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "Liste des fichiers traités et actions effectuées:" >> "$REPORT_FILE"
echo "------------------------------------------------" >> "$REPORT_FILE"

# --- Logs ---
log_file="$LOG_DIR/log.cpx.$(date +%Y-%m-%d_%H-%M-%S).log"
exec > >(tee -a "$log_file") 2>&1

# --- Exécution principale ---
echo "=== Début de l'exécution ($VERSION) ==="
echo "Source: $dir_source"
echo "Cible: $dir_target"
echo "Mode simulation: $SIMULATE"
echo "Overwrite: $OVERWRITE"
$USE_EXT_FILTER && echo "Extensions incluses: ${EXTENSIONS[*]}"
$USE_EXCF_FILTER && echo "Extensions exclues: ${EXCLUDE_EXTENSIONS[*]}"
[ ${#EXCLUDE_DIRS[@]} -gt 0 ] && echo "Répertoires exclus: ${EXCLUDE_DIRS[*]}"
echo "Rapport: $REPORT_FILE"
echo "Log: $log_file"
echo ""

# --- Parcours des fichiers ---
file_count=0
processed_files=0

find "$dir_source" -maxdepth 1 -type f | while read -r file; do
    file_count=$((file_count + 1))
done

if [ "$file_count" -eq 0 ]; then
    echo "Aucun fichier régulier trouvé dans le répertoire source: $dir_source"
    write_report "Aucun fichier régulier trouvé dans le répertoire source."
    echo ""
    echo "=== Exécution terminée (aucun fichier à traiter) ==="
    exit 0
fi

echo "Nombre de fichiers à traiter: $file_count"
write_report "Nombre de fichiers à traiter: $file_count"

find "$dir_source" -maxdepth 1 -type f | while read -r file; do
    filename=$(basename "$file")
    dirname=$(dirname "$file")

    # Vérification des exclusions de répertoire
    if [ ${#EXCLUDE_DIRS[@]} -gt 0 ] && is_excluded_dir "$dirname"; then
        echo "  -> Répertoire exclu: $dirname/$filename (ignoré)"
        write_report "Répertoire exclu: $dirname/$filename – IGNORÉ"
        continue
    fi

    # Vérification des extensions exclues
    if $USE_EXCF_FILTER && ! has_excluded_extension "$filename"; then
        echo "  -> Extension exclue: $filename (ignoré)"
        write_report "Extension exclue: $filename – IGNORÉ"
        continue
    fi

    # Vérification des extensions incluses
    if $USE_EXT_FILTER && ! has_valid_extension "$filename"; then
        echo "  -> Extension non autorisée: $filename (ignoré)"
        write_report "Extension non autorisée: $filename – IGNORÉ"
        continue
    fi

    processed_files=$((processed_files + 1))
    process_file "$file" "$dir_target/$filename" "$processed_files" "$file_count"
done

echo ""
echo "=== Exécution terminée ($processed_files/$file_count fichiers traités) ==="
echo "Rapport détaillé disponible: $REPORT_FILE"
