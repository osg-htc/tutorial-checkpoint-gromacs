#!/bin/bash
set -o pipefail

source /usr/local/gromacs/bin/GMXRC
export OMP_NUM_THREADS=4
BASENAME=$1
INTERVALHR=$2
FILE=${BASENAME}.cpt

set -u

# --- RUN ---
# Note: Do NOT use 1>${BASENAME}.log; -deffnm already writes and appends ${BASENAME}.log automatically.
if [ -e "$FILE" ]; then
    echo "$FILE exists. Starting from checkpoint."
    gmx mdrun -deffnm "$BASENAME" -ntmpi 1 -ntomp "$OMP_NUM_THREADS" \
              -maxh "$INTERVALHR" -cpi "$FILE" \
              1>mdrun_std.out 2>mdrun_std.err
    GMX_EXIT=$?
else
    echo "$FILE does not exist. Starting from beginning."
    gmx grompp -f "${BASENAME}.mdp" -c npt.gro -t npt.cpt -p topol.top \
               -o "${BASENAME}.tpr" \
               1>grompp.log 2>grompp.err || exit 1

    gmx mdrun -deffnm "$BASENAME" -ntmpi 1 -ntomp "$OMP_NUM_THREADS" \
              -maxh "$INTERVALHR" \
              1>mdrun_std.out 2>mdrun_std.err
    GMX_EXIT=$?
fi

echo "[Wrapper] GROMACS exit code: $GMX_EXIT"

# 1. Catch any non-zero exit
if [ "$GMX_EXIT" -ne 0 ]; then
    echo "[Wrapper] GROMACS failed with exit code $GMX_EXIT"
    exit 2
fi

# 2. Check ONLY this segment's stderr and the tail of the appended .log for fatal errors
if grep -qiE "Fatal error|Segmentation fault|Error in user input|Cannot open file" mdrun_std.err || \
   tail -n 50 "${BASENAME}.log" | grep -qiE "Fatal error|Segmentation fault|Error in user input|Cannot open file"; then
    echo "[Wrapper] Fatal error detected in current run"
    exit 3
fi

# 3. Verify the CURRENT segment reached clean shutdown (tail prevents false positives from earlier segments)
if ! tail -n 30 "${BASENAME}.log" | grep -q "Finished mdrun"; then
    echo "[Wrapper] mdrun exited 0 without reaching 'Finished mdrun' in current segment"
    exit 4
fi

# 4. Distinguish full completion vs. valid -maxh checkpoint
if [ -e "${BASENAME}.gro" ]; then
    echo "[Wrapper] Simulation completed all nsteps successfully"
    exit 0
elif tail -n 200 "${BASENAME}.log" | grep -q "will terminate the run within" && [ -s "${BASENAME}.cpt" ]; then
    echo "[Wrapper] Valid -maxh checkpoint confirmed — returning exit code 85"
    exit 85
else
    echo "[Wrapper] Missing .gro file, but no valid -maxh checkpoint in current segment"
    exit 5
fi
