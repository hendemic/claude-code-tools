#!/usr/bin/env bash
# Copy language and architecture conventions from conventions/ into a
# project's .claude/ directory.
#
# Rule conventions (kind=rule) are path-scoped files copied to
# .claude/rules/conventions/ (Claude Code loads .claude/rules/ recursively).
# Skill conventions (kind=skill) are directories copied to .claude/skills/<name>/.
# Each copied file is recorded in .claude/conventions.lock so later runs can
# tell an upstream change ("update available") from a local edit ("locally
# modified"). The copies are meant to be committed with the project.
#
# With no command on an interactive terminal, opens a checklist (whiptail,
# dialog, or a plain prompt). Commands never prompt when stdin isn't a TTY.

set -euo pipefail

HARNESS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HARNESS/conventions"
COMMIT="$(git -C "$HARNESS" rev-parse --short HEAD 2>/dev/null || echo unknown)"

usage() {
    cat <<'EOF'
Usage: install-conventions.sh [--project DIR] [--force] [command] [names...]

Commands:
  list               All conventions with kind, status and description
  status             Installed conventions only
  add <names...>     Install conventions
  remove <names...>  Delete installed files and their lock entries
  update [names...]  Update installed conventions (default: all installed)

With no command on an interactive terminal, opens a checklist.

Options:
  --project DIR  Project root (default: current directory)
  --force        Overwrite or delete locally modified files without asking
  -h, --help     Show this help

Statuses: not installed, installed, update available, locally modified,
removed upstream (installed, but gone from the harness: remove it).
Rules go to .claude/rules/conventions/, skills to .claude/skills/<name>/.
Commit those and .claude/conventions.lock afterwards.
EOF
}

# --- arguments ---------------------------------------------------------------

PROJECT="$PWD"
FORCE=0
COMMAND=""
NAMES=()

while [ $# -gt 0 ]; do
    case "$1" in
        --project) [ $# -ge 2 ] || { usage >&2; exit 2; }; PROJECT="$2"; shift 2 ;;
        --project=*) PROJECT="${1#--project=}"; shift ;;
        --force) FORCE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
        *)
            if [ -z "$COMMAND" ]; then COMMAND="$1"; else NAMES+=("$1"); fi
            shift ;;
    esac
done

[ -d "$PROJECT" ] || { echo "No such directory: $PROJECT" >&2; exit 1; }
PROJECT="$(cd "$PROJECT" && pwd)"
LOCK="$PROJECT/.claude/conventions.lock"

top="$(git -C "$PROJECT" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$top" ]; then
    echo "Warning: $PROJECT is not a git repository" >&2
elif [ "$(cd "$top" && pwd)" != "$PROJECT" ]; then
    echo "Warning: $PROJECT is not the git repository root ($top)" >&2
fi

if command -v sha256sum >/dev/null 2>&1; then
    sha() { sha256sum "$1" | cut -d' ' -f1; }
elif command -v shasum >/dev/null 2>&1; then
    sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
else
    echo "Need sha256sum or shasum" >&2; exit 1
fi

# How to ask questions: whiptail/dialog (TUI), plain (terminal), none (never).
if [ -t 0 ]; then ASK=plain; else ASK=none; fi

CHANGES=()
SKIPPED=()

# --- library -----------------------------------------------------------------

all_conventions() {
    local d
    for d in "$LIB"/*/; do
        [ -f "$d/convention.conf" ] && basename "$d"
    done
}

conf_get() {  # <name> <key>; orphans have no conf (kind comes from the lock)
    if [ -f "$LIB/$1/convention.conf" ]; then
        sed -n "s/^$2=//p" "$LIB/$1/convention.conf" | head -n1
    elif [ "$2" = kind ]; then
        lock_entries "$1" | awk '{ print $2; exit }'
    fi
}

is_known() { [ -f "$LIB/$1/convention.conf" ]; }

source_files() {  # <name> -> paths relative to the convention dir
    (cd "$LIB/$1" && find . -type f ! -name convention.conf | sed 's|^\./||' | sort)
}

dest_for() {  # <name> <kind> <rel> -> path relative to the project
    case "$2" in
        rule) echo ".claude/rules/conventions/$3" ;;
        skill) echo ".claude/skills/$1/$3" ;;
        *) echo "Unknown kind '$2' for $1" >&2; return 1 ;;
    esac
}

# --- lock file ---------------------------------------------------------------
# One line per installed file: <convention> <kind> <dest> <sha256> <commit>

lock_entries() {  # [name] -> matching lines
    [ -f "$LOCK" ] || return 0
    awk -v c="${1:-}" '!/^#/ && NF >= 5 && (c == "" || $1 == c)' "$LOCK"
}

lock_sha() {  # <dest> -> recorded sha, or nothing
    [ -f "$LOCK" ] || return 0
    awk -v d="$1" '$3 == d { print $4 }' "$LOCK"
}

lock_del() {  # <dest>
    [ -f "$LOCK" ] || return 0
    awk -v d="$1" '$3 != d' "$LOCK" > "$LOCK.tmp"
    mv "$LOCK.tmp" "$LOCK"
}

lock_set() {  # <name> <kind> <dest> <sha>
    mkdir -p "$(dirname "$LOCK")"
    lock_del "$3"
    echo "$1 $2 $3 $4 $COMMIT" >> "$LOCK"
    sort -o "$LOCK" "$LOCK"
}

is_installed() { [ -n "$(lock_entries "$1")" ]; }

orphans() {  # installed conventions no longer in the library
    local name
    for name in $(lock_entries | awk '{ print $1 }' | sort -u); do
        is_known "$name" || echo "$name"
    done
}

# --- status ------------------------------------------------------------------

conv_status() {  # <name>
    local name="$1" kind rel dest recorded update=0 modified=0
    is_installed "$name" || { echo "not installed"; return; }
    is_known "$name" || { echo "removed upstream"; return; }
    kind="$(conf_get "$name" kind)"

    local expected=" "
    while IFS= read -r rel; do
        dest="$(dest_for "$name" "$kind" "$rel")"
        expected+="$dest "
        recorded="$(lock_sha "$dest")"
        [ "$recorded" = "$(sha "$LIB/$name/$rel")" ] || update=1
    done < <(source_files "$name")

    while read -r _ _ dest recorded _; do
        case "$expected" in *" $dest "*) ;; *) update=1 ;; esac
        if [ ! -f "$PROJECT/$dest" ] || [ "$(sha "$PROJECT/$dest")" != "$recorded" ]; then
            modified=1
        fi
    done < <(lock_entries "$name")

    if [ $update = 1 ] && [ $modified = 1 ]; then echo "update available, locally modified"
    elif [ $update = 1 ]; then echo "update available"
    elif [ $modified = 1 ]; then echo "locally modified"
    else echo "installed"
    fi
}

print_table() {  # <names...>
    local name
    printf '%-14s %-6s %-34s %s\n' NAME KIND STATUS DESCRIPTION
    for name in "$@"; do
        printf '%-14s %-6s %-34s %s\n' "$name" "$(conf_get "$name" kind)" \
            "$(conv_status "$name")" "$(conf_get "$name" description)"
    done
}

# --- prompts -----------------------------------------------------------------

box_size() {  # fit dialogs to the terminal, up to 24x100
    local lines cols
    lines="$(tput lines 2>/dev/null || echo 24)"
    cols="$(tput cols 2>/dev/null || echo 80)"
    BOX_H=$(( lines < 28 ? lines - 4 : 24 ))
    BOX_W=$(( cols < 104 ? cols - 4 : 100 ))
}

ask() {  # <question> [yes-label] [no-label] -> 0 for yes
    local yes="${2:-Yes}" no="${3:-No}" reply
    case "$ASK" in
        whiptail) whiptail --title "Conventions" --yes-button "$yes" --no-button "$no" \
                      --yesno "$1" 12 "$BOX_W" ;;
        dialog) dialog --title "Conventions" --yes-label "$yes" --no-label "$no" \
                    --yesno "$1" 12 "$BOX_W" ;;
        plain) read -r -p "$1 [y/N] " reply; [[ "$reply" =~ ^[Yy] ]] ;;
        *) return 1 ;;
    esac
}

show_diff() {  # <current> <incoming> <label>
    local tmp
    tmp="$(mktemp)"
    { echo "Local changes to $3 (- yours, + harness):"; echo
      diff -u "$1" "$2" || true; } > "$tmp"
    case "$ASK" in
        whiptail) whiptail --title "$3" --scrolltext --textbox "$tmp" "$BOX_H" "$BOX_W" ;;
        dialog) dialog --title "$3" --textbox "$tmp" "$BOX_H" "$BOX_W" ;;
        plain) cat "$tmp" ;;
    esac
    rm -f "$tmp"
}

confirm_overwrite() {  # <dest> <src>
    [ $FORCE = 1 ] && return 0
    if [ "$ASK" = none ]; then
        echo "Skipping $1: locally modified (re-run with --force to overwrite)"
        return 1
    fi
    show_diff "$PROJECT/$1" "$2" "$1"
    ask "$1 has local changes. Overwrite it with the harness version?" Overwrite Skip
}

confirm_delete() {  # <dest>
    [ $FORCE = 1 ] && return 0
    if [ "$ASK" = none ]; then
        echo "Skipping $1: locally modified (re-run with --force to delete)"
        return 1
    fi
    ask "$1 has local changes. Delete it anyway?" Delete Keep
}

# --- actions -----------------------------------------------------------------

prune_dirs() {  # <dest> -> remove empty parent dirs up to .claude/
    local dir
    dir="$(dirname "$PROJECT/$1")"
    while [ "$dir" != "$PROJECT/.claude" ] && [ "$dir" != "$PROJECT" ]; do
        rmdir "$dir" 2>/dev/null || break
        dir="$(dirname "$dir")"
    done
}

delete_file() {  # <dest> <recorded sha>
    if [ -f "$PROJECT/$1" ] && [ "$(sha "$PROJECT/$1")" != "$2" ]; then
        if ! confirm_delete "$1"; then SKIPPED+=("$1 (kept)"); return; fi
    fi
    rm -f "$PROJECT/$1"
    lock_del "$1"
    prune_dirs "$1"
    CHANGES+=("removed $1")
}

install_conv() {  # <name>  (add and update share this)
    local name="$1" kind rel src dest srcsha recorded destsha expected=" "
    kind="$(conf_get "$name" kind)"
    case "$kind" in
        rule|skill) ;;
        *) echo "$name: unknown kind '$kind' in convention.conf" >&2; return 1 ;;
    esac

    while IFS= read -r rel; do
        src="$LIB/$name/$rel"
        dest="$(dest_for "$name" "$kind" "$rel")"
        expected+="$dest "
        srcsha="$(sha "$src")"
        recorded="$(lock_sha "$dest")"

        if [ -f "$PROJECT/$dest" ]; then
            destsha="$(sha "$PROJECT/$dest")"
            if [ "$destsha" = "$srcsha" ]; then
                [ "$recorded" = "$srcsha" ] || lock_set "$name" "$kind" "$dest" "$srcsha"
                continue
            fi
            # Differs from both the harness and what we last installed.
            if [ "$destsha" != "$recorded" ] && ! confirm_overwrite "$dest" "$src"; then
                SKIPPED+=("$dest (locally modified)")
                continue
            fi
        fi

        mkdir -p "$(dirname "$PROJECT/$dest")"
        cp "$src" "$PROJECT/$dest"
        lock_set "$name" "$kind" "$dest" "$srcsha"
        if [ -n "$recorded" ]; then CHANGES+=("updated $dest"); else CHANGES+=("added $dest"); fi
    done < <(source_files "$name")

    # Files the harness no longer ships for this convention.
    while read -r _ _ dest recorded _; do
        case "$expected" in *" $dest "*) ;; *) delete_file "$dest" "$recorded" ;; esac
    done < <(lock_entries "$name")
}

remove_conv() {  # <name>
    local dest recorded
    if ! is_installed "$1"; then echo "$1 is not installed"; return 0; fi
    while read -r _ _ dest recorded _; do
        delete_file "$dest" "$recorded"
    done < <(lock_entries "$1")
}

summary() {
    local item
    if [ ${#CHANGES[@]} -gt 0 ]; then
        echo "Changed:"
        for item in "${CHANGES[@]}"; do echo "  $item"; done
    fi
    if [ ${#SKIPPED[@]} -gt 0 ]; then
        echo "Skipped:"
        for item in "${SKIPPED[@]}"; do echo "  $item"; done
    fi
    [ ${#CHANGES[@]} -gt 0 ] || [ ${#SKIPPED[@]} -gt 0 ] || echo "Nothing changed."
    if [ ${#CHANGES[@]} -gt 0 ]; then
        echo "Commit .claude/rules/conventions, .claude/skills and .claude/conventions.lock in $PROJECT."
    fi
    # Drop an empty lock so a full remove leaves nothing behind.
    if [ -f "$LOCK" ] && [ -z "$(lock_entries)" ]; then rm -f "$LOCK"; fi
}

check_names() {  # <0|1 accept orphans> <names...> -> exit 1 on unknown names
    local name bad=0 known
    known=" $(all_conventions | tr '\n' ' ') "
    [ "$1" = 1 ] && known+="$(orphans | tr '\n' ' ') "
    shift
    for name in "$@"; do
        case "$known" in *" $name "*) ;; *) echo "Unknown convention: $name" >&2; bad=1 ;; esac
    done
    [ $bad = 0 ] || { echo "Available: $(all_conventions | tr '\n' ' ')" >&2; exit 1; }
}

# --- interactive -------------------------------------------------------------

choose_plain() {  # prints the selected names, one per line
    local names=("$@") i mark reply n
    echo "Conventions (* = installed):" >&2
    for i in "${!names[@]}"; do
        if is_installed "${names[$i]}"; then mark="*"; else mark=" "; fi
        printf ' %s %2d) %-14s %-34s %s\n' "$mark" $((i + 1)) "${names[$i]}" \
            "$(conv_status "${names[$i]}")" "$(conf_get "${names[$i]}" description)" >&2
    done
    read -r -p "Numbers to keep or install, space-separated (blank = no change, 0 = none): " reply
    if [ -z "$reply" ]; then
        for n in "${names[@]}"; do is_installed "$n" && echo "$n"; done
        return 0
    fi
    for n in $reply; do
        [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le ${#names[@]} ] && echo "${names[$((n - 1))]}"
    done
    return 0
}

choose_box() {  # <tool> <names...>
    local tool="$1" name state args=()
    shift
    for name in "$@"; do
        if is_installed "$name"; then state=ON; else state=OFF; fi
        args+=("$name" "[$(conv_status "$name")] $(conf_get "$name" description)" "$state")
    done
    "$tool" --title "Conventions" --separate-output \
        --checklist "Install into $PROJECT\nSpace toggles, Enter confirms." \
        "$BOX_H" "$BOX_W" $(( BOX_H - 8 )) "${args[@]}" 3>&1 1>&2 2>&3
}

run_tui() {
    local names chosen name status to_add=() to_remove=() to_update=()
    mapfile -t names < <(all_conventions; orphans)
    [ ${#names[@]} -gt 0 ] || { echo "No conventions in $LIB"; exit 0; }

    if command -v whiptail >/dev/null 2>&1; then ASK=whiptail
    elif command -v dialog >/dev/null 2>&1; then ASK=dialog
    else ASK=plain
    fi

    box_size
    if [ "$ASK" = plain ]; then
        chosen="$(choose_plain "${names[@]}")"
    else
        chosen="$(choose_box "$ASK" "${names[@]}")" || { clear; echo "Cancelled."; exit 0; }
        clear
    fi

    for name in "${names[@]}"; do
        status="$(conv_status "$name")"
        if grep -qx "$name" <<<"$chosen"; then
            case "$status" in
                "not installed") to_add+=("$name") ;;
                *update*) to_update+=("$name") ;;
            esac
        elif [ "$status" != "not installed" ]; then
            to_remove+=("$name")
        fi
    done

    if [ ${#to_remove[@]} -gt 0 ] && ! ask "Remove ${to_remove[*]}? This deletes the installed files."; then
        to_remove=()
    fi
    if [ ${#to_remove[@]} -gt 0 ]; then
        FORCE=1  # already confirmed
        for name in "${to_remove[@]}"; do remove_conv "$name"; done
        FORCE=0
    fi
    for name in "${to_add[@]}" "${to_update[@]}"; do install_conv "$name"; done
    summary
}

# --- main --------------------------------------------------------------------

[ -d "$LIB" ] || { echo "No conventions directory at $LIB" >&2; exit 1; }

case "$COMMAND" in
    "")
        if [ -t 0 ] && [ -t 1 ]; then run_tui; else usage >&2; exit 2; fi ;;
    list)
        mapfile -t all < <(all_conventions; orphans)
        print_table "${all[@]}" ;;
    status)
        installed=()
        for name in $(all_conventions); do is_installed "$name" && installed+=("$name"); done
        mapfile -t -O ${#installed[@]} installed < <(orphans)
        if [ ${#installed[@]} -eq 0 ]; then echo "No conventions installed in $PROJECT."
        else print_table "${installed[@]}"; fi ;;
    add)
        [ ${#NAMES[@]} -gt 0 ] || { echo "add: name at least one convention" >&2; exit 2; }
        check_names 0 "${NAMES[@]}"
        for name in "${NAMES[@]}"; do install_conv "$name"; done
        summary ;;
    remove)
        [ ${#NAMES[@]} -gt 0 ] || { echo "remove: name at least one convention" >&2; exit 2; }
        check_names 1 "${NAMES[@]}"
        for name in "${NAMES[@]}"; do remove_conv "$name"; done
        summary ;;
    update)
        rc=0
        if [ ${#NAMES[@]} -eq 0 ]; then
            for name in $(all_conventions); do is_installed "$name" && NAMES+=("$name"); done
        else
            check_names 1 "${NAMES[@]}"
        fi
        for name in $(orphans); do
            echo "$name: removed upstream, not updated (run: remove $name)"
        done
        for name in "${NAMES[@]}"; do
            if ! is_known "$name"; then continue  # orphan, reported above
            elif is_installed "$name"; then install_conv "$name"
            else echo "$name is not installed (use add)" >&2; rc=1
            fi
        done
        summary
        exit $rc ;;
    *)
        echo "Unknown command: $COMMAND" >&2; usage >&2; exit 2 ;;
esac
