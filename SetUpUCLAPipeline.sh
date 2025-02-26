#!/bin/echo This script should be sourced before calling a pipeline script, and should not be run directly:

#!/bin/echo This script should be sourced before calling a pipeline script, and should not be run directly:

export HCP_APP_DIR=/nafs/apps/HCPPipelines/64
export PATH="/ifshome/jpierce/anaconda3/bin:${HCP_APP_DIR}/../miniconda/bin:${HCP_APP_DIR}/util:${PATH}"

# Set up specific environment variables for the HCP Pipeline
export HCPPIPEDIR=/nafs/narr/jpierce/hcppipe
export MSMBINDIR="${HCP_APP_DIR}/MSM_HOCR_v3-github"
export MSMCONFIGDIR="${HCPPIPEDIR}/MSMConfig"
# this must be set to v91 for this version of the HCPpipelines. note that this
# is different than the MCR used for FIX, which is configured in its own
# settings file
export MATLAB_COMPILER_RUNTIME="${HCP_APP_DIR}/MCR/R2016b/v91"
export FSL_FIX_MCR="${HCP_APP_DIR}/MCR/R2017b/v93"
export FSL_FIXDIR="${HCP_APP_DIR}/fix"
# if a suitable version of wb_command is on your $PATH, CARET7DIR can be blank
export CARET7DIR="${HCP_APP_DIR}/workbench/1.3.2/bin_rh_linux64"

export FIX_R_DIR="/nafs/apps/R/3.4.3/64/gcc4.8.5"

# Set up FSL (if not already done so in the running environment)
# Uncomment the following 2 lines (remove the leading #) and correct the FSLDIR setting for your setup
export FSLDIR="${HCP_APP_DIR}/fsl/6.0.1-hcp"
. "${FSLDIR}/etc/fslconf/fsl.sh" > /dev/null 2>&1

if [[ -z "${FSLDIR:-}" ]]
then
    found_fsl=$(which fslmaths || true)
    if [[ ! -z "$found_fsl" ]]
    then
        #like our scripts, assume $FSLDIR/bin/fslmaths (neurodebian doesn't follow this, so sanity check)
        #yes, quotes nest properly inside of $()
        export FSLDIR=$(dirname "$(dirname "$found_fsl")")
        #if we didn't have FSLDIR, assume we haven't sourced fslconf
        if [[ ! -f "$FSLDIR/etc/fslconf/fsl.sh" ]]
        then
            echo "FSLDIR was unset, and guessed FSLDIR ($FSLDIR) does not contain etc/fslconf/fsl.sh, please specify FSLDIR in the setup script" 1>&2
            exit 1
        else
            source "$FSLDIR/etc/fslconf/fsl.sh"
        fi
    else
        echo "fslmaths not found in \$PATH, please install FSL and ensure it is on \$PATH, or edit the setup script to specify its location" 1>&2
        exit 1
    fi
fi

# Let FreeSurfer know what version of FSL to use
# FreeSurfer uses FSL_DIR instead of FSLDIR to determine the FSL version
export FSL_DIR="${FSLDIR}"

# Set up FreeSurfer (if not already done so in the running environment)
# Uncomment the following 2 lines (remove the leading #) and correct the FREESURFER_HOME setting for your setup
export FREESURFER_HOME="${HCP_APP_DIR}/freesurfer/6.0.0-stable-pub"
. "${FREESURFER_HOME}/SetUpFreeSurfer.sh" > /dev/null 2>&1

#users probably won't need to edit anything below this line

#sanity check things and/or populate from $PATH
if [[ -z "$CARET7DIR" ]]
then
    found_wb=$(which wb_command || true)
    if [[ ! -z "$found_wb" ]]
    then
        CARET7DIR=$(dirname "$found_wb")
    else
        echo "wb_command not found in \$PATH, please install connectome workbench and ensure it is on \$PATH, or edit the setup script to specify its location" 1>&2
        exit 1
    fi
fi
if [[ ! -x "$CARET7DIR/wb_command" ]]
then
    echo "CARET7DIR ($CARET7DIR) does not contain wb_command, please fix the settings in the setup script" 1>&2
    exit 1
fi
#make sure FSLDIR is sane
if [[ ! -x "$FSLDIR/bin/fslmaths" ]]
then
    echo "FSLDIR ($FSLDIR) does not contain bin/fslmaths, please fix the settings in the setup script" 1>&2
    exit 1
fi
#add the specified versions of some things to the front of $PATH, so we can stop using absolute paths everywhere
export PATH="$CARET7DIR:$PATH"

# Set up EPD
export EPD_PYTHON_HOME="${HCP_APP_DIR}/epd-7.3-2-rh5"
export PATH="${EPD_PYTHON_HOME}/bin:${PATH}"

#source extra stuff that pipelines authors may need to edit, but users shouldn't ever need to
#by separating them this way, a user can continue to use their previous setup file even if we rearrange some internal things
if [[ ! -f "$HCPPIPEDIR/global/scripts/finish_hcpsetup.shlib" ]]
then
    echo "HCPPIPEDIR ($HCPPIPEDIR) appears to be set to an old version of the pipelines, please check the setting (or start from the older SetUpHCPPipeline.sh to run the older pipelines)"
    exit 1
fi
source "$HCPPIPEDIR/global/scripts/finish_hcpsetup.shlib"

