# arr-sync CONFIG: apply the wiring described in CONFIG (JSON, rendered by
# arr-sync.nix) through the *arrs' REST APIs.
config=$1

declare -A api
while IFS=$'\t' read -r service url; do
  api[$service]=$url
done < <(jq -r '.services | to_entries[] | [.key, .value.api] | @tsv' "$config")

# Secrets reach jq through the environment and curl through a file, never
# argv, which any local user can read.
CREDS=$(
  for file in "$CREDENTIALS_DIRECTORY"/*; do
    jq -n --arg name "${file##*/}" --rawfile value "$file" '{($name): ($value | rtrimstr("\n"))}'
  done | jq -s add
)
export CREDS

# request SERVICE METHOD PATH, body (if any) on stdin. GETs retry while the
# service is still starting up; writes don't, to avoid duplicates.
request() {
  local service=$1 method=$2 path=$3
  local args=(--silent --show-error --fail-with-body
    --variable "key@$CREDENTIALS_DIRECTORY/$service"
    --expand-header 'X-Api-Key: {{key:trim}}'
    --request "$method" "${api[$service]}/$path")
  if [[ $method == GET ]]; then
    args+=(--retry 60 --retry-connrefused --retry-delay 2)
  else
    args+=(--header 'Content-Type: application/json' --data-binary @-)
  fi
  local response
  response=$(curl "${args[@]}") || { echo "$response" >&2; return 1; }
  printf '%s' "$response"
}

# The *arrs test a download client's or proxy's connection on every save and
# reject it if the target isn't answering yet. Any HTTP response will do.
wait_for() {
  curl --silent --output /dev/null --retry 60 --retry-connrefused --retry-delay 2 "$1"
}

tag_id() {
  local service=$1 label=$2 id
  id=$(request "$service" GET tag | jq --arg label "$label" '.[] | select(.label == $label) | .id')
  [[ -n $id ]] || id=$(jq -n --arg label "$label" '{$label}' | request "$service" POST tag | jq .id)
  echo "$id"
}

# upsert SERVICE RESOURCE SPEC: start from the entry with the spec's name, or
# from the implementation's schema, then overlay the spec's top-level keys and
# the values of the fields it names. Tag labels become ids, created as needed.
upsert() {
  local service=$1 resource=$2 spec=$3 current method path label ids=()
  mapfile -t labels < <(jq -r '.tags // [] | .[]' <<<"$spec")
  for label in "${labels[@]}"; do
    ids+=("$(tag_id "$service" "$label")")
  done
  if ((${#ids[@]})); then
    spec=$(jq -c '.tags = ($ARGS.positional | map(tonumber))' --args "${ids[@]}" <<<"$spec")
  fi

  current=$(request "$service" GET "$resource" |
    jq -c --argjson spec "$spec" '.[] | select(.name == $spec.name)')
  if [[ -n $current ]]; then
    method=PUT path="$resource/$(jq .id <<<"$current")"
  else
    current=$(request "$service" GET "$resource/schema" |
      jq -c --argjson spec "$spec" '.[] | select(.implementation == $spec.implementation)')
    [[ -n $current ]] || { echo "$service: no $resource implementation in $spec" >&2; exit 1; }
    method=POST path=$resource
  fi
  jq --argjson spec "$spec" '
    (env.CREDS | fromjson) as $creds
    | ($spec | walk(if type == "object" and has("credential") then $creds[.credential] else . end)) as $spec
    | . + ($spec | del(.fields))
    | .fields |= map(.name as $name | if $spec.fields | has($name) then .value = $spec.fields[$name] else . end)
  ' <<<"$current" | request "$service" "$method" "$path" >/dev/null
  echo "$service: $method $resource '$(jq -r .name <<<"$spec")'"
}

root_folder() {
  local service=$1 path=$2
  request "$service" GET rootfolder | jq -e --arg path "$path" 'any(.path == $path)' >/dev/null ||
    jq -n --arg path "$path" '{$path}' | request "$service" POST rootfolder >/dev/null
}

mapfile -t urls < <(jq -r '.waitFor[]' "$config")
for url in "${urls[@]}"; do
  wait_for "$url"
done

for service in "${!api[@]}"; do
  mapfile -t resources < <(jq -r --arg service "$service" '.services[$service] | del(.api, .rootfolder) | keys[]' "$config")
  for resource in "${resources[@]}"; do
    mapfile -t specs < <(jq -c --arg service "$service" --arg resource "$resource" '.services[$service][$resource][]' "$config")
    for spec in "${specs[@]}"; do
      upsert "$service" "$resource" "$spec"
    done
  done

  mapfile -t folders < <(jq -r --arg service "$service" '.services[$service].rootfolder // [] | .[]' "$config")
  for folder in "${folders[@]}"; do
    root_folder "$service" "$folder"
  done
done
