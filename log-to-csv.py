#!/usr/bin/env python3

import csv
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


def main():
    csv_writer = csv.DictWriter(sys.stdout, fieldnames=EMPTY_TEST.keys())
    csv_writer.writeheader()

    for file_arg in sys.argv[1:]:
        file_path = pathlib.Path(file_arg)
        file_name_parts = file_path.name.lstrip('pytest_integration_').rstrip('.log').split('_')

        test_file_data = EMPTY_TEST.copy()

        i = 0

        test_file_data['podman_version'] = file_name_parts[i]
        i += 1

        if test_file_data['podman_version'].endswith('-dev'):
            test_file_data['commit_date'] = file_name_parts[i]
            test_file_data['commit_id'] = file_name_parts[i+1]
            i += 2
        else:
            test_file_data['commit_date'] = None
            test_file_data['commit_id'] = None

        test_file_data['runtime'] = file_name_parts[i]
        i += 1

        test_file_data['comment'] = '_'.join(file_name_parts[i:])

        test_file_data['_test_session'] = "{} {} {} {} {}".format(
            test_file_data['podman_version'],
            test_file_data['commit_date'],
            test_file_data['commit_id'],
            test_file_data['runtime'],
            test_file_data['comment'],
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

                        test = test_file_data.copy()

                        try:
                            file_class_test, result, _ = line.split(' ', maxsplit=2)
                            test['_test_name'] = file_class_test
                            test['result'] = result
                        except ValueError:
                            file_class_test, _ = line.split(' ', maxsplit=1)

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
