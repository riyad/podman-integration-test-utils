#!/usr/bin/env python3

import csv
import sys
from collections import defaultdict
from itertools import groupby
from operator import itemgetter

import jinja2


def main():
    if len(sys.argv) == 2:
        csv_file_name = sys.argv[1]
    else:
        csv_file_name = None

    if csv_file_name is not None:
        with open(csv_file_name, 'rt') as f:
            csv_reader = csv.DictReader(f)
            all_tests = list(csv_reader)
    elif not sys.stdin.isatty():
        csv_reader = csv.DictReader(sys.stdin)
        all_tests = list(csv_reader)
    else:
        exit(1)

    tests_by_name = defaultdict(list)
    test_names = set()
    test_sessions = set()
    test_summaries_by_session = defaultdict(lambda: defaultdict(int))
    for test_name, tests in groupby(all_tests, lambda t: t['_test_name']):
        tests = list(tests)
        tests_by_name[test_name].extend(tests)
        test_names.add(test_name)

        for test in tests:
            test_sessions.add(test['_test_session'])
            test_summaries_by_session[test['_test_session']][test['result']] += 1

    test_names = sorted(list(test_names))
    test_sessions = sorted(list(test_sessions))
    for test_name in test_names:
        tests_by_name[test_name] = sorted(tests_by_name[test_name], key=itemgetter('_test_session'))

    env = jinja2.Environment(loader=jinja2.FileSystemLoader('.'))
    template = env.get_template('template.html.j2')
    print(template.render(
        test_names=test_names,
        test_sessions=test_sessions,
        tests_by_name=tests_by_name,
        test_summaries_by_session=test_summaries_by_session,
    ))


if __name__ == '__main__':
    main()
