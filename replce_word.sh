#!/bin/bash

input="file1.txt"
output="file2.txt"

awk 'NR>=5 && /welcome/ {gsub (/give/ , "learning")} {print}' "$input" > "$output"
