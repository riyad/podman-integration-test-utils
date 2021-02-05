#!/usr/bin/env python3

import csv
import json
import pathlib
import sys


EMPTY_TEST = dict(
    commit_date=None,
    commit_id=None,
    podman_version=None,
    runtime=None,
    test_file=None,
    test_class=None,
    test_method=None,
    result=None,
    comment=None,
    _test_name=None,
    _test_session=None,
    _unsupported=None,
)
UNSUPPORTED_TEST_CLASSES = ['ConfigAPITest', 'NodesTest', 'SecretAPITest', 'ServiceTest', 'SwarmTest', 'TestStore']
UNSUPPORTED_TEST_METHODS = ['test_create_inspect_network_with_scope', 'test_create_network_attachable' , 'test_create_network_ingress']


# str.removeprefix only supported for Python >= 3.9
# see https://docs.python.org/3/library/stdtypes.html#str.removeprefix
def removeprefix(text, prefix):
    if prefix and text.startswith(prefix):
        return text[len(prefix):]
    return text

# str.removesuffix only supported for Python >= 3.9
# see https://docs.python.org/3/library/stdtypes.html#str.removesuffix
def removesuffix(text, suffix):
    if suffix and text.endswith(suffix):
        return text[:-len(suffix)]
    return text


def main():
    csv_writer = csv.DictWriter(sys.stdout, fieldnames=EMPTY_TEST.keys())
    csv_writer.writeheader()

    for file_arg in sys.argv[1:]:
        file_path = pathlib.Path(file_arg)

        if not file_path.name.endswith('.pytest.log'):
            continue

        test_suite_data = EMPTY_TEST.copy()

        podman_info_file = file_path.parent.joinpath(
            removesuffix(file_path.name, '.pytest.log') + '.podman-info.json')

        pytest_log_file_name_parts = removesuffix(removeprefix(file_path.name, 'pytest_integration_'), '.pytest.log').split('_')
        i = 0
        if podman_info_file.exists():
            # file name format:  pytest_integration_<branch/release>_<commit date>_<commit id>[_<comments ...>].pytest.log
            with podman_info_file.open('rt') as f:
                podman_info_data = json.load(f)

            # skip "release/branch"
            i += 1

            test_suite_data['podman_version'] = podman_info_data['version']['Version']
            test_suite_data['runtime'] = podman_info_data['host']['ociRuntime']['name']

            if 'dev' in test_suite_data['podman_version']:
                test_suite_data['commit_date'] = pytest_log_file_name_parts[i]
                test_suite_data['commit_id'] = pytest_log_file_name_parts[i+1]
                i += 2
            else:
                test_suite_data['commit_date'] = None
                test_suite_data['commit_id'] = None
        else:
            # file name format:  pytest_integration_<podman version>_<commit date>_<commit id>_<runtime>[_<comments ...>].pytest.log
            test_suite_data['podman_version'] = pytest_log_file_name_parts[i]
            i += 1

            if 'dev' in test_suite_data['podman_version']:
                test_suite_data['commit_date'] = pytest_log_file_name_parts[i]
                test_suite_data['commit_id'] = pytest_log_file_name_parts[i+1]
                i += 2
            else:
                test_suite_data['commit_date'] = None
                test_suite_data['commit_id'] = None

            test_suite_data['runtime'] = pytest_log_file_name_parts[i]
            i += 1

        test_suite_data['comment'] = '_'.join(pytest_log_file_name_parts[i:])

        test_suite_data['_test_session'] = "{} {} {} {} {}".format(
            test_suite_data['podman_version'],
            test_suite_data['commit_date'],
            test_suite_data['commit_id'],
            test_suite_data['runtime'],
            test_suite_data['comment'],
        )

        with file_path.open('rt') as f:
            is_test_section = False
            do_parse = False
            for line in f:
                if not is_test_section:
                    if '===== test session starts =====' in line:
                        is_test_section = True
                        continue
                else:
                    if '=====' in line:
                        is_test_section = False
                        do_parse = False
                        break

                    if not do_parse:
                        # first empty line, test session section begins
                        if line == "\n":
                            do_parse = True
                            continue
                    else:
                        if line == "\n":
                            # second empty line, test session section ends
                            do_parse = False
                            break

                        test = test_suite_data.copy()

                        try:
                            file_class_test, result, _ = line.split(' ', maxsplit=2)
                            test['result'] = result
                        except ValueError:
                            file_class_test, _ = line.split(' ', maxsplit=1)
                        test['_test_name'] = file_class_test

                        try:
                            test_file, test_method = file_class_test.split('::', maxsplit=1)
                            if '::' in test_method:
                                test_class, test_method = test_method.split('::')
                            test['test_file'] = test_file
                            test['test_class'] = test_class
                            test['test_method'] = test_method
                        except ValueError:
                            pass

                        test['_unsupported'] = (
                            test['test_class'] in UNSUPPORTED_TEST_CLASSES \
                            or test['test_method'] in UNSUPPORTED_TEST_METHODS)

                        csv_writer.writerow(test)


if __name__ == '__main__':
    main()
