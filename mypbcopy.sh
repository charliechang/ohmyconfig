#!/bin/bash
tee /tmp/copy | nc -w1 localhost 8377
tmux set-buffer "$(cat /tmp/copy)"
