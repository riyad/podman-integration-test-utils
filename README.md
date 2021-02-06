Podman Integration Test Utilities
=================================

A collection of scripts to help run [docker-py's](https://github.com/docker/docker-py)
integration tests against [Podman's](https://github.com/containers/podman) Docker
compatible API and to collect and analyze the results.


## Installation

```shell
# clone this repository
git clone https://github.com/riyad/podman-integration-test-utils.git
cd podman-integration-test-utils
# create venv and install dependencies
python3 -m venv venv
source ./venv/bin/activate
pip install -U -r requirements.txt
```

Update the variables at the top of the _setup_test_suite.sh_ and
_run_test_suite.sh_ to point to the directories you've cloned
[Podman](https://github.com/containers/podman) and
[docker-py](https://github.com/docker/docker-py) to.

WARNING: beware that _run_test_suite.sh_ will run Git commands on the specified
Podman repo. You may want to have a separate clone for these scripts to work in.

After you've set the repo paths run the setup script.

```shell
./setup_test_suite.sh
```

This will create a pytest configuration file more suited to our needs and setup
a Python virtualenv for docker-py and install its dependencies into it.


## Usage

### Running the test suite

The simplest way to run the test suite is to call the `run_test_suite.sh` script
giving it a Git branch or commit id.

```shell
./run_test_suite.sh dev
```

It will checkout the specified branch or commit, build the _podman_ binary,
start the API server run the tests against it and then stop the server again.

It will produce 3 files:
- `pyptest_integration_<suite tag>_<commit date>_<commit id>_<comment>.pytest.log`: the pytest output
- `pyptest_integration_<suite tag>_<commit date>_<commit id>_<comment>.podman-info.json`: a
    capture of `podman info`
- `pyptest_integration_<suite tag>_<commit date>_<commit id>_<comment>.server.log`: the server logs

`<suite tag>` is meant to differentiate multiple runs of the test suite on the
same commit (e.g. running with different runtimes). Most sensible is to use the
Podman version (e.g. "3.0.0-dev")

`<commit date>` and `<commit id>` are automatically determined from the checked-out
commit in the Podman repo. They can be empty.

`<comment>` is whatever you provided with the `--message` option.

WARNING: to ensure a "clean" environment _run_test_suite.sh_ will preemptively
remove containers, kill "lingering" Podman processes and do a `git checkout` in
the Podman repo. Use the options listed with `./run_test_suit.sh --help` to prevent
the script from doing any of these things.

#### Running individual tests

You can pass additional arguments to _run_test_suite.sh_ which get forwarded to
pytest (see [pytest's commmand-line flags](https://docs.pytest.org/en/stable/reference.html#command-line-flags)):

```shell
./run_test_suite.sh drilldown -k test_create_with_host_pid_mode
```

#### Running tests against host Podman

You can use _run_test_suite.sh_ also to run it agains a system installed version
of Podman.

```shell
PODMAN_BIN=podman ./run_test_suite.sh 2.2.1 --checkout ''
```

NOTE: the commit id and commit date in the file names of the generated logs have
no meaning in this case.

### Rendering pytest logs into a HTML table

Once you've collected (even incomplete) logs you can turn them into a table
visualizing how individual test results compare between different test suite runs.

```shell
./log-to-csv.py path/to/pytest/logs/* | ./csv-to-html.py > index.html

```

### Converting pytest logs into a CSV file

You can also convert your pytest logs into a CSV file if you want to use other
tools for processing the test data.

```shell
./log-to-csv.py path/to/pytest/logs/* > all.csv

```


## Contact and Issues

Please, report all issues on our issue tracker on GitHub: https://github.com/riyad/podman-integration-test-utils/issues
