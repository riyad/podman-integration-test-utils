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
readonly PODMAN_REPO_PATH="${PODMAN_REPO_PATH:-$HOME/src/podman}"
readonly DOCKER_PY_REPO_PATH="${DOCKER_PY_REPO_PATH:-$HOME/src/docker-py}"
readonly DOCKER_PY_VENV_PATH="${DOCKER_PY_VENV_PATH:-$HOME/.virtualenvs/docker-py}"
readonly LOGS_PATH="${LOGS_PATH:-${DOCKER_PY_REPO_PATH}/logs}"
readonly PODMAN_BIN="${PODMAN_BIN:-${PODMAN_REPO_PATH}/bin/podman}"
readonly PODMAN_SOCKET_PATH="${PODMAN_SOCKET_PATH:-unix:${PODMAN_REPO_PATH}/docker-py-test.sock}"
readonly BUILDAH_BIN="$(command -v buildah)"

export DOCKER_HOST="${DOCKER_HOST:-${PODMAN_SOCKET_PATH}}"


function usage() {
  echo "Usage: $0 <SUITE_TAG> [OPTIONS] [<PYTEST_ARGS ...>]"
  echo "       Builds Podman starts an API server and runs the docker-py"
  echo "       integration tests against it. It collects engine information,"
  echo "       test and server logs for each run."
  echo ""
  echo "OPTIONS"
  echo " -c,--checkout \"<BRANCH>\"  Podman branch/commit to checkout. Set this to"
  echo "                             '' to prevent doing acheckout. (default: main)"
  echo " -m,--message \"<MESSAGE>\"  Message/comment/note to attach to this test run"
  echo "               --no-cleanup  Do not stop and remove Podman and Buildah"
  echo "                             containers before running the tests"
  echo "                  --no-kill  Do not kill all podman processes before"
  echo "                             running the tests"
  echo "                  -h,--help  Display this help text and exit"
  echo ""
  echo "ENVIRONMENT VARIABLES"
  echo "    PODMAN_REPO_PATH  Directory where your podman source code lives"
  echo "                      (default: ~/src/podman)"
  echo " DOCKER_PY_REPO_PATH  Directory where your docker-py source code lives"
  echo "                      (default: ~/src/docker-py)"
  echo " DOCKER_PY_VENV_PATH  Directory where your Python virtual env for docker-py"
  echo "                      lives (default: ~/.virtualenvs/docker-py)"
  echo "           LOGS_PATH  Directory where you want logs from test suites saved"
  echo "                      (default: \$DOCKER_PY_REPO_PATH/logs)"
  echo "          PODMAN_BIN  Use this binary as the podman command (default: ./bin/podman)"
  echo "  PODMAN_SOCKET_PATH  Use this as the socket path for the API server"
  echo "                      (default: unix:${PODMAN_REPO_PATH}/docker-py-test.sock)"
}


parse_command_line_args() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  elif [[ $# -eq 1 && ( "$1" = '-h' || "$1" = '--help' ) ]]; then
    usage
    exit 0
  fi

  OPT_CHECKOUT_PODMAN='main'
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
        exit 0
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
    git checkout "${OPT_CHECKOUT_PODMAN}"
    local PODMAN_COMMIT_ID="$(git log -1 --format=%H)"
    local PODMAN_COMMIT_DATE="$(git log -1 --format=%cI)"
  fi

  local LOG_BASE_NAME="${LOGS_PATH}/pytest_integration_${OPT_SUITE_TAG}_${PODMAN_COMMIT_DATE:-}_${PODMAN_COMMIT_ID:-}"

  if [[ -n "${OPT_MESSAGE}" ]]; then
    LOG_BASE_NAME="${LOG_BASE_NAME}_${OPT_MESSAGE}"
  fi

  make -j "$(nproc)" podman

  if [[ -n "${OPT_CLEANUP_CONTAINERS}" ]]; then
    echo "Cleaning up ..."
    "${PODMAN_BIN}" stop -a
    "${PODMAN_BIN}" rm -a
    [[ -x "${BUILDAH_BIN}" ]] && "${BUILDAH_BIN}" rm -a
  fi

  if [[ -n "${OPT_KILL_PODMAN}" ]]; then
    killall -r 'podman.*' || true
  fi

  "${PODMAN_BIN}" info --format json > "${LOG_BASE_NAME}.podman-info.json"

  echo "Starting API service ..."
  "${PODMAN_BIN}" system service -t 0 "${PODMAN_SOCKET_PATH}" > "${LOG_BASE_NAME}.server.log" 2>&1 &

  echo "Saving logs to \"${LOG_BASE_NAME}.pytest.log\" ..."
  cd "${DOCKER_PY_REPO_PATH}"
  source "${DOCKER_PY_VENV_PATH}/bin/activate"
  set +o pipefail  # disable pipefail
  # pytest returns with non-zero exit code when tests fail :/
  pytest -c pytest_podman_apiv2.ini --junitxml="${LOG_BASE_NAME}.junit.xml" "${OPT_PYTEST_ARGS[@]}" | tee "${LOG_BASE_NAME}.pytest.log"
  set +o pipefail  # re.enable pipefail
  echo "Saving logs to \"${LOG_BASE_NAME}.pytest.log\" ... Done."

  if [[ -n "${OPT_CLEANUP_CONTAINERS}" ]]; then
    echo "Cleaning up ..."
    [[ -x "${BUILDAH_BIN}" ]] && "${BUILDAH_BIN}" rm -a
    "${PODMAN_BIN}" rm -af
    set +e  # disable errexit
    # podman image rm ... returns non-zero exit code when any of the images don't exist
    # we could use --ignore for podman versions > 3.4?!?
    "${PODMAN_BIN}" image rm \
      localhost/docker-py-test-build-with-dockerignore \
      docker.io/library/docker-py-test-build-with-dockerignore \
      localhost/dup-txt-tag \
      docker.io/library/dup-txt-tag \
      localhost/isolation \
      docker.io/library/isolation \
      localhost/some-tag \
      docker.io/library/some-tag \
      189596303490 \
      sha256:e7b300aee9f9bf3433d32bc9305bfdd22183beb59d933b48d77ab56ba53a197a \
      f2a91732366c d1165f221234 feb5d9fea6a5
      # 189596303490 => quay.io/libpod/rootless-cni-infra
      # f2a91732366c,d1165f221234,feb5d9fea6a5 => docker.io/library/hello-world
    "${PODMAN_BIN}" image ls | grep dockerpytest | awk '{ print $1 }' | xargs "${PODMAN_BIN}" image rm
    "${PODMAN_BIN}" image prune -f
    "${PODMAN_BIN}" network ls | grep dockerpytest | awk '{ print $1 }' | xargs "${PODMAN_BIN}" network rm
    set -e  # re-enable errexit
  fi

  # kill backgrounbd jobs (i.e. Podman API server)
  kill "$(jobs -p)"

  echo "All done."
}


main "${@}"
