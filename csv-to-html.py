#!/usr/bin/env python3
#
# Author: Riyad Preukschas <riyad@informatik.uni-bremen.de>
# License: Mozilla Public License 2.0
# SPDX-License-Identifier: MPL-2.0
#
# Loads pytest test logs from a CSV file (also from  STDIN) and renders it into
# a HTML table for better comparison.

import csv
import distutils.util
import sys
from collections import defaultdict
from datetime import datetime
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

    tests_by_name_and_suite = defaultdict(lambda: defaultdict(defaultdict))
    test_names = set()
    test_suites = set()
    test_summaries_by_suite = defaultdict(lambda: defaultdict(int))
    for test_name, tests in groupby(all_tests, lambda t: t['_test_name']):
        tests = list(tests)
        test_names.add(test_name)

        for test in tests:
            # fix data format
            if test['commit_date'] != '':
                test['commit_date'] = datetime.fromisoformat(test['commit_date'])
            test['_unsupported'] = bool(distutils.util.strtobool(test['_unsupported']))

            test_suites.add(test['_test_suite'])
            tests_by_name_and_suite[test_name][test['_test_suite']] = test
            test_summaries_by_suite[test['_test_suite']][test['result']] += 1

    test_names = list(sorted(test_names))
    test_suites = list(reversed(sorted(test_suites)))

    env = jinja2.Environment(loader=jinja2.FileSystemLoader('.'))
    template = env.get_template('template.html.j2')
    print(template.render(
        test_names=test_names,
        test_suites=test_suites,
        tests_by_name_and_suite=tests_by_name_and_suite,
        test_summaries_by_suite=test_summaries_by_suite,
    ))


if __name__ == '__main__':
    main()
