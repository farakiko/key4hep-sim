#!/bin/bash
#SBATCH -p main
#SBATCH --mem-per-cpu=6G
#SBATCH --cpus-per-task=1
#SBATCH -o logs/slurm-%x-%j-%N.out
set -e
set -x

env
df -h

export NEV=$1  # number of events to generate per rootfile
export SAMPLE=$2 # main card
export JOBID=$3 # random seed
export TAG=$4 # output dir tag on EOS

# alias for quick access of work directory
export EOSDIR=/eos/user/f/fmokhtar/

mkdir CLDConfigYalla
cd CLDConfigYalla

# copy large input files via xrootd (recommended)
xrdcp root://eosuser.cern.ch/$EOSDIR/key4hep-sim/cld/CLDConfig/CLDConfig/${SAMPLE}.cmd card.cmd
xrdcp root://eosuser.cern.ch/$EOSDIR/key4hep-sim/cld/CLDConfig/CLDConfig/pythia.py pythia.py
xrdcp root://eosuser.cern.ch/$EOSDIR/key4hep-sim/cld/CLDConfig/CLDConfig/cld_steer.py cld_steer.py
xrdcp root://eosuser.cern.ch/$EOSDIR/key4hep-sim/cld/CLDConfig/CLDConfig/CLDReconstruction.py CLDReconstruction.py
xrdcp -r root://eosuser.cern.ch/$EOSDIR/key4hep-sim/cld/CLDConfig/CLDConfig/PandoraSettingsCLD .

cd ..

# update the seed in the pythia card
echo "Random:seed=${JOBID}" >> card.cmd
cat card.cmd

echo "
#!/bin/bash
set -e
source /cvmfs/sw.hsf.org/key4hep/setup.sh
env
k4run pythia.py -n $NEV --Dumper.Filename out.hepmc --Pythia8.PythiaInterface.pythiacard card.cmd
ddsim -I out.hepmc -N -1 -O out_SIM.root --compactFile \$K4GEO/FCCee/CLD/compact/CLD_o2_v05/CLD_o2_v05.xml --steeringFile cld_steer.py
k4run CLDReconstruction.py --inputFiles out_SIM.root --outputBasename out_RECO --num-events -1
" > sim.sh

cat sim.sh

# run the event generation and PF reco
singularity exec -B /cvmfs -B CLDConfigYalla docker://ghcr.io/key4hep/key4hep-images/alma9:latest bash sim.sh

# copy the output files to EOS
bzip2 out.hepmc
xrdcp out.hepmc.bz2 root://eosuser.cern.ch/$EOSDIR/$TAG/sim_${SAMPLE}_${JOBID}.hepmc.bz2
xrdcp out_RECO_edm4hep.root root://eosuser.cern.ch/$EOSDIR/$TAG/reco_${SAMPLE}_${JOBID}.root

