#!/bin/bash
#SBATCH -J Pennant
#SBATCH --nodes=16
#SBATCH --ntasks-per-node=64
#SBATCH --exclusive
#SBATCH --time=00:40:00
#SBATCH -A VEN113

ulimit -s unlimited
ulimit -c unlimited


echo "The nodes in use are: $SLURM_JOB_NODELIST"
module load craype-accel-amd-gfx90a
module load PrgEnv-cray
module load rocm
module list
set -x
export FI_CXI_ATS=0
export FI_MR_CACHE_MONITOR=memhooks
export FI_CXI_DEFAULT_CQ_SIZE=131072
export MPICH_OFI_NIC_POLICY=USER
export MPICH_OFI_NIC_MAPPING="0:0,1;1:2,3;2:4,5;3:6,7"
export MPICH_OFI_NIC_POLICY=NUMA

export NODES=$SLURM_NNODES
export PENNANT_ROOT=$PWD/../pennant
export TEST_DIR=${PENNANT_ROOT}/test
export OMP_NUM_THREADS=1
echo "--------------------AMD Runs------------------------"
export EXE=${PENNANT_ROOT}/build/pennant
export TEST_CASE=sedovflatx32
export TEST=${TEST_DIR}/${TEST_CASE}/${TEST_CASE}.pnt
export RANKS=`expr ${SLURM_NNODES} \* ${SLURM_NTASKS_PER_NODE}`

export OUTPUT="pennant.out"
export OUTDIR="pennant_R${RANKS}_${TEST_CASE}_${NODES}nodes.${SLURM_JOBID}"
mkdir ${OUTDIR}
module list > ${OUTDIR}/launch.modules.log
env > ${OUTDIR}/launch.env.log
ulimit -a > ${OUTDIR}/launch.ulimits.log
ldd ${EXE} > ${OUTDIR}/launch.ldd.log
export OUTPUT=pennant_R${RANKS}_${TEST_CASE}_${NODES}nodes.${SLURM_JOBID}

t1=$(perl -e 'print time')
srun -n1 numactl -H
time -p srun    --nodes=${NODES}   --ntasks=${RANKS}  ${EXE}   ${TEST} > ${OUTDIR}/${OUTPUT}
t2=$(perl -e 'print time')








