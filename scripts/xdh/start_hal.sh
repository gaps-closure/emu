#!/bin/bash

CFG=$1
./hal/hal -l0 -f hal.out ./hal/$CFG &
