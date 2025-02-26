#!/bin/bash 

get_batch_options() {
    local arguments=("$@")

    unset command_line_specified_study_folder
    unset command_line_specified_subj
    unset command_line_specified_run_local

    local index=0
    local numArgs=${#arguments[@]}
    local argument

    while [ ${index} -lt ${numArgs} ]; do
        argument=${arguments[index]}

        case ${argument} in
            --StudyFolder=*)
                command_line_specified_study_folder=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --Subjlist=*)
                command_line_specified_subj=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --runlocal)
                command_line_specified_run_local="TRUE"
                index=$(( index + 1 ))
                ;;
	    *)
		echo ""
		echo "ERROR: Unrecognized Option: ${argument}"
		echo ""
		exit 1
		;;
        esac
    done
}

get_batch_options "$@"

StudyFolder="/nafs/narr/asahib/test_multirun_fix/nout" #Location of Subject folders (named by subjectID)
Subjlist="k001701" #Space delimited list of subject IDs
EnvironmentScript="${HCPPIPEDIR}/runners/SetUpUCLAPipeline.sh" #Pipeline environment script

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

# Requirements for this script
#  installed versions of: FSL (version 5.0.6)
#  environment: FSLDIR , HCPPIPEDIR , CARET7DIR 

#Set up pipeline environment variables and software
source ${EnvironmentScript}

# Log the originating call
echo "$@"

#if [ X$SGE_ROOT != X ] ; then
#    QUEUE="-q long.q"
    QUEUE="-q long.q"
#fi

PRINTCOM=""
#PRINTCOM="echo"

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the results of the HCP minimal preprocesing pipelines from Q2

######################################### DO WORK ##########################################

HighResMesh="164"
LowResMesh="32"
RegName="MSMAll_InitalReg_2_d40_WRN"
DeDriftRegFiles="${HCPPIPEDIR}/global/templates/MSMAll/DeDriftingGroup.L.sphere.DeDriftMSMAll.164k_fs_LR.surf.gii@${HCPPIPEDIR}/global/templates/MSMAll/DeDriftingGroup.R.sphere.DeDriftMSMAll.164k_fs_LR.surf.gii"
ConcatRegName="MSMAll_Test"
Maps="sulc curvature corrThickness thickness"
MyelinMaps="MyelinMap SmoothedMyelinMap" #No _BC, this will be reapplied
MRFixConcatNames="rest_AP_PA-carit_PA-face_AP_PA"
MRFixNames="rest_acq-AP_run-01@rest_acq-PA_run-02@rest_acq-AP_run-03@rest_acq-PA_run-04@carit_acq-PA_run-01@face_acq-AP_run-01@face_acq-PA_run-02"
fixNames="" #Space delimited list or NONE
fixNames="" #Space delimited list or NONE
dontFixNames="" #Space delimited list or NONE
dontFixNames=""
SmoothingFWHM="2" #Should equal previous grayordinates smoothing (because we are resampling from unsmoothed native mesh timeseries)
HighPass="2000"
MotionRegression=FALSE
#MatlabMode="1" #Mode=0 compiled Matlab, Mode=1 interpreted Matlab, Mode=2 octave
MatlabMode="0" #Mode=0 compiled Matlab, Mode=1 interpreted Matlab, Mode=2 octave

Maps=`echo "$Maps" | sed s/" "/"@"/g`
MyelinMaps=`echo "$MyelinMaps" | sed s/" "/"@"/g`
MRFixNames=`echo "$MRFixNames" | sed s/" "/"@"/g`
fixNames=`echo "$fixNames" | sed s/" "/"@"/g`
dontFixNames=`echo "$dontFixNames" | sed s/" "/"@"/g`

for Subject in $Subjlist ; do
	echo "    ${Subject}"
	
	if [ -n "${command_line_specified_run_local}" ] ; then
	    echo "About to run ${HCPPIPEDIR}/MSMAll/MSMAllPipeline.sh"
	    queuing_command=""
	else
	    echo "About to use fsl_sub to queue or run ${HCPPIPEDIR}/MSMAll/MSMAllPipeline.sh"
	    queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
	fi

	${queuing_command} ${HCPPIPEDIR}/DeDriftAndResample/DeDriftAndResamplePipeline.sh \
        --path=${StudyFolder} \
        --subject=${Subject} \
        --high-res-mesh=${HighResMesh} \
        --low-res-meshes=${LowResMesh} \
        --registration-name=${RegName} \
        --dedrift-reg-files=${DeDriftRegFiles} \
        --concat-reg-name=${ConcatRegName} \
        --maps=${Maps} \
        --myelin-maps=${MyelinMaps} \
        --multirun-fix-concat-names=${MRFixConcatNames} \
        --multirun-fix-names=${MRFixNames} \
        --fix-names=${fixNames} \
        --dont-fix-names=${dontFixNames} \
        --smoothing-fwhm=${SmoothingFWHM} \
        --highpass=${HighPass} \
        --matlab-run-mode=${MatlabMode} \
        --motion-regression=${MotionRegression}
done


