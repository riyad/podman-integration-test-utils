#!/bin/bash
#
# Author: Riyad Preukschas <riyad@informatik.uni-bremen.de>
# License: Mozilla Public License 2.0
# SPDX-License-Identifier: MPL-2.0
#
# Builds Podman at <PODMAN_VERSION> and runs the docker-py integration tests
# against it.


set -euo pipefail

readonly PODMAN_REPO_PATH=~/src/podman
readonly PODMAN_SOCKET_PATH="unix:${PODMAN_REPO_PATH}/docker-py-test.sock"
readonly DOCKER_PY_REPO_PATH=~/src/docker-py
readonly DOCKER_PY_VIRTUALENV_PATH="${DOCKER_PY_REPO_PATH}/venv"
readonly DOCKER_PY_LOGS_PATH="${DOCKER_PY_REPO_PATH}/logs"

export DOCKER_HOST="${PODMAN_SOCKET_PATH}"


function usage() {
  echo "Usage: $0 <PODMAN_VERSION> [OPTIONS] [<PYTEST_ARGS ...>]"
  echo "       Builds Podman at <PODMAN_VERSION> starts an API server and runs"
  echo "       the docker-py integration tests against it."
  echo ""
  echo "OPTIONS"
  echo " -m,--message \"<MESSAGE>\"  Message/comment/note to attach to this test run"
  echo "              --no-checkout  Do not do a `git checkout` in the Podman repo"
  echo "                             containers before running the tests"
  echo "               --no-cleanup  Do not stop and remove Podman and Buildah"
  echo "                             containers before running the tests"
  echo "                  --no-kill  Do not kill all podman processes before"
  echo "                             running the tests"
}


parse_command_line_args() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  fi

  OPT_CHECKOUT_CONTAINERS='1'
  OPT_CLEANUP_CONTAINERS='1'
  OPT_KILL_PODMAN='1'
  OPT_MESSAGE=''
  OPT_PODMAN_VERSION="$1"
  shift
  OPT_PYTEST_ARGS=''

  while [[ $# -gt 0 ]]
  do
    case "$1" in
      -h|--help)
        usage
        exit 1
        ;;
      -m|--message)
        readonly OPT_MESSAGE="$2"
        shift
        ;;
      --no-checkout)
        readonly OPT_CHECKOUT_CONTAINERS=''
        ;;
      --no-cleanup)
        readonly OPT_CLEANUP_CONTAINERS=''
        ;;
      --no-kill)
        readonly OPT_KILL_PODMAN=''
        ;;
      *)
        # the rest of the arguments are for pytest
        break
      ;;
    esac
    shift
  done

  readonly OPT_PYTEST_ARGS=( "${@}" )
}


function main() {
  parse_command_line_args "$@"

  cd "${PODMAN_REPO_PATH}"
  if [[ -n "${OPT_CHECKOUT_CONTAINERS}" ]]; then
    git checkout "${OPT_PODMAN_VERSION}"
  fi

  local PODMAN_COMMIT_ID="$(git log -1 --format=%H)"
  local PODMAN_COMMIT_DATE="$(git log -1 --format=%cI)"
  local LOG_BASE_NAME="${DOCKER_PY_LOGS_PATH}/pytest_integration_dev_${PODMAN_COMMIT_DATE}_${PODMAN_COMMIT_ID}"

  if [[ -n "${OPT_MESSAGE}" ]]; then
    LOG_BASE_NAME="${LOG_BASE_NAME}_${OPT_MESSAGE}"
  fi

  make -j "$(nproc)" podman

  ./bin/podman info --format json > "${LOG_BASE_NAME}.podman-info.json"

  if [[ -n "${OPT_CLEANUP_CONTAINERS}" ]]; then
    ./bin/podman stop -a
    ./bin/podman rm -a
    buildah rm -a
  fi

  if [[ -n "${OPT_KILL_PODMAN}" ]]; then
    killall -r 'podman.*'
  fi

  ./bin/podman system service -t 0 "${PODMAN_SOCKET_PATH}" > "${LOG_BASE_NAME}.server.log" 2>&1 &

  cd "${DOCKER_PY_REPO_PATH}"
  source "${DOCKER_PY_VIRTUALENV_PATH}/bin/activate"
  pytest -c pytest_podman_apiv2.ini "${OPT_PYTEST_ARGS[@]}" | tee "${LOG_BASE_NAME}.pytest.log"

  # kill backgrounbd jobs (i.e. Podman API server)
  kill "$(jobs -p)"
}


main "${@}"
