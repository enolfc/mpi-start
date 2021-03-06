#!/bin/bash

#
# Copyright (c) 2006-2007 High Performance Computing Center Stuttgart,
#                         University of Stuttgart.  All rights reserved.
#           (c) 2009-2010 Instituto de Fisica de Cantabria - CSIC. 
#


#======================================================================
# MPI_START_SHARED_FS
# Global variable that specifies if we are on a 
# shared filesystem or not. 
# 0 - fs NOT shared
# 1 - fs is shared 
#======================================================================

#======================================================================
# Helper  function of the callback hooks. The user provides a callback
# function/script that is called with each host in the job.
#
# $1 name of the callback function or host
#======================================================================
mpi_start_foreach_host () {
    if test "x$1" = "x"  ; then
        error_msg "mpi_start_foreach called without callback function paramater."
        return 1
    fi
    
    # call callback function
    debug_msg "loop over machine file and call user specific callback"
    for i in `cat $MPI_START_MACHINEFILE | sort -u`; do
        CMD="$1 $i"
        debug_msg " call : $CMD"
        $CMD
    done
}


#======================================================================
# Function to query if we are on a shared filesystem 
# or not. Will set MPI_START_SHARED_FS to 0 or 1
#======================================================================
mpi_start_detect_shared_fs () {
    if test "x$MPI_START_SHARED_FS" = "x" ; then
        debug_msg "detect shared filesystem"

        if test "x${MPI_START_UNAME}" = "xlinux" ; then
            #MOUNT_POINTS=`cat "/etc/mtab" | cut -d ' '  -f2`
            #MOUNT_POINTS_FS=`cat "/etc/mtab" | cut -d ' ' -f3`
            # alternative system: use mount
            MOUNT_POINTS=`mount | sed 's/.* on \([^ ]*\) type \([^ ]*\) .*/\1/'`
            MOUNT_POINTS_FS=`mount | sed 's/.* on \([^ ]*\) type \([^ ]*\) .*/\2/'`
        elif test "x${MPI_START_UNAME}" = "xdarwin" ; then
            # this could be more efficient if only done once.
            MOUNT_POINTS=`mount | sed 's/.* on \(.*\) (\([^,]*\),.*/\1/'`
            MOUNT_POINTS_FS=`mount | sed 's/.* on \(.*\) (\([^,]*\),.*/\2/'` 
        else
            warn_msg "FS detection not supported in your OS, assuming not shared"
            export MPI_START_SHARED_FS=0;
            return 0
        fi

        CUR_DIR=$PWD
        LOCAL_FS_TYPE="unknown"

        # dump mount points
        debug_msg " dump mount point information:"
        MOUNT_POINT_INDEX=1
        for MOUNT_POINT in $MOUNT_POINTS ; do
            MOUNT_POINT_FS=`echo  $MOUNT_POINTS_FS | cut -d ' ' -f$MOUNT_POINT_INDEX `
            debug_msg " => $MOUNT_POINT = $MOUNT_POINT_FS"
            MOUNT_POINT_INDEX=$(($MOUNT_POINT_INDEX+1))
        done
        debug_msg " current working directory : $CUR_DIR"

        while test "x$CUR_DIR" != "x"  ; do
            IS_LINK=`readlink -n $CUR_DIR`
            if test "x$IS_LINK" != "x" ; then
                debug_msg " found link $CUR_DIR -> $IS_LINK"
                if test "${IS_LINK#\/}" = "${IS_LINK}" ; then
                    if test `dirname $CUR_DIR` = "/" ; then
                        CUR_DIR="/${IS_LINK}"
                    else
                        CUR_DIR=`dirname $CUR_DIR`/${IS_LINK}
                    fi
                else
                    CUR_DIR=${IS_LINK}
                fi
                debug_msg "            resolved to $CUR_DIR"
            fi

            # be sure to remove trailing slashes (unless it is /!)
            if test "x$CUR_DIR" != "x/"; then
                CUR_DIR=${CUR_DIR%"/"}
            fi

            MOUNT_POINT_INDEX=1
            for MOUNT_POINT in $MOUNT_POINTS ; do
                if test "x$MOUNT_POINT" = "x$CUR_DIR" ; then
                    debug_msg " found mount point ($MOUNT_POINT) for working directory"
                    LOCAL_FS_TYPE=`echo $MOUNT_POINTS_FS | cut -d ' ' -f$MOUNT_POINT_INDEX `
                    break 2
                fi
                MOUNT_POINT_INDEX=$(($MOUNT_POINT_INDEX+1))
            done
            # if we reach this point no mount point mached
            # lets try another round with parent dir of CUR_DIR
            # but only if we not alread reached the root
            if test "x$CUR_DIR" != "x/"  ; then 
                CUR_DIR=`dirname $CUR_DIR`
            else
                # we are done
                break
            fi
        done

        echo $LOCAL_FS_TYPE | grep "\<nfs[0-9]\>" > /dev/null
        st=$?
        if test $st -eq 0 ; then
            LOCAL_FS_TYPE="nfs"
        fi

        case $LOCAL_FS_TYPE in
        nfs|gfs|afs|smb|gpfs|lustre)
            debug_msg " found network fs : $LOCAL_FS_TYPE";
            export MPI_START_SHARED_FS=1;
             ;;
        *)
            debug_msg " found local fs : $LOCAL_FS_TYPE";
            export MPI_START_SHARED_FS=0;
            ;;
        esac
    fi
    return 0
}


#======================================================================
# This hook will use mpi_mt, mpiexec or cptoshared to distribute files.
#======================================================================
mpi_start_pre_run_hook_copy () {
    debug_msg "mpi_start_pre_run_hook_copy"

    if test $MPI_START_NHOSTS -le 1 ; then
        debug_msg "only localhost, skip distribution"
        return 0
    fi

	#check all available file distribution plugins
    priority=255
    chosenDistrMethod="undef"

    #check if some file distribution method has been explicitely given
    #if it was not, try to pick the best method
    if test "x$I2G_MPI_FILE_DIST" = "x"
    then
        mpi_start_get_plugin "*.filedist"
    	for i in $MPI_START_PLUGIN_FILES ; do
	        unset check_distribution_method
	        . $i
	        check_distribution_method
	        returnPrior=$?
            #should we change the file distribution method?
	        if test $priority -gt $returnPrior ; then
	            chosenDistrMethod=$i	
	            priority=$returnPrior
                I2G_MPI_FILE_DIST=`echo "$i" | sed -e 's/^[-.0-9a-zA-Z_/]*\///g' | sed -e 's/\.filedist//g'`
	        fi
    	done
    else
        mpi_start_get_plugin "$I2G_MPI_FILE_DIST.filedist" 1
        chosenDistrMethod="$MPI_START_PLUGIN_FILES"
    fi
    debug_msg "I2G_MPI_FILE_DIST => $I2G_MPI_FILE_DIST"

    #if no plugin was suitable, program is interrupted
    if test "x$chosenDistrMethod" = "xundef" ; then
        error_msg "no file distribution method was found"
        dump_env
        exit 1
    fi

    # create tarball
    mpi_start_mktemp
    export TARBALL=$MPI_START_TEMP_FILE
    status=$?
    if [ $status -ne 0 -o "x$TARBALL" = "x" ]; then
        error_msg "Failed to create tarball for file distribution"
        exit 1
    fi
    TARBALL_BASENAME=`basename $TARBALL`
   
    # try and get the whole job directory
    if test "x$EDG_WL_RB_BROKERINFO" = "x" ; then
        MYDIR=`pwd`
    else
        MYDIR=`dirname $EDG_WL_RB_BROKERINFO`
    fi

    # XXX find a way to deal with this with bsd tar
    #HIDDEN_FILES="$PWD/.[a-zA-Z0-9]*"

    #EXTRATAROPTS=""
    #if test "x${MPI_START_UNAME}" = "xlinux" ; then
    #    EXTRATAROPTS="--ignore-failed-read $PWD/.[a-zA-Z0-9]*"
    #fi
    TARCMD="tar czf $TARBALL $MYDIR"
    if test "x$I2G_MPI_START_DEBUG" = "x1" ; then 
        $TARCMD
        st=$?
    else
        $TARCMD > /dev/null 2>&1
        st=$?
    fi
    if test $st -ne 0 ; then
        error_msg "Unable to create tarball for file distribution, aborting"
        dump_env
        exit 1
    fi

    unset copy
    unset copy_from_node 
    . $chosenDistrMethod > /dev/null 2>&1
    if test $? -ne 0 ; then
        error_msg "Unable to load distribution method $chosenDistrMethod"
        dump_env
        exit 1
    fi
    copy
    status=$?

    rm -f $TARBALL
    return $status
}


#======================================================================
# Run the pre hook defined in the file passed as parameter
#======================================================================
mpi_start_run_pre_hook () {
    debug_msg "mpi_start_run_pre_hook"

    if test "x$1" = "x" ; then
        return 0 
    fi
    if test -e $1 ; then 
        debug_msg "Try to run pre hooks at $1"
        unset pre_run_hook
        . $1
        type pre_run_hook > /dev/null 2>&1
        result=$?
        if test $result -ne 0 ; then
            debug_msg "pre_run_hook is not defined, ignoring"
            return 0
        fi
		debug_msg "call pre_run hook"
        if test "x$I2G_MPI_START_VERBOSE" = "x1" -a "x$2" = "1"; then
            echo "-<START PRE-RUN HOOK>---------------------------------------------------";
        fi
        pre_run_hook
        result=$?
        if test "x$I2G_MPI_START_VERBOSE" = "x1" -a "x$2" = "1"; then
            echo "-<STOP  PRE-RUN HOOK>---------------------------------------------------"; 
        fi
        if test $result -ne 0 ; then 
            error_msg "pre-run hook returned : $result"
            dump_env
            exit $result
        fi
	fi	
}


#======================================================================
# This hook is called before the "mpirun" is started.
#======================================================================
mpi_start_pre_run_hook () {
    debug_msg "mpi_start_pre_run_hook"

    # call generic function
    mpi_start_pre_run_hook_generic
    return $?
}


#======================================================================
# This hook is called befor the "mpirun" has been finished.
#======================================================================
mpi_start_pre_run_hook_generic () {
    debug_msg "mpi_start_pre_run_hook_generic"

    mpi_start_get_plugin "*.hook" 
    for hook in $MPI_START_PLUGIN_FILES; do
        mpi_start_run_pre_hook "$hook"
    done

    # determine local filesystem
    mpi_start_detect_shared_fs

    mpi_start_get_plugin "mpi-start.hooks.local" 1
    MPI_START_HOOKS_LOCAL=$MPI_START_PLUGIN_FILES
    mpi_start_run_pre_hook "$MPI_START_HOOKS_LOCAL" 1

    mpi_start_run_pre_hook "$I2G_MPI_PRE_RUN_HOOK" 1

    # make sure I2G_MPI_APPLICATION is a single thing, the rest is arguments
    set -- foo $I2G_MPI_APPLICATION
    shift
    export I2G_MPI_APPLICATION=$1
    shift
    export I2G_MPI_APPLICATION_ARGS="$* $I2G_MPI_APPLICATION_ARGS"

    if test "x${I2G_MPI_APPLICATION}" != "x" ; then
        if test ! -x $I2G_MPI_APPLICATION; then
            chmod +x $I2G_MPI_APPLICATION 2> /dev/null # do not care if it fails.
        fi
        # add complete path to I2G_MPI_APPLICATIONlication so . does not need to be in PATH
        which $I2G_MPI_APPLICATION > /dev/null 2>&1
        if test $? -ne 0 ; then 
            if test "${I2G_MPI_APPLICATION/#\/}" = "${I2G_MPI_APPLICATION}" ;  then
                export I2G_MPI_APPLICATION=$PWD/$I2G_MPI_APPLICATION
            fi
        fi
    fi

    if  test "x$MPI_START_SHARED_FS" != "x1" -o "x$MPI_START_DISTRIBUTE_PROXY" = "x1" ; then 
        mpi_start_pre_run_hook_copy
    else
        debug_msg "fs shared -> do not distribute binary"
    fi
    return $?
}


#======================================================================
# Run the post hook defined in the file passed as parameter
#======================================================================
mpi_start_run_post_hook () {
    debug_msg "mpi_start_run_post_hook"

    if test "x$1" = "x" ; then
        return 0 
    fi
    if test -e $1 ; then 
        debug_msg "Try to run post hooks at $1"
        unset post_run_hook
        . $1
        type post_run_hook > /dev/null 2>&1
        result=$?
        if test $result -ne 0 ; then
            debug_msg "post_run_hook is not defined, ignoring"
            return 0
        fi
        debug_msg "call post-run hook"
        if test "x$I2G_MPI_START_VERBOSE" = "x1" -a "x$2" = "1"; then
            echo "-<START POST-RUN HOOK>--------------------------------------------------";
        fi
        post_run_hook
        result=$?
        if test "x$I2G_MPI_START_VERBOSE" = "x1" -a "x$2" = "1"; then
            echo "-<STOP  POST-RUN HOOK>--------------------------------------------------"; 
        fi
        if test $result -ne 0 ; then 
            error_msg "post-run hook returned : $result"
            dump_env
            exit $result
        fi
    fi
}
 

#======================================================================
# This hook is called after the "mpirun" has been finished.
#======================================================================
mpi_start_post_run_hook_generic () {
    debug_msg "mpi_start_post_run_hook_generic"

    mpi_start_get_plugin "*.hook" 
    for hook in $MPI_START_PLUGIN_FILES; do
        mpi_start_run_post_hook "$hook"
    done

    mpi_start_get_plugin "mpi-start.hooks.local" 1 
    MPI_START_HOOKS_LOCAL=$MPI_START_PLUGIN_FILES
    mpi_start_run_post_hook "$MPI_START_HOOKS_LOCAL" 1

    mpi_start_run_post_hook "$I2G_MPI_POST_RUN_HOOK" 1

    # If cleanup is defined, call it (if not disabled!)
    if test "x$MPI_START_DISABLE_CLEANUP" != "xyes" ; then
        if test "x$chosenDistrMethod" != "x" -a "x$chosenDistrMethod" != "xundef" ; then
            unset clean
            . $chosenDistrMethod > /dev/null 2>&1
            debug_msg "Calling post-hook file cleaning"
            clean
        fi
    fi
}


#======================================================================
# This hook is called after the "mpirun" has been finished.
#======================================================================
mpi_start_post_run_hook () {
    debug_msg "mpi_start_post_run_hook"

    # call generic function
    mpi_start_post_run_hook_generic
    return $?
}

