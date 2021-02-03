#!/bin/bash
#
# Author: Riyad Preukschas <riyad@informatik.uni-bremen.de>
# License: Mozilla Public License 2.0
# SPDX-License-Identifier: MPL-2.0
#
# Builds Podman at <PODMAN_COMMIT_ID> and runs the docker-py


set -euo pipefail

readonly PODMAN_REPO_PATH=~/src/podman
readonly PODMAN_SOCKET_PATH="unix:${PODMAN_REPO_PATH}/docker-py-test.sock"
readonly DOCKER_PY_REPO_PATH=~/src/docker-py
readonly DOCKER_PY_VIRTUALENV_PATH="${DOCKER_PY_REPO_PATH}/venv"
readonly DOCKER_PY_LOGS_PATH="${DOCKER_PY_REPO_PATH}/logs"

export DOCKER_HOST="${PODMAN_SOCKET_PATH}"


function usage() {
  echo "Usage: $0 <PODMAN_COMMIT_ID> [<PYTEST_ARGS ...>]"
  echo "       Builds Podman at <PODMAN_COMMIT_ID> starts an API server and runs"
  echo "       the docker-py integration tests against it."
}


function main() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  fi

  local OPT_PODMAN_COMMIT_ID=$1
  shift

  cd "${PODMAN_REPO_PATH}"
  git checkout "${OPT_PODMAN_COMMIT_ID}"

  local PODMAN_COMMIT_ID="$(git log -1 --format=%H)"
  local PODMAN_COMMIT_DATE="$(git log -1 --format=%cI)"
  local LOG_BASE_NAME="${DOCKER_PY_LOGS_PATH}/pytest_integration_${PODMAN_COMMIT_DATE}_${PODMAN_COMMIT_ID}"

  make -j "$(nproc)" podman

  ./bin/podman info --format json > "${LOG_BASE_NAME}.podman-info.json"

  # TODO: put behind flag
  ./bin/podman rm -a

  # TODO: put behind flag
  killall -r 'podman.*'

  # somehow the output can't be redirected
  ./bin/podman system service -t 0 "${PODMAN_SOCKET_PATH}" 2>&1 > "${LOG_BASE_NAME}.server.log" &

  cd "${DOCKER_PY_REPO_PATH}"
  source "${DOCKER_PY_VIRTUALENV_PATH}/bin/activate"
  pytest -c pytest_podman_apiv2.ini "${@}" | tee "${LOG_BASE_NAME}.pytest.log"

  # kill backgrounbd jobs (i.e. podman server)
  kill "$(jobs -p)"
}


main "${@}"
