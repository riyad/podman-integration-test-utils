#!/usr/bin/env python3

import csv
import pathlib
import sys


def main():
    csv_writer = csv.writer(sys.stdout)
    csv_writer.writerow(['commit_date', 'commit_id', 'podman_version', 'runtime', 'test_file', 'test_class', 'test_method', 'result', 'comment'])

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

        with file_path.open('rt') as f:
            do_parse = False
            for line in f:
                if not do_parse:
                    # first empty line, test summary section begins
                    if line == "\n":
                        do_parse = True
                        continue
                else:
                    if line == "\n":
                        # second empty line, error section follows
                        break

                    file_class_test, result, _ = line.split(' ', maxsplit=2)
                    test_class = None
                    test_file, test_method = file_class_test.split('::', maxsplit=1)
                    if '::' in test_method:
                        test_class, test_method = test_method.split('::')
                    csv_writer.writerow([commit_date, commit_id, podman_version, runtime, test_file, test_class, test_method, result, comment])


if __name__ == '__main__':
    main()
