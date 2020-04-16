#!/usr/bin/env python3

import sys

if __name__ == "__main__":
  while True:
    c = sys.stdin.read(1)
    sys.stdout.write(c)
    sys.stdout.flush()
