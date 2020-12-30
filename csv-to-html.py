#!/usr/bin/env python3

import csv
import sys
from collections import defaultdict
from itertools import groupby
from operator import itemgetter

import jinja2


def main():
  csv_file_name = sys.argv[1]
  with open(csv_file_name, 'rt') as f:
    csv_reader = csv.DictReader(f)

    all_tests = list(csv_reader)



  grouped_by_tests = defaultdict(list)
  for test_name, tests in groupby(all_tests, lambda t: t.get('file_class_test')):
    grouped_by_tests[test_name].extend(list(tests))

  test_names = list(sorted(grouped_by_tests.keys()))
  grouped_by_tests[test_names[0]] = sorted(grouped_by_tests[test_names[0]], key=itemgetter('podman_version', 'commit_date', 'commit_id'))



  env = jinja2.Environment(loader=jinja2.FileSystemLoader('.'))
  template = env.get_template('template.html.j2')
  print(template.render(test_names=test_names, tests=grouped_by_tests))


if __name__ == '__main__':
  main()