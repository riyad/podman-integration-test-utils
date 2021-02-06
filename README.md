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

NOTE: beware that _run_test_suite.sh_ will run Git commands on the specified
  Podman repo. You may want to have a separate clone for these scripts to work in.

If you've updated the paths run the setup script.

```shell
./setup_test_suite.sh
```

This will create a pytest configuration filemore suited to our needs and setup a
Python virtualenv for docker-py and install its dependencies into it.


## Usage

### Running test suite

The simplest way to run the test suite is to call the `run_test_suite.sh` script
giving it a Git branch or commit id.

```shell
./run_test_suite.sh master
```

It will checkout the specified branch or commit, build the _podman_ binary,
start the API server run the tests against it and then stop the server again.

It will produce 3 files:
- _pyptest_integration_dev_<commit date>_<commit id>_<comment>.pytest.log_: the pytest output
- _pyptest_integration_dev_<commit date>_<commit id>_<comment>.podman-info.json_: a
    capture of `podman info`
- _pyptest_integration_dev_<commit date>_<commit id>_<comment>.server.log_: the server logs

NOTE: to ensure a "clean" environment _run_test_suite.sh_ will preemptively
remove containers, kill "lingering" Podman processes and do a `git checkout` in
the Podman repo. Use the options listed with `./run_test_suit.sh --help` to prevent
the script from doing any of these things.

#### Running individual tests

You can pass additional arguments to _run_test_suite.sh_ which get forwarded to
pytest (see [pytest's commmand-line flags](https://docs.pytest.org/en/stable/reference.html#command-line-flags)):

```shell
./un_test_suite.sh master -k test_create_with_host_pid_mode
```

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
