#!/bin/bash
#SBATCH -J Pennant
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --exclusive
#SBATCH --time=00:20:00
#SBATCH -A VEN113
#SBATCH --gres=gpu:8 

ulimit -s unlimited
ulimit -c unlimited

echo "The nodes in use are: $SLURM_JOB_NODELIST"
module load rocm
module list

set -x
export FI_CXI_ATS=0

cd pennant
t1=$(perl -e 'print time')
srun -n1 make clean
srun -n1 make -j16
t2=$(perl -e 'print time')
echo "Total compile time = `expr $t2 - $t1`secs"
echo "Job is done!"

