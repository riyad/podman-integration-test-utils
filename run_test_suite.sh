#!/bin/bash
#
# Author: Riyad Preukschas <riyad@informatik.uni-bremen.de>
# License: Mozilla Public License 2.0
# SPDX-License-Identifier: MPL-2.0
#
# Builds Podman starts an API server and runs the docker-py integration tests
# against it. It collects engine information, test and server logs for each run.


set -euo pipefail

# NOTE: change these to match your environment
readonly PODMAN_REPO_PATH=~/src/podman
readonly DOCKER_PY_REPO_PATH=~/src/docker-py
readonly DOCKER_PY_VIRTUALENV_PATH="${DOCKER_PY_REPO_PATH}/venv"
readonly DOCKER_PY_LOGS_PATH="${DOCKER_PY_REPO_PATH}/logs"


readonly PODMAN_BIN="${PODMAN_BIN:-./bin/podman}"
readonly PODMAN_SOCKET_PATH="unix:${PODMAN_REPO_PATH}/docker-py-test.sock"
export DOCKER_HOST="${PODMAN_SOCKET_PATH}"


function usage() {
  echo "Usage: $0 <SUITE_TAG> [OPTIONS] [<PYTEST_ARGS ...>]"
  echo "       Builds Podman starts an API server and runs the docker-py"
  echo "       integration tests against it. It collects engine information,"
  echo "       test and server logs for each run."
  echo ""
  echo "OPTIONS"
  echo " -c,--checkout \"<BRANCH>\"  Podman branch/commit to checkout. Set this to"
  echo "                             '' to prevent doing acheckout. (default: master)"
  echo " -m,--message \"<MESSAGE>\"  Message/comment/note to attach to this test run"
  echo "               --no-cleanup  Do not stop and remove Podman and Buildah"
  echo "                             containers before running the tests"
  echo "                  --no-kill  Do not kill all podman processes before"
  echo "                             running the tests"
  echo ""
  echo "ENVIRONMENT VARIABLES"
  echo "         PODMAN_BIN  Use this binary as the podman command (default: ./bin/podman)"
}


parse_command_line_args() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  fi

  OPT_CHECKOUT_PODMAN='master'
  OPT_CLEANUP_CONTAINERS='1'
  OPT_KILL_PODMAN='1'
  OPT_MESSAGE=''
  OPT_SUITE_TAG="${1}"
  shift
  OPT_PYTEST_ARGS=''

  while [[ $# -gt 0 ]]
  do
    case "$1" in
      -h|--help)
        usage
        exit 1
        ;;
      -c|--checkout)
        readonly OPT_CHECKOUT_PODMAN="$2"
        shift
        ;;
      -m|--message)
        readonly OPT_MESSAGE="$2"
        shift
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
  if [[ -n "${OPT_CHECKOUT_PODMAN}" ]]; then
    git checkout "${OPT_SUITE_TAG}"
  fi

  local PODMAN_COMMIT_ID="$(git log -1 --format=%H)"
  local PODMAN_COMMIT_DATE="$(git log -1 --format=%cI)"
  local LOG_BASE_NAME="${DOCKER_PY_LOGS_PATH}/pytest_integration_${OPT_SUITE_TAG}_${PODMAN_COMMIT_DATE}_${PODMAN_COMMIT_ID}"

  if [[ -n "${OPT_MESSAGE}" ]]; then
    LOG_BASE_NAME="${LOG_BASE_NAME}_${OPT_MESSAGE}"
  fi

  make -j "$(nproc)" podman

  "${PODMAN_BIN}" info --format json > "${LOG_BASE_NAME}.podman-info.json"

  if [[ -n "${OPT_CLEANUP_CONTAINERS}" ]]; then
    "${PODMAN_BIN}" stop -a
    "${PODMAN_BIN}" rm -a
    buildah rm -a
  fi

  if [[ -n "${OPT_KILL_PODMAN}" ]]; then
    killall -r 'podman.*'
  fi

  "${PODMAN_BIN}" system service -t 0 "${PODMAN_SOCKET_PATH}" > "${LOG_BASE_NAME}.server.log" 2>&1 &

  cd "${DOCKER_PY_REPO_PATH}"
  source "${DOCKER_PY_VIRTUALENV_PATH}/bin/activate"
  pytest -c pytest_podman_apiv2.ini "${OPT_PYTEST_ARGS[@]}" | tee "${LOG_BASE_NAME}.pytest.log"

  # kill backgrounbd jobs (i.e. Podman API server)
  kill "$(jobs -p)"
}


main "${@}"
