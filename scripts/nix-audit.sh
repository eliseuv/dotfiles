#!/usr/bin/env bash
# Rebuild-check locally built store paths, to catch outputs that were
# miscompiled (e.g. by defective RAM) and then registered as valid.
#
# `nix store verify` cannot catch these: Nix hashed the already-corrupt output
# when registering it, so its contents match the database. Only rebuilding the
# derivation and comparing tells. Substituted paths are not rebuilt: their NAR
# hash was checked on import against a signed narinfo, so anything that went
# wrong with them since is what `nix store verify --all --no-trust` detects.
#
# Candidates are the locally built (`ultimate`), input-addressed outputs in the
# *build* graph of the roots, not just their runtime closure: a locally built
# compiler or generator that the roots no longer reference can still have
# poisoned what was built with it. Content-addressed paths are skipped, as
# their hash is checked by `nix store verify`.
#
# Derivations are checked dependencies first. `--check` reuses the existing
# inputs, so a result identical to the existing output proves nothing when an
# input in its build closure is itself suspect; such results are recorded as
# `inconclusive` instead of `identical`.
#
# Nothing existing is modified: `--check` builds into a temporary output, and
# keeps a differing one as `<out>.check` (an ordinary, garbage-collectable
# store path) for comparison, e.g. with diffoscope. --keep-failed, which keeps
# that output, also leaves the build directory of every non-identical rebuild
# in /nix/var/nix/builds, to be removed by hand. Results are appended as
# they come, and re-running with the same --out resumes where it stopped.
#
# Runs as any trusted Nix user. Other users' profiles are only readable as
# root; pass their resolved store paths as roots, or run under sudo.
set -euo pipefail

caches=(https://cache.nixos.org https://nix-community.cachix.org)

usage() {
    cat <<EOF
Usage: ${0##*/} [--exhaustive] [--out DIR] [ROOT...]

ROOT defaults to /run/current-system plus every readable user profile
(home-manager, profile).

  --exhaustive  Also every older system and user profile generation, and,
                when run as root, every GC root.
  --out DIR     Where results go (default: ./nix-audit-$(date +%F)).

Writes, in DIR:
  results.tsv  status, derivation, outputs, cache, cache_nar, note, log
  summary.txt  counts per status, and every row that is not \`identical\`
  logs/        output of each \`nix-store --realise --check\`

Statuses:
  identical       rebuilt bit-for-bit identical to the existing output
  differs         rebuilt differently; corruption or plain non-reproducibility
  inconclusive    identical, but an input in its build closure is not
  build-failed    the rebuild failed (1xx exit status, see its log)
  error           could not be checked at all (e.g. an output is missing)
  no-derivation   the deriver is unknown or no longer in the store

cache is which of ${caches[*]} have the output.
cache_nar compares the cache's NAR hash with the local one: \`match\` means
the local output equals the cache's build, \`differs\` means it does not.
EOF
}

exhaustive=false
out_dir="./nix-audit-$(date +%F)"
roots=()
while (($#)); do
    case $1 in
        --exhaustive) exhaustive=true ;;
        --out) out_dir=$2; shift ;;
        -h | --help) usage; exit 0 ;;
        -*) usage >&2; exit 1 ;;
        *) roots+=("$1") ;;
    esac
    shift
done

if ((${#roots[@]} == 0)); then
    roots=(/run/current-system)
    for home in /home/*; do
        profiles=$home/.local/state/nix/profiles
        if [[ ! -x $home || (-e $profiles && ! -r $profiles) ]]; then
            echo "warning: cannot read $profiles, its profiles are skipped" >&2
            continue
        fi
        for name in home-manager profile; do
            if [[ -e $profiles/$name ]]; then roots+=("$profiles/$name"); fi
            if $exhaustive; then
                for generation in "$profiles/$name"-*-link; do
                    if [[ -e $generation ]]; then roots+=("$generation"); fi
                done
            fi
        done
    done
    if $exhaustive; then
        roots+=(/nix/var/nix/profiles/system-*-link)
        if ((EUID == 0)); then
            mapfile -t -O "${#roots[@]}" roots < <(
                nix-store --gc --print-roots | awk '$3 ~ "^/nix/store/" { print $3 }'
            )
        else
            echo "warning: not root, GC roots are skipped" >&2
        fi
    fi
fi
mapfile -t roots < <(readlink -f "${roots[@]}" | sort -u)

mkdir -p "$out_dir/logs"
results=$out_dir/results.tsv
printf '%s\n' "${roots[@]}" > "$out_dir/roots.txt"
echo "roots: ${#roots[@]} (see $out_dir/roots.txt)"

# Paths on stdin that exist. Their list is later passed as arguments, not
# through xargs, which could split it over several invocations and so break
# the topological order of `--query --requisites`.
existing() { local path; while read -r path; do if [[ -e $path ]]; then echo "$path"; fi; done; }

# Every derivation that built a local output in the runtime closure, then the
# build graph of those, so build-time-only local outputs are included too.
nix path-info --recursive --json --json-format 1 "${roots[@]}" > "$out_dir/closure.json"
mapfile -t seeds < <(
    jq -r '.[] | select(. != null) | select(.ultimate and .ca == null and .deriver != null) | .deriver' \
        "$out_dir/closure.json" | sort -u | existing
)
if ((${#seeds[@]})); then
    nix-store --query --requisites --include-outputs "${seeds[@]}" | grep -v '\.drv$' \
        | nix path-info --stdin --json --json-format 1 > "$out_dir/build-outputs.json"
else
    echo '{}' > "$out_dir/build-outputs.json"
fi

# Local outputs whose deriver is gone, or was never recorded, cannot be checked.
jq -r 'to_entries[] | select(.value != null) | select(.value.ultimate and .value.ca == null)
       | "\(.value.deriver // "-")\t\(.key)"' \
    "$out_dir/closure.json" "$out_dir/build-outputs.json" | sort -u > "$out_dir/local-outputs.tsv"

# Dependencies first: `--query --requisites` prints in topological order.
mapfile -t candidates < <(cut -f1 "$out_dir/local-outputs.tsv" | grep '\.drv$' | sort -u | existing)
drv_order=()
if ((${#candidates[@]})); then
    mapfile -t drv_order < <(nix-store --query --requisites "${candidates[@]}" | grep '\.drv$')
fi
declare -A outputs_of=()
while IFS=$'\t' read -r drv output; do
    outputs_of[$drv]+="${outputs_of[$drv]:+,}$output"
done < "$out_dir/local-outputs.tsv"

declare -A local_nar=()
while IFS=$'\t' read -r path nar; do
    local_nar[$path]=$nar
done < <(jq -r 'to_entries[] | select(.value != null) | "\(.key)\t\(.value.narHash)"' \
    "$out_dir/closure.json" "$out_dir/build-outputs.json")

declare -A cache_has=() cache_nar=()
for cache in "${caches[@]}"; do
    echo "querying $cache"
    while IFS=$'\t' read -r path nar; do
        cache_has[$path]+="${cache_has[$path]:+,}${cache#https://}"
        # A cache match settles it, whatever the other caches say.
        if [[ $nar == "${local_nar[$path]-}" ]]; then
            cache_nar[$path]=match
        elif [[ ${cache_nar[$path]-} != match ]]; then
            cache_nar[$path]=differs
        fi
    done < <(
        cut -f2 "$out_dir/local-outputs.tsv" \
            | nix path-info --store "$cache" --stdin --json --json-format 1 2>/dev/null \
            | jq -r 'to_entries[] | select(.value != null) | "\(.key)\t\(.value.narHash)"' || true
    )
done

# Join per-output cache info into one field per derivation.
cache_info() {
    local field=$1 drv=$2 output values=()
    IFS=, read -ra outs <<< "${outputs_of[$drv]}"
    for output in "${outs[@]}"; do
        if [[ $field == has ]]; then values+=("${cache_has[$output]:-none}")
        else values+=("${cache_nar[$output]:--}"); fi
    done
    (IFS=';'; echo "${values[*]}")
}

declare -A done_drvs=() suspect=()
if [[ -s $results ]]; then
    while IFS=$'\t' read -r status drv _; do
        if [[ $status == status ]]; then continue; fi
        done_drvs[$drv]=1
        if [[ $status != identical ]]; then suspect[$drv]=1; fi
    done < "$results"
    echo "resuming: ${#done_drvs[@]} derivations already recorded"
else
    printf 'status\tderivation\toutputs\tcache\tcache_nar\tnote\tlog\n' > "$results"
fi

record() { # status drv note log
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "${outputs_of[$2]}" \
        "$(cache_info has "$2")" "$(cache_info nar "$2")" "$3" "$4" >> "$results"
    if [[ $1 != identical ]]; then suspect[$2]=1; fi
    printf '%-14s %s\n' "$1" "${2#/nix/store/}"
}

# Outputs whose deriver cannot be rebuilt.
while IFS=$'\t' read -r drv output; do
    if [[ ($drv != - && -e $drv) || ${done_drvs[$drv]-} ]]; then continue; fi
    done_drvs[$drv]=1
    if [[ $drv == - ]]; then note="no deriver recorded"; else note="derivation not in store"; fi
    record no-derivation "$drv" "$note" -
done < "$out_dir/local-outputs.tsv"

total=0
for drv in "${drv_order[@]}"; do if [[ ${outputs_of[$drv]-} ]]; then ((++total)); fi; done
echo "derivations to check: $total"

for drv in "${drv_order[@]}"; do
    [[ ${outputs_of[$drv]-} && ! ${done_drvs[$drv]-} ]] || continue
    done_drvs[$drv]=1

    log=$out_dir/logs/${drv#/nix/store/}.log
    rc=0
    nix-store --realise --check --keep-failed "$drv" > "$log" 2>&1 || rc=$?

    # Going through the daemon, Nix 2.34 exits 1 for all of these, rather
    # than with the 1xx bitmask nix-store-realise(1) documents, so the log is
    # what tells them apart.
    if ((rc == 0)); then
        status=identical
    elif grep -q 'may not be deterministic' "$log"; then
        status=differs
    elif grep -qE "builder for '.*' failed|timed out|hash mismatch" "$log"; then
        status=build-failed
    else
        status=error
    fi

    note=
    if ((${#suspect[@]})); then
        suspect_inputs=()
        while read -r input; do
            if [[ $input != "$drv" && ${suspect[$input]-} ]]; then
                suspect_inputs+=("${input#/nix/store/}")
            fi
        done < <(nix-store --query --requisites "$drv" | grep '\.drv$')
        if ((${#suspect_inputs[@]})); then
            note="suspect inputs: ${suspect_inputs[*]}"
            if [[ $status == identical ]]; then status=inconclusive; fi
        fi
    fi
    if [[ $status == differs ]]; then
        IFS=, read -ra outs <<< "${outputs_of[$drv]}"
        kept=()
        for output in "${outs[@]}"; do if [[ -e $output.check ]]; then kept+=("$output.check"); fi; done
        note+="${note:+; }kept: ${kept[*]:-none}"
    fi
    record "$status" "$drv" "$note" "$log"
done

{
    echo "roots: ${#roots[@]} (roots.txt)"
    jq -r '
        [.[] | select(.ultimate | not) | select(.signatures | length > 0)] as $signed
        | [.[] | select(.ca != null)] as $ca
        | "runtime closure: \(length) paths, \($signed | length) substituted and signed, \($ca | length) content-addressed;"
          + " covered by `nix store verify --all --no-trust`, not rebuilt here"' "$out_dir/closure.json"
    echo
    echo "derivations by status:"
    tail -n +2 "$results" | cut -f1 | sort | uniq -c | sort -rn
    echo
    echo "local outputs a cache also has: $(printf '%s\n' "${!cache_has[@]}" | grep -c . || true)," \
        "of which the cache's NAR hash differs: $(printf '%s\n' "${cache_nar[@]}" | grep -c '^differs$' || true)"
    echo
    echo "not identical:"
    tail -n +2 "$results" | awk -F'\t' '$1 != "identical"' | sort
} > "$out_dir/summary.txt"

echo
cat "$out_dir/summary.txt"
