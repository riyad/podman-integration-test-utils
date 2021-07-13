#!/bin/bash
#
# Author: Riyad Preukschas <riyad@informatik.uni-bremen.de>
# License: Mozilla Public License 2.0
# SPDX-License-Identifier: MPL-2.0
#
# Sets up docker-py so we can run the tests.

set -euo pipefail

# NOTE: change these to match your environment
readonly PODMAN_REPO_PATH="${PODMAN_REPO_PATH:-$HOME/src/podman}"
readonly DOCKER_PY_REPO_PATH="${DOCKER_PY_REPO_PATH:-$HOME/src/docker-py}"
readonly DOCKER_PY_VENV_PATH="${DOCKER_PY_VENV_PATH:-$HOME/.virtualenvs/docker-py}"
readonly LOGS_PATH="${LOGS_PATH:-${DOCKER_PY_REPO_PATH}/logs}"


function main() {
  if [[ ! -d "${DOCKER_PY_REPO_PATH}" ]]; then
    echo "docker-py repo missing. Please clone it first."
    exit 1
  fi
  cd "${DOCKER_PY_REPO_PATH}"

  mkdir -p "${LOGS_PATH}"

  # create custom pytest config
  # see https://docs.pytest.org/en/stable/reference.html#ini-options-ref
  # see https://github.com/containers/podman/issues/5386#issuecomment-755298337
  if [[ ! -e pytest_podman_apiv2.ini ]]; then
    cat > pytest_podman_apiv2.ini <<-EOF
[pytest]
addopts =
    --tb=short
    -rxs
    --cache-clear
    -v
    -k 'not ConfigAPITest  and not LinkTest and not NodesTest and not PluginTest and not ServiceTest and not SwarmTest and not TestNetworksWithSwarm and not TestStore'

junit_suite_name = docker-py
junit_logging = all
junit_log_passing_tests = False

testpaths =
    tests/integration/
EOF
  fi

  # create virtualenv
  python3 -m venv "${DOCKER_PY_VIRTUALENV_PATH}"
  source "${DOCKER_PY_VIRTUALENV_PATH}/bin/activate"

  # install requiements in virtualenv
  pip install -U -r requirements.txt
  pip install -U -r test-requirements.txt
  # make sure at least pytest is up-to-date
  pip install -U pytest
}


main "${@}"
