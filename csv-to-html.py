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
    test_infos_by_name = dict()
    test_suites = dict()
    test_summaries_by_suite = defaultdict(lambda: defaultdict(int))
    for test_name, tests in groupby(all_tests, lambda t: t['_test_name']):
        tests = list(tests)

        test_infos_by_name[test_name] = test_infos_by_name.get(
            test_name,
            dict(
                test_name=test_name,
                test_file='',
                test_class='',
                test_method='',
                _unsupported=False,
            )
        )

        for test in tests:
            # fix data format
            if test['commit_date'] != '':
                test['commit_date'] = datetime.fromisoformat(test['commit_date'])
            test['_unsupported'] = bool(distutils.util.strtobool(test['_unsupported']))

            if test['_test_suite'] not in test_suites:
                test_suites[test['_test_suite']] = dict(
                    _id=test['_test_suite'],
                    commit_date=test['commit_date'],
                    commit_id=test['commit_id'],
                    podman_version=test['podman_version'],
                    runtime=test['runtime'],
                    comment=test['comment'],
                )
            tests_by_name_and_suite[test_name][test['_test_suite']] = test
            # don't "count" unsupported tests
            test_summaries_by_suite[test['_test_suite']] \
                ['UNSUPPORTED' if test['_unsupported'] else test['result']] += 1

            test_infos_by_name[test_name]['test_file'] = test['test_file']
            test_infos_by_name[test_name]['test_class'] = test['test_class']
            test_infos_by_name[test_name]['test_method'] = test['test_method']
            test_infos_by_name[test_name]['_unsupported'] = test_infos_by_name[test_name]['_unsupported'] or test['_unsupported']

    test_infos = list(test_info for (_, test_info) in sorted(test_infos_by_name.items()))
    test_suites = list(test_suite for (_, test_suite) in sorted(test_suites.items(), reverse=True))

    env = jinja2.Environment(loader=jinja2.FileSystemLoader('.'))
    template = env.get_template('template.html.j2')
    print(template.render(
        test_infos=test_infos,
        test_suites=test_suites,
        tests_by_name_and_suite=tests_by_name_and_suite,
        test_summaries_by_suite=test_summaries_by_suite,
    ))


if __name__ == '__main__':
    main()
