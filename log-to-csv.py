#!/usr/bin/env python3

import csv
import pathlib
import sys


def main():
    csv_writer = csv.writer(sys.stdout)
    csv_writer.writerow(['commit_date', 'commit_id', 'podman_version', 'runtime', 'test_file', 'test_class', 'test_method', 'result', 'comment', '_test_name', '_test_session'])

    for file_arg in sys.argv[1:]:
        file_path = pathlib.Path(file_arg)
        file_name_parts = file_path.name.lstrip('pytest_integration_').rstrip('.log').split('_')

        i = 0

        podman_version = file_name_parts[i]
        i += 1

        if podman_version.endswith('-dev'):
            commit_date = file_name_parts[i]
            commit_id = file_name_parts[i+1]
            i += 2
        else:
            commit_date = None
            commit_id = None

        runtime = file_name_parts[i]
        i += 1

        comment = '_'.join(file_name_parts[i:])

        _test_session = "{} {} {} {} {}".format(podman_version, commit_date, commit_id, runtime, comment)

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

                        try:
                            file_class_test, result, _ = line.split(' ', maxsplit=2)
                        except ValueError:
                            file_class_test, _ = line.split(' ', maxsplit=1)
                            result = None

                        try:
                            test_file, test_method = file_class_test.split('::', maxsplit=1)
                            if '::' in test_method:
                                test_class, test_method = test_method.split('::')
                        except ValueError:
                            test_file = None
                            test_class = None
                            test_method = None

                        _test_name = file_class_test
                        csv_writer.writerow([commit_date, commit_id, podman_version, runtime, test_file, test_class, test_method, result, comment, _test_name, _test_session])


if __name__ == '__main__':
    main()
