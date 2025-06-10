#!/bin/bash

echo "Activating P-RES scheduler..."
setsched P-RES


MAJOR_CYCLE=1000

echo "Creating table-driven reservation on CPU 0 with ID 1001..."
resctl -n 1001 -c 0 -t table-driven -m $MAJOR_CYCLE '[100, 200)' '[500, 650)'

echo "Table setup complete."