#!/usr/bin/env bash
# Validate and test every module that has tests, the same way for every Terraform version CI uses.
#
# Providers: no module commits a .terraform.lock.hcl (consumers own the lock), so every `init`
# would re-download the ~100 MB google provider. A plugin cache alone does not help without a lock
# file to check the cached copy against, so the cache is paired with
# TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE; that only loosens the throwaway lock files this
# script writes. Each init gets a timeout and 3 attempts; a timeout may leave a half-extracted
# cache entry, so that case wipes the cache before retrying.
#
# Run from the repo root. Honours TF_PLUGIN_CACHE_DIR (default: a temp dir).
set -euo pipefail
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$(mktemp -d)}"
export TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE=true
mkdir -p "$TF_PLUGIN_CACHE_DIR"

init_module() {
  local attempt rc
  for attempt in 1 2 3; do
    rc=0
    timeout -k 15 180 terraform -chdir="$1" init -backend=false -input=false || rc=$?
    if [ "$rc" -eq 0 ]; then return 0; fi
    echo "::warning::terraform init in $1 failed (rc=$rc, attempt $attempt/3)"
    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
      rm -rf "$TF_PLUGIN_CACHE_DIR" "$1/.terraform"
      mkdir -p "$TF_PLUGIN_CACHE_DIR"
    fi
  done
  return 1
}

dirs=$(find modules -name '*.tftest.hcl' | sed -E 's#/tests/.*##' | sort -u)
# An empty discovery would make the loop below vacuously pass.
if [ -z "$dirs" ]; then
  echo "::error::No modules with tests discovered; refusing to report success."
  exit 1
fi
# Every module must have tests, or it is silently skipped.
for m in modules/*/; do
  printf '%s\n' "$dirs" | grep -qx "${m%/}" || { echo "::error::${m%/} has no tests/*.tftest.hcl"; exit 1; }
done

for d in $dirs; do
  echo "::group::$d"
  init_module "$d"
  terraform -chdir="$d" validate
  terraform -chdir="$d" test
  echo "::endgroup::"
done
