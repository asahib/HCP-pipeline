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
Subjlist="k007501" #Space delimited list of subject IDs
EnvironmentScript="${HCPPIPEDIR}/runners/SetUpUCLAPipeline.sh" #Pipeline environment script

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

# Requirements for this script
#  installed versions of: FSL (version 5.0.6), FreeSurfer (version 5.3.0-HCP) , gradunwarp (HCP version 1.0.1)
#  environment: FSLDIR , FREESURFER_HOME , HCPPIPEDIR , CARET7DIR , PATH (for gradient_unwarp.py)

#Set up pipeline environment variables and software
source ${EnvironmentScript}

# Log the originating call
echo "$@"

#if [ X$SGE_ROOT != X ] ; then
#    QUEUE="-q long.q"
    QUEUE="-q hcp_priority.q"
#fi

if [[ ${HCPPIPEDEBUG} == "true" ]]; then
    set -x
fi

PRINTCOM=""
#PRINTCOM="echo"
#QUEUE="-q veryshort.q"

########################################## INPUTS ########################################## 

# Scripts called by this script do NOT assume anything about the form of the input names or paths.
# This batch script assumes the HCP raw data naming convention.
#
# For example, if phase encoding directions are LR and RL, for tfMRI_EMOTION_LR and tfMRI_EMOTION_RL:
#
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_LR/${Subject}_3T_tfMRI_EMOTION_LR.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_LR/${Subject}_3T_tfMRI_EMOTION_LR_SBRef.nii.gz
#
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_RL/${Subject}_3T_tfMRI_EMOTION_RL.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_RL/${Subject}_3T_tfMRI_EMOTION_RL_SBRef.nii.gz
#
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_LR/${Subject}_3T_SpinEchoFieldMap_LR.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_LR/${Subject}_3T_SpinEchoFieldMap_RL.nii.gz
#
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_RL/${Subject}_3T_SpinEchoFieldMap_LR.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_RL/${Subject}_3T_SpinEchoFieldMap_RL.nii.gz
#
# If phase encoding directions are PA and AP:
#
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_PA/${Subject}_3T_tfMRI_EMOTION_PA.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_PA/${Subject}_3T_tfMRI_EMOTION_PA_SBRef.nii.gz
#
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_AP/${Subject}_3T_tfMRI_EMOTION_AP.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_AP/${Subject}_3T_tfMRI_EMOTION_AP_SBRef.nii.gz
#
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_PA/${Subject}_3T_SpinEchoFieldMap_PA.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_PA/${Subject}_3T_SpinEchoFieldMap_AP.nii.gz
#
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_AP/${Subject}_3T_SpinEchoFieldMap_PA.nii.gz
#	${StudyFolder}/${Subject}/unprocessed/3T/tfMRI_EMOTION_AP/${Subject}_3T_SpinEchoFieldMap_AP.nii.gz
#
#
# Change Scan Settings: EchoSpacing, FieldMap DeltaTE (if not using TOPUP),
# and $TaskList to match your acquisitions
#
# If using gradient distortion correction, use the coefficents from your scanner.
# The HCP gradient distortion coefficents are only available through Siemens.
# Gradient distortion in standard scanners like the Trio is much less than for the HCP 'Connectom' scanner.
#
# To get accurate EPI distortion correction with TOPUP, the phase encoding direction
# encoded as part of the ${TaskList} name must accurately reflect the PE direction of
# the EPI scan, and you must have used the correct images in the
# SpinEchoPhaseEncode{Negative,Positive} variables.  If the distortion is twice as
# bad as in the original images, either swap the
# SpinEchoPhaseEncode{Negative,Positive} definition or reverse the polarity in the
# logic for setting UnwarpDir.
# NOTE: The pipeline expects you to have used the same phase encoding axis and echo
# spacing in the fMRI data as in the spin echo field map acquisitions.

######################################### DO WORK ##########################################

SCRIPT_NAME=`basename ${0}`
echo $SCRIPT_NAME

TaskList=""
TaskList+=" rest_acq-AP_run-01"  #Include space as first character
TaskList+=" rest_acq-PA_run-02"
TaskList+=" rest_acq-AP_run-03"
TaskList+=" rest_acq-PA_run-04"
TaskList+=" carit_acq-PA_run-01"
TaskList+=" face_acq-AP_run-01"
TaskList+=" face_acq-PA_run-02"

# Start or launch pipeline processing for each subject
for Subject in $Subjlist ; do
  echo "${SCRIPT_NAME}: Processing Subject: ${Subject}"

  i=1
  for fMRIName in $TaskList ; do
    echo "  ${SCRIPT_NAME}: Processing Scan: ${fMRIName}"
	  
        TaskName=$(echo ${fMRIName} | cut -d_ -f1)
	echo "  ${SCRIPT_NAME}: TaskName: ${TaskName}"

	len=${#fMRIName}
	echo "  ${SCRIPT_NAME}: len: $len"
	start=$(( len - 2 ))
		
        PhaseEncodingDir="$(echo "${fMRIName}" | grep -oE '(AP|PA|RL|LR)')"
	echo "  ${SCRIPT_NAME}: PhaseEncodingDir: ${PhaseEncodingDir}"
		
	case ${PhaseEncodingDir} in
	  "PA")
		UnwarpDir="y"
		;;
	  "AP")
		UnwarpDir="y-"
		;;
	  "RL")
		UnwarpDir="x"
		;;
	  "LR")
		UnwarpDir="x-"
		;;
	  *)
		echo "${SCRIPT_NAME}: Unrecognized Phase Encoding Direction: ${PhaseEncodingDir}"
		exit 1
	esac
	
	echo "  ${SCRIPT_NAME}: UnwarpDir: ${UnwarpDir}"
		
    fMRITimeSeries="${StudyFolder}/sub-${Subject}/func/sub-${Subject}_task-${fMRIName}_bold.nii.gz"

	# A single band reference image (SBRef) is recommended if available
	# Set to NONE if you want to use the first volume of the timeseries for motion correction
    fMRISBRef="${StudyFolder}/sub-${Subject}/func/sub-${Subject}_task-${fMRIName}_sbref.nii.gz"
	
	# "Effective" Echo Spacing of fMRI image (specified in *sec* for the fMRI processing)
	# EchoSpacing = 1/(BWPPPE * ReconMatrixPE)
	#   where BWPPPE is the "BandwidthPerPixelPhaseEncode" = DICOM field (0019,1028) for Siemens, and
	#   ReconMatrixPE = size of the reconstructed image in the PE dimension
	# In-plane acceleration, phase oversampling, phase resolution, phase field-of-view, and interpolation
	# all potentially need to be accounted for (which they are in Siemen's reported BWPPPE)
        EchoSpacing="$(jq -r '.EffectiveEchoSpacing' "$(echo ${fMRITimeSeries} | sed 's/\.nii\.gz$/\.json/')")"

	# Susceptibility distortion correction method (required for accurate processing)
	# Values: TOPUP, SiemensFieldMap (same as FIELDMAP), GeneralElectricFieldMap
    DistortionCorrection="TOPUP"

	# Receive coil bias field correction method
	# Values: NONE, LEGACY, or SEBASED
	#   SEBASED calculates bias field from spin echo images (which requires TOPUP distortion correction)
	#   LEGACY uses the T1w bias field (method used for 3T HCP-YA data, but non-optimal; no longer recommended).
	BiasCorrection="SEBASED"

	# For the spin echo field map volume with a 'negative' phase encoding direction
	# (LR in HCP-YA data; AP in 7T HCP-YA and HCP-D/A data)
	# Set to NONE if using regular FIELDMAP
    if [ $fMRIName == "rest_acq-AP_run-01" ] || [ $fMRIName == "rest_acq-PA_run-02" ]; then
    		SpinEchoPhaseEncodeNegative="${StudyFolder}/sub-${Subject}/fmap/sub-${Subject}_acq-func_dir-AP_run-01_epi.nii.gz"

		# For the spin echo field map volume with a 'positive' phase encoding direction
		# (RL in HCP-YA data; PA in 7T HCP-YA and HCP-D/A data)
		# Set to NONE if using regular FIELDMAP
   		SpinEchoPhaseEncodePositive="${StudyFolder}/sub-${Subject}/fmap/sub-${Subject}_acq-func_dir-PA_run-02_epi.nii.gz"
	elif [ $fMRIName == "rest_acq-AP_run-03" ] || [ $fMRIName == "rest_acq-PA_run-04" ]; then
    		SpinEchoPhaseEncodeNegative="${StudyFolder}/sub-${Subject}/fmap/sub-${Subject}_acq-func_dir-AP_run-03_epi.nii.gz"

		# For the spin echo field map volume with a 'positive' phase encoding direction
		# (RL in HCP-YA data; PA in 7T HCP-YA and HCP-D/A data)
		# Set to NONE if using regular FIELDMAP
   		SpinEchoPhaseEncodePositive="${StudyFolder}/sub-${Subject}/fmap/sub-${Subject}_acq-func_dir-PA_run-04_epi.nii.gz"
      else
		SpinEchoPhaseEncodeNegative="${StudyFolder}/sub-${Subject}/fmap/sub-${Subject}_acq-func_dir-AP_run-05_epi.nii.gz"

		# For the spin echo field map volume with a 'positive' phase encoding direction
		# (RL in HCP-YA data; PA in 7T HCP-YA and HCP-D/A data)
		# Set to NONE if using regular FIELDMAP
    		SpinEchoPhaseEncodePositive="${StudyFolder}/sub-${Subject}/fmap/sub-${Subject}_acq-func_dir-PA_run-06_epi.nii.gz"
     fi
    TopUpConfig="${HCPPIPEDIR_Config}/b02b0.cnf"

	# Not using Siemens Gradient Echo Field Maps for susceptibility distortion correction
	# Set following to NONE if using TOPUP
	MagnitudeInputName="NONE" #Expects 4D Magnitude volume with two 3D volumes (differing echo times)
    PhaseInputName="NONE" #Expects a 3D Phase difference volume (Siemen's style)
    DeltaTE="NONE" #2.46ms for 3T, 1.02ms for 7T
	
    # Path to General Electric style B0 fieldmap with two volumes
    #   1. field map in degrees
    #   2. magnitude
    # Set to "NONE" if not using "GeneralElectricFieldMap" as the value for the DistortionCorrection variable
    #
    # Example Value: 
    #  GEB0InputName="${StudyFolder}/${Subject}/unprocessed/3T/${fMRIName}/${Subject}_3T_GradientEchoFieldMap.nii.gz" 
    GEB0InputName="NONE"

	# Target final resolution of fMRI data
	# 2mm is recommended for 3T HCP data, 1.6mm for 7T HCP data (i.e. should match acquisition resolution)
	# Use 2.0 or 1.0 to avoid standard FSL templates
    FinalFMRIResolution="$(jq '.SpacingBetweenSlices' "${StudyFolder}/sub-${Subject}/func/sub-${Subject}_task-${fMRIName}_bold.json")"

	# Gradient distortion correction
	# Set to NONE to skip gradient distortion correction
	# (These files are considered proprietary and therefore not provided as part of the HCP Pipelines -- contact Siemens to obtain)
    # GradientDistortionCoeffs="${HCPPIPEDIR_Config}/coeff_SC72C_Skyra.grad"
    GradientDistortionCoeffs="${HCPPIPEDIR_Config}/coeff_AS82.grad"
      if [[ -z "${GradientDistortionCoeffs}" ]]; then
        echo "Missing gradient distortion coefficients. Manually populate file
        or set GradientDistortionCoeffs=NONE to skip gradient distortion
        correction.

        This file contains proprietary Siemens data and should never be
        committed to a public repo. Exiting."
        exit 1
      fi

    # Type of motion correction
	# Values: MCFLIRT (default), FLIRT
	# (3T HCP-YA processing used 'FLIRT', but 'MCFLIRT' now recommended)
    MCType="MCFLIRT"
		
    if [ -n "${command_line_specified_run_local}" ] ; then
        echo "About to run ${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh"

        queuing_command=""
    else
        echo "About to use fsl_sub to queue or run ${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh"
        queuing_command="${FSLDIR}/bin/fsl_sub -l ${LOG_DIR} ${QUEUE}"
    fi

    ${queuing_command} ${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh \
      --path=$StudyFolder \
      --subject=$Subject \
      --fmriname=$fMRIName \
      --fmritcs=$fMRITimeSeries \
      --fmriscout=$fMRISBRef \
      --SEPhaseNeg=$SpinEchoPhaseEncodeNegative \
      --SEPhasePos=$SpinEchoPhaseEncodePositive \
      --fmapmag=$MagnitudeInputName \
      --fmapphase=$PhaseInputName \
      --fmapgeneralelectric=$GEB0InputName \
      --echospacing=$EchoSpacing \
      --echodiff=$DeltaTE \
      --unwarpdir=$UnwarpDir \
      --fmrires=$FinalFMRIResolution \
      --dcmethod=$DistortionCorrection \
      --gdcoeffs=$GradientDistortionCoeffs \
      --topupconfig=$TopUpConfig \
      --printcom=$PRINTCOM \
      --biascorrection=$BiasCorrection \
      --mctype=${MCType}

  # The following lines are used for interactive debugging to set the positional parameters: $1 $2 $3 ...

  echo "set -- --path=$StudyFolder \
      --subject=$Subject \
      --fmriname=$fMRIName \
      --fmritcs=$fMRITimeSeries \
      --fmriscout=$fMRISBRef \
      --SEPhaseNeg=$SpinEchoPhaseEncodeNegative \
      --SEPhasePos=$SpinEchoPhaseEncodePositive \
      --fmapmag=$MagnitudeInputName \
      --fmapphase=$PhaseInputName \
      --fmapgeneralelectric=$GEB0InputName \
      --echospacing=$EchoSpacing \
      --echodiff=$DeltaTE \
      --unwarpdir=$UnwarpDir \
      --fmrires=$FinalFMRIResolution \
      --dcmethod=$DistortionCorrection \
      --gdcoeffs=$GradientDistortionCoeffs \
      --topupconfig=$TopUpConfig \
      --printcom=$PRINTCOM \
      --biascorrection=$BiasCorrection \
      --mctype=${MCType}"

  echo ". ${EnvironmentScript}"
	
    i=$(($i+1))
  done
done

ret=$?; times; exit "${ret}"
