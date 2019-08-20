#!/bin/sh

###################################################
# Modularized forecast script with capability to  #
# support coupling experiments.    		  #
#						  #
#	2019/04/17 Prototype V1.0, Jian Kuang	  #
#						  #
###################################################

#######################
# Function definition #
#######################

set_environment(){		# Do we really need this block?
echo SUB ${FUNCNAME[0]}: Setting up environment
case "$machine" in
'sandbox')
	local unameOut="$(uname -s)"
	case "${unameOut}" in
    		Linux*)
			SCRIPTDIR=$(dirname $(readlink -f "$0") )
			echo SUB ${FUNCNAME[0]}: Linux environment. Current Script locates in $SCRIPTDIR.
			;;
    		Darwin*)
                        SCRIPTDIR=$(pwd)
                        echo SUB ${FUNCNAME[0]}: MacOS environment. Current Script locates in $SCRIPTDIR.
			;;
    		CYGWIN*)    echo CYGWIN ;;
    		MINGW*)     echo MinGw ;;
    		*)          echo "UNKNOWN:${unameOut}"
	esac
echo SUB ${FUNCNAME[0]}: environment loaded for $machine platform
  ;;
'WCOSS_C')
echo SUB: environment loaded for $machine platform
  ;;
'WCOSS_DELL_P3')
echo SUB: environment loaded for $machine platform
  ;;
'theia')
echo SUB: environment loaded for $machine platform
  ;;
esac
echo SUB ${FUNCNAME[0]}: Environment set for $machine
# More platforms here
}

select_combination(){
echo SUB ${FUNCNAME[0]}: Selecting combination of models
local array=($cplflx $cplwav $cplchem)
local ATM=(0 0 0)
local ATM_WAVE=(0 1 0)
local ATM_WAVE_CHEM=(0 1 1)
case $array in
	$ATM) combination='ATM' ;;
	$ATM_WAVE) combination='ATM_WAVE' ;;
	$ATM_WAVE_CHEM) combination='ATM_WAVE_CHEM' ;;
	*) echo SUB: Combination not supported; exit ;;
esac
echo SUB ${FUNCNAME[0]}: Running $combination
#	if [ $cplflx = 0 -a $cplwav = 0 -a $cplchem = 0 ]; then
#		combination='ATM'
#	elif [ $cplflx = 0 -a $cplwav != 0 -a $cplchem = 0 ]; then
#		combination='ATM_WAVE'
#	elif [ $cplflx = 0 -a $cplwav != 0 -a $cplchem != 0 ]; then
#		combination='ATM_WAVE_CHEM'
#	else
#		echo SUB: Combination currently not supported. Exit now!
#		exit
#	fi
}

data_link(){
# data in take for all active components
# Arguments: None 
# 
echo SUB ${FUNCNAME[0]}: Linking input data for FV3
if [ $warm_start = ".true." ]; then

  # Link all (except sfc_data) restart files from $gmemdir
  for file in $gmemdir/RESTART/${PDY}.${cyc}0000.*.nc; do
    file2=$(echo $(basename $file))
    file2=$(echo $file2 | cut -d. -f3-) # remove the date from file
    fsuf=$(echo $file2 | cut -d. -f1)
    if [ $fsuf != "sfc_data" ]; then
       $NLN $file $DATA/INPUT/$file2
    fi
  done

  # Link sfcanl_data restart files from $memdir
  for file in $memdir/RESTART/${PDY}.${cyc}0000.*.nc; do
    file2=$(echo $(basename $file))
    file2=$(echo $file2 | cut -d. -f3-) # remove the date from file
    fsufanl=$(echo $file2 | cut -d. -f1)
    if [ $fsufanl = "sfcanl_data" ]; then
      file2=$(echo $file2 | sed -e "s/sfcanl_data/sfc_data/g")
      $NLN $file $DATA/INPUT/$file2
    fi
  done

  # Handle coupler.res file for DA cycling
  if [ ${USE_COUPLER_RES:-"NO"} = "YES" ]; then
    # In DA, this is not really a "true restart",
    # and the model start time is the analysis time
    # The alternative is to replace
    # model start time with current model time in coupler.res
    file=$gmemdir/RESTART/${PDY}.${cyc}0000.coupler.res
    file2=$(echo $(basename $file))
    file2=$(echo $file2 | cut -d. -f3-) # remove the date from file
    $NLN $file $DATA/INPUT/$file2
  fi

  increment_file=$memdir/${CDUMP}.t${cyc}z.atminc.nc
  if [ -f $increment_file ]; then
    $NLN $increment_file $DATA/INPUT/fv3_increment.nc
    read_increment=".true."
    res_latlon_dynamics="fv3_increment.nc"
  else
    read_increment=".false."
    res_latlon_dynamics="''"
  fi

else ## cold start                            

  for file in $memdir/INPUT/*.nc; do
    file2=$(echo $(basename $file))
    fsuf=$(echo $file2 | cut -c1-3)
    if [ $fsuf = "gfs" -o $fsuf = "sfc" ]; then
      $NLN $file $DATA/INPUT/$file2
    fi
  done

fi 

if [ $machine = 'sandbox' ]; then
	echo SUB ${FUNCNAME[0]}: Checking initial condition, overriden in sandbox mode!
else
	nfiles=$(ls -1 $DATA/INPUT/* | wc -l)
	if [ $nfiles -le 0 ]; then
		  echo SUB ${FUNCNAME[0]}: Initial conditions must exist in $DATA/INPUT, ABORT!
		  msg=”"SUB ${FUNCNAME[0]}: Initial conditions must exist in $DATA/INPUT, ABORT!"
		  postmsg "$jlogfile" "$msg"
		  exit 1
	fi
fi

#--------------------------------------------------------------------------
# Grid and orography data
for n in $(seq 1 $ntiles); do
  $NLN $FIXfv3/$CASE/${CASE}_grid.tile${n}.nc     $DATA/INPUT/${CASE}_grid.tile${n}.nc
  $NLN $FIXfv3/$CASE/${CASE}_oro_data.tile${n}.nc $DATA/INPUT/oro_data.tile${n}.nc
done
$NLN $FIXfv3/$CASE/${CASE}_mosaic.nc  $DATA/INPUT/grid_spec.nc

# GFS standard input data

IALB=${IALB:-1}
IEMS=${IEMS:-1}
ISOL=${ISOL:-2}
IAER=${IAER:-111}
ICO2=${ICO2:-2}

if [ ${new_o3forc:-YES} = YES ]; then
    O3FORC=ozprdlos_2015_new_sbuvO3_tclm15_nuchem.f77
else
    O3FORC=global_o3prdlos.f77
fi
H2OFORC=${H2OFORC:-"global_h2o_pltc.f77"}
$NLN $FIX_AM/${O3FORC}                         $DATA/global_o3prdlos.f77
$NLN $FIX_AM/${H2OFORC}                        $DATA/global_h2oprdlos.f77
$NLN $FIX_AM/global_solarconstant_noaa_an.txt  $DATA/solarconstant_noaa_an.txt
$NLN $FIX_AM/global_sfc_emissivity_idx.txt     $DATA/sfc_emissivity_idx.txt

$NLN $FIX_AM/global_co2historicaldata_glob.txt $DATA/co2historicaldata_glob.txt
$NLN $FIX_AM/co2monthlycyc.txt                 $DATA/co2monthlycyc.txt
if [ $ICO2 -gt 0 ]; then
  for file in $(ls $FIX_AM/fix_co2_proj/global_co2historicaldata*) ; do
    $NLN $file $DATA/$(echo $(basename $file) | sed -e "s/global_//g")
  done
fi

$NLN $FIX_AM/global_climaeropac_global.txt     $DATA/aerosol.dat
if [ $IAER -gt 0 ] ; then
  for file in $(ls $FIX_AM/global_volcanic_aerosols*) ; do
    $NLN $file $DATA/$(echo $(basename $file) | sed -e "s/global_//g")
  done
fi

# Fix files
FNGLAC=${FNGLAC:-"$FIX_AM/global_glacier.2x2.grb"}
FNMXIC=${FNMXIC:-"$FIX_AM/global_maxice.2x2.grb"}
FNTSFC=${FNTSFC:-"$FIX_AM/RTGSST.1982.2012.monthly.clim.grb"}
FNSNOC=${FNSNOC:-"$FIX_AM/global_snoclim.1.875.grb"}
FNZORC=${FNZORC:-"igbp"}
FNALBC2=${FNALBC2:-"$FIX_AM/global_albedo4.1x1.grb"}
FNAISC=${FNAISC:-"$FIX_AM/CFSR.SEAICE.1982.2012.monthly.clim.grb"}
FNTG3C=${FNTG3C:-"$FIX_AM/global_tg3clim.2.6x1.5.grb"}
FNVEGC=${FNVEGC:-"$FIX_AM/global_vegfrac.0.144.decpercent.grb"}
FNMSKH=${FNMSKH:-"$FIX_AM/seaice_newland.grb"}
FNVMNC=${FNVMNC:-"$FIX_AM/global_shdmin.0.144x0.144.grb"}
FNVMXC=${FNVMXC:-"$FIX_AM/global_shdmax.0.144x0.144.grb"}
FNSLPC=${FNSLPC:-"$FIX_AM/global_slope.1x1.grb"}
FNALBC=${FNALBC:-"$FIX_AM/global_snowfree_albedo.bosu.t${JCAP}.${LONB}.${LATB}.rg.grb"}
FNVETC=${FNVETC:-"$FIX_AM/global_vegtype.igbp.t${JCAP}.${LONB}.${LATB}.rg.grb"}
FNSOTC=${FNSOTC:-"$FIX_AM/global_soiltype.statsgo.t${JCAP}.${LONB}.${LATB}.rg.grb"}
FNABSC=${FNABSC:-"$FIX_AM/global_mxsnoalb.uariz.t${JCAP}.${LONB}.${LATB}.rg.grb"}
FNSMCC=${FNSMCC:-"$FIX_AM/global_soilmgldas.statsgo.t${JCAP}.${LONB}.${LATB}.grb"}

# If the appropriate resolution fix file is not present, use the highest resolution available (T1534)
[[ ! -f $FNALBC ]] && FNALBC="$FIX_AM/global_snowfree_albedo.bosu.t1534.3072.1536.rg.grb"
[[ ! -f $FNVETC ]] && FNVETC="$FIX_AM/global_vegtype.igbp.t1534.3072.1536.rg.grb"
[[ ! -f $FNSOTC ]] && FNSOTC="$FIX_AM/global_soiltype.statsgo.t1534.3072.1536.rg.grb"
[[ ! -f $FNABSC ]] && FNABSC="$FIX_AM/global_mxsnoalb.uariz.t1534.3072.1536.rg.grb"
[[ ! -f $FNSMCC ]] && FNSMCC="$FIX_AM/global_soilmgldas.statsgo.t1534.3072.1536.grb"


# soft link commands insert here
if [ $cplwav = TRUE ]
then
	  echo SUB ${FUNCNAME[0]}: Linking input data for WW3
	  # soft link commands insert here
fi
if [ $cplflx = TRUE ]	#cplflx
then
	  echo SUB ${FUNCNAME[0]}: Linking input data for HYCOM
	  # soft link commands insert here
fi
if [ $cplchem = TRUE ]
then
	  echo SUB ${FUNCNAME[0]}: Linking input data for GSD
	  # soft link commands insert here
fi
# More components
}

namelist_and_diagtable()
{
# namelist output for a certain component
echo SUB ${FUNCNAME[0]}: Creating name lists and model configure file for FV3

# Call child scripts in current script directory

source $SCRIPTDIR/parsing_namelists_FV3.sh
source $SCRIPTDIR/parsing_model_configure_FV3.sh

echo SUB ${FUNCNAME[0]}: FV3 name lists and model configure file created
if [ $cplwav = TRUE ]
then
	  echo SUB ${FUNCNAME[0]}: Creating name list for WW3
	  sh parsing_namelist_WW3.sh
	  # name list insert here
fi
if [ $cplflx = TRUE ]
then
	  echo SUB ${FUNCNAME[0]}: Creating name list for HYCOM
	  sh parsing_namelist_HYCOM.sh
	  # name list insert here
fi
if [ $cplchem = TRUE ]
then
	  echo SUB ${FUNCNAME[0]}: Creating name list for GSD
	  sh parsing_namelist_GSD.sh
	  # name list insert here
fi
# More components
}

nems_config_writing()
{
# selection logic including combination of components
# Argument: 
#   Compset: directly from second argument of main script
# echo 'This section writes nems configuration file for a compset'
echo SUB ${FUNCNAME[0]} begins
case "$1" in
'ATM')
if [ -e nems.configure ]; then
	rm -f nems.configure
fi
source $SCRIPTDIR/nems.configure_temp_fv3.sh
;;
'ATM_WAVE')
echo SUB ${FUNCNAME[0]}: Writing nems_config for FV3-WW3
# nems_config for FV#-WW3 here
;;
'ATM_WAVE_CHEM')
echo SUB ${FUNCNAME[0]}: Writing nems_config for FV3-WW3-GSD
# nems_config for FV#-WW3 here
;;
*)
echo SUB ${FUNCNAME[0]}: Component set not supported, exiting
exit 1
esac
}

execution()
{
# launcher for given app based on the compset
# Argument: combination
# 
echo SUB ${FUNCNAME[0]}: !!Only output the command instead of actually executing it.
case "$1" in
  	'ATM')
  		#------------------------------------------------------------------
		# run the executable
		$NCP $FCSTEXECDIR/$FCSTEXEC $DATA/.
		export OMP_NUM_THREADS=$NTHREADS_FV3
		$APRUN_FV3 $DATA/$FCSTEXEC 1>&1 2>&2
		export ERR=$?
		export err=$ERR
		$ERRSCRIPT || exit $err
  		echo SUB ${FUNCNAME[0]}: mpirun -np XX executable_FV3
  		;;
  	'ATM_WAVE')
  		echo SUB ${FUNCNAME[0]}: mpirun -np XX executable_FV3-WW3
  		;;
    'ATM_WAVE_CHEM')
        echo SUB ${FUNCNAME[0]}: mpirun -np XX executable_FV3-WW3-GSD
        ;;
    *)
        echo SUB ${FUNCNAME[0]}: Component set $1 not supported, exiting
        exit 1
esac
}

data_out()
{
# data in take for all active components
# Arguments: None 
# 
#------------------------------------------------------------------
# make symbolic links to write forecast files directly in memdir

cd $DATA
if [ $QUILTING = ".true." -a $OUTPUT_GRID = "gaussian_grid" ]; then
  fhr=$FHMIN
  while [ $fhr -le $FHMAX ]; do
    FH3=$(printf %03i $fhr)
    atmi=atmf${FH3}.$OUTPUT_FILE
    sfci=sfcf${FH3}.$OUTPUT_FILE
    logi=logf${FH3}
    atmo=$memdir/${CDUMP}.t${cyc}z.atmf${FH3}.$OUTPUT_FILE
    sfco=$memdir/${CDUMP}.t${cyc}z.sfcf${FH3}.$OUTPUT_FILE
    logo=$memdir/${CDUMP}.t${cyc}z.logf${FH3}.$OUTPUT_FILE
    eval $NLN $atmo $atmi
    eval $NLN $sfco $sfci
    eval $NLN $logo $logi
    FHINC=$FHOUT
    if [ $FHMAX_HF -gt 0 -a $FHOUT_HF -gt 0 -a $fhr -lt $FHMAX_HF ]; then
      FHINC=$FHOUT_HF
    fi
    fhr=$((fhr+FHINC))
  done
else
  for n in $(seq 1 $ntiles); do
    eval $NLN nggps2d.tile${n}.nc       $memdir/nggps2d.tile${n}.nc
    eval $NLN nggps3d.tile${n}.nc       $memdir/nggps3d.tile${n}.nc
    eval $NLN grid_spec.tile${n}.nc     $memdir/grid_spec.tile${n}.nc
    eval $NLN atmos_static.tile${n}.nc  $memdir/atmos_static.tile${n}.nc
    eval $NLN atmos_4xdaily.tile${n}.nc $memdir/atmos_4xdaily.tile${n}.nc
  done
fi

#------------------------------------------------------------------
if [ $SEND = "YES" ]; then
  # Copy model restart files
  cd $DATA/RESTART
  mkdir -p $memdir/RESTART

  # Only save restarts at single time in RESTART directory
  # Either at restart_interval or at end of the forecast
  if [ $restart_interval -eq 0 -o $restart_interval -eq $FHMAX ]; then

    # Add time-stamp to restart files at FHMAX
    RDATE=$($NDATE +$FHMAX $CDATE)
    rPDY=$(echo $RDATE | cut -c1-8)
    rcyc=$(echo $RDATE | cut -c9-10)
    for file in $(ls * | grep -v 0000); do
      $NMV $file ${rPDY}.${rcyc}0000.$file
    done

  else

    # time-stamp exists at restart_interval time, just copy
    RDATE=$($NDATE +$restart_interval $CDATE)
    rPDY=$(echo $RDATE | cut -c1-8)
    rcyc=$(echo $RDATE | cut -c9-10)
    for file in ${rPDY}.${rcyc}0000.* ; do
      $NCP $file $memdir/RESTART/$file
    done

  fi

fi

echo SUB ${FUNCNAME[0]}: copying output data for FV3
# copy commands insert here

if [ $cplwav = TRUE ]
then
	  echo SUB ${FUNCNAME[0]}: copying output data for WW3
	  # copy commands insert here
fi
if [ $cplflx = TRUE ]
then
	  echo SUB ${FUNCNAME[0]}: copying output data for HYCOM
	  # copy commands insert here
fi
if [ $cplchem = TRUE ]
then
	  echo SUB ${FUNCNAME[0]}: copying output data for GSD
	  # copy commands insert here
fi

# More components
}

#######################
# Main body starts here
#######################

cplflx=${CPLFLX:-0} # default off,import from outside source
cplwav=${CPLWAV:-0} # ? how to control 1-way/2-way?
#export cplwav=TRUE
cplchem=${CPLCHEM:-0} #

if [ -z $machine ]; then
	machine=sandbox
        echo "MAIN: !!!Running in sandbox mode!!!"
fi

select_combination
echo MAIN: $combination selected

echo MAIN: Forecast script started for $combination on $machine
set_environment $machine
echo MAIN: ENV Configured to run

echo MAIN: Loading variables
source $SCRIPTDIR/forecast_def.sh
echo MAIN: Finish loading variables

data_link
echo MAIN: Input data linked

if [ $machine = 'sandbox' ]; then
	cd $SCRIPTDIR
	echo MAIN: !!!Sandbox mode, writing to current directory!!!
fi
echo MAIN: Writing name lists and model configuration
namelist_and_diagtable
echo MAIN: Name lists and model configuration written

nems_config_writing $combination
echo MAIN: NEMS configured

if [ $machine = 'sandbox' ]; then
	echo MAIN: mpirun commands here!
else
	execution $combination
fi
sleep 1s

#rm -f nems.configure
#cat >> nems.configure <<EOF
#EARTH_component_list: ATM
#ATM_model:            fv3
#runSeq::
#	 ATM
#::
#EOF

if [ $machine != 'sandbox' ]; then		
	data_out
	sleep 1s
else
	echo MAIN: Running on sandbox mode, no output linking
fi
echo MAIN: Output copied to COMROT

#------------------------------------------------------------------
# Clean up before leaving
if [ $KEEPDATA = "NO" ]; then rm -rf $DATA; fi

#------------------------------------------------------------------
set +x
#if [ $VERBOSE = "YES" ] ; then
#  echo $(date) EXITING $0 with return code $err >&2
#fi

echo MAIN: $combination Forecast completed at normal status
exit 0
