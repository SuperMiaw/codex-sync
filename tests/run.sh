#!/usr/bin/env bash
set -euo pipefail
test_dir=$(cd -- "$(dirname -- "$0")" && pwd -P)
for test_file in "$test_dir"/test-*.sh; do
	printf '\nRunning %s\n' "${test_file##*/}"
	bash "$test_file"
done
printf '\nAll behavior tests passed.\n'
