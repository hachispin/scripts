#!/usr/bin/env zsh

set -euo pipefail

sum_times=0.0
num_iterations=25

for ((i = 0; i < num_iterations; i++)); do
	output=$(nvim --headless --startuptime /dev/stdout +q!)
	final_time=$(tail -n2 <<<"$output" | tr -d '\n' | cut -d ' ' -f1 | sed 's/^0*//')
	((sum_times += final_time))
done

echo $((sum_times / num_iterations))
