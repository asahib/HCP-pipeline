#!/bin/bash

#SBATCH -J PALM_PPI
#SBATCH -o PALM_PPI


#module unload fsl
#module load fsl/6.0.1


#hcpdir="/nafs/narr/HCP_OUTPUT"
maindir="/nafs/narr/asahib/test_multirun_fix/runners2"
#copeList="HAMD RUMINATION"
#copeList="cope5"

#GroupList="KTP1_HC"
GroupList=$(<${maindir}/Sublist.txt)

. /nafs/narr/asahib/test_multirun_fix/runners2/SetUpUCLAPipeline.sh

for g in ${GroupList}
do
	
	
	
    		echo "sbatch --nodes=1 --ntasks=1 --cpus-per-task=1 --mem=30G --time=7-00:00:00 \
--job-name=C${g} --output=/nafs/narr/asahib/Task_fmri/CARIT/PALM_${g}.log --export=COPE=group=${g} /nafs/narr/asahib/Task_fmri/CARIT/PALM3rdLevel_TFCE_JL_4slurm_wFIX_CARIT.sh"
   
		sbatch --nodes=1 --ntasks=1 --cpus-per-task=1 --mem=40G --time=5-00:00:00 \
--job-name=C${g} --output=/nafs/narr/asahib/test_multirun_fix/runners2/HCP_${g}.log --export=group=${g} /nafs/narr/asahib/test_multirun_fix/runners2/0-preprocessData_v3.sh
		
	
done

echo "finished"
