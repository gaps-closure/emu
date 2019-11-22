#!/usr/bin/env python3

import sys

if __name__ == "__main__":
    for line in sys.stdin:
        line = line.replace('a', 'x')
        sys.stdout.write(line)
        sys.stdout.flush()
#        print ("o1:", type(line), line, end = '')
#        sys.stderr.write(line)
