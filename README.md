# Checkpoint a GROMACS job on the OSPool

This repository contains scripts, files, and an HTCondor submit file that demonstrates how to checkpoint a GROMACS molecular dynamics job. The GROMACS example was taken from [this tutorial](http://www.mdtutorials.com/gmx/lysozyme/08_MD.html) by the Lemkul lab at Virginia Tech.

## Contents

| File(s) | Purpose |
| --- | --- |
| `charmm36-feb2026_cgenff-5.0.ff/` | Directory of force field files |
| `chkpt.sh` | Executable script |
| `chkpt.sub` | HTCondor submit file |
| `md_0_0.1.mdp` | Molecular dynamics parameters |
| `npt.cpt`, `npt.gro`, `posre.itp`, `topol.top` | Input files generated from previous GROMACS steps |
| `gromacs2026.3.def` | Apptainer definition file for container image |

## The MD simulation

This job simulates lysozyme in water for 0.1 nanoseconds and checkpoints every 5 minutes using GROMACS's self-checkpointing mechanism paired with a wrapper script.

Because GROMACS's exit code upon checkpointing / successfully finishing the simulation are both 0, we must use a wrapper script to perform other checks and make the job compatible with HTCondor's checkpointing mechanism.

> [!WARNING]  
> For the purposes of the tutorial/demonstration, we are checkpointing every 5 minutes, but this is not recommended for actual jobs, due to scheduler overhead. **Instead, we recommend checkpointing every 4 hours**.
>
