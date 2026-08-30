#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
for i in 1 2 3; do
  pdflatex -interaction=nonstopmode main.tex > /dev/null
done
cp main.pdf Solar_MPPT_Control_Report.pdf
echo "Built Solar_MPPT_Control_Report.pdf ($(pdfinfo main.pdf | awk '/Pages/{print $2}') pages)"
