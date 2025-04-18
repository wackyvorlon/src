#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
File: main.py
Description: Brief description of what this script does.
Author: Alyssa
Date: April 18, 2025
"""

from itertools import groupby
from operator import itemgetter

# Sample data: (name, department)
employees = [
    ("Alice", "Engineering"),
    ("Bob", "Marketing"),
    ("Charlie", "Engineering"),
    ("Diana", "HR"),
    ("Evan", "Marketing"),
]

# Sort by department first (groupby works on consecutive items)
employees.sort(key=itemgetter(1))

# Group by department
for department, group in groupby(employees, key=itemgetter(1)):
    print(f"\n{department} Department:")
    for name, _ in group:
        print(f"  - {name}")