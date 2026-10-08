#!/usr/bin/env bash
# Build the installed upstream release with a less noisy tmux footer budget.
# Usage: bash packages/agent-deck/build.sh /absolute/path/to/output-binary
# Upstream updates replace this local patch; rerun to restore the pinned build.
set -euo pipefail

if [[ $# != 1 || $1 != /* ]]; then
  echo "Usage: $0 /absolute/path/to/output-binary" >&2
  exit 2
fi
output=$1
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_revision=34cf3690c39614f33aa683e8f8a280322320de59
source_sha256=36ad6af62d01b906450e317950a9f0aefbe0ee27c585ef15ba22d11841092303
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/agent-deck-health.XXXXXX")
trap 'rm -rf -- "$build_dir"' EXIT

curl --fail --silent --show-error --location \
  "https://codeload.github.com/asheshgoplani/agent-deck/tar.gz/$source_revision" \
  --output "$build_dir/source.tar.gz"
printf '%s  %s\n' "$source_sha256" "$build_dir/source.tar.gz" | shasum -a 256 --check
mkdir "$build_dir/source"
tar -xzf "$build_dir/source.tar.gz" --strip-components=1 -C "$build_dir/source"
cd "$build_dir/source"
patch -p1 < "$script_dir/tmux-health-ui-budget.patch"
go test ./internal/health -count=1
go test ./internal/ui -run '^TestRuntimeHealth' -count=1
CGO_ENABLED=0 go build -trimpath \
  -ldflags '-s -w -X main.Version=1.16.26+tmux-health' \
  -o "$build_dir/agent-deck" ./cmd/agent-deck
"$build_dir/agent-deck" version

# Replace atomically; a running TUI keeps its original executable until restart.
if [[ -e $output ]]; then
  cp -p -- "$output" "$output.before-tmux-health-$(date +%Y%m%d-%H%M%S)"
fi
install -m 755 "$build_dir/agent-deck" "$output.new-tmux-health"
mv -- "$output.new-tmux-health" "$output"
echo "Installed $output; restart the Agent Deck dashboard to apply."
