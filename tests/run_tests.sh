#!/bin/bash

# check mktemp
export MYMKTEMP="mktemp"
TMPFILE=`$MYMKTEMP 2> /dev/null`
if test $? -ne 0 ; then
    export MYMKTEMP="mktemp -t MPI_START_TESTS"
    TMPFILE=`$MYMKTEMP 2> /dev/null`
    if test $? -ne 0 ; then
        echo "Unable to find good mktemp!?"
        exit 0
    fi
fi
mymktemp=`$MYMKTEMP`
tempfiles=`$MYMKTEMP`
cat > $mymktemp << EOF
F=\`$MYMKTEMP \$*\`
echo \$F >> $tempfiles
echo \$F
EOF
chmod +x $mymktemp
export MYMKTEMP=$mymktemp

echo $mymktemp > $tempfiles

rm -f $TMPFILE    

DOWNLOAD_MY_SHUNIT=0
REMOVE_MY_SHUNIT=0

# tests to run
RUN_UNIT_TESTS=1
RUN_BASIC_TESTS=0
RUN_HOOK_TESTS=0
RUN_NP_TESTS=0
RUN_SCH_TESTS=0
RUN_FSDETECT_TESTS=0
RUN_AFFINITY_TESTS=0
# if running these tests, ensure you have proper environment loaded!
RUN_OMP_TESTS=0
RUN_MPICH2_TESTS=0
RUN_MVAPICH2_TESTS=0
RUN_MPICH_TESTS=0
RUN_OPENMPI_TESTS=0
RUN_LAM_TESTS=0

export MPI_OPENMPI_MPIEXEC_PARAMS="--mca btl ^openib"


#
# Check environment variables
#
export SHUNIT2=$PWD/shunit2
if test "x${SHUNIT2}" = "x" ; then
    if test "x${DOWNLOAD_MY_SHUNIT}" = "x1"; then
        wget -q http://devel.ifca.es/~enol/depot/shunit2 -O shunit2 --no-check-certificate 
        st=$?
        if test $st -ne 0 ; then
            echo "Could not download shunit, please set SHUNIT2 env variable to the correct location."
            exit 1
        fi
        export SHUNIT2=$PWD/shunit2
        REMOVE_MY_SHUNIT=1
    else
        echo "SHUNIT2 environment variable not defined!"
        echo "Please set it to the location of shunit2 script"
        exit 1
    fi
fi

if test "x${I2G_MPI_START}" = "x" ; then
    which mpi-start &> /dev/null
    if test $? -ne 0 ; then
        echo "I2G_MPI_START environment variable not defined!"
        echo "Please set it to the location of MPI-Start binary"
        exit 1
    else
        export I2G_MPI_START=mpi-start
    fi
fi

echo ""
echo "** Using $I2G_MPI_START for testing! **"
echo ""

#
# Run all the tests in the directory
#
exitcode=0
if test "x${RUN_UNIT_TESTS}" = "x1" ; then
    echo "***************************"
    echo "* Unit Tests"
    echo "* RFCs #30, #35"
    ./test_unit.sh || exitcode=1
    echo "* RFC #63"
    ./test_trac_63.sh || exitcode=1
    echo "* Issue #1, #9"
    ./test_issue_1_and_9.sh || exitcode=1
    echo "* Issue #6"
    ./test_issue_6.sh || exitcode=1
    echo "***************************"
fi
if test "x${RUN_BASIC_TESTS}" = "x1" ; then
    echo ""
    echo "***************************"
    echo "* Basic Tests"
    echo "* RFCs #16, #25"
    ./test_basic.sh || exitcode=1
    echo "* RFC #58"
    ./test_trac_58.sh || exitcode=1
    echo "* RFC #61"
    ./test_trac_61.sh || exitcode=1
    echo "***************************"
fi
if test "x${RUN_HOOK_TESTS}" = "x1" ; then
    echo ""
    echo "***************************"
    echo "* Hook Tests"
    ./test_hooks.sh || exitcode=1
    echo "* RFC #47"
    ./test_trac_47.sh || exitcode=1
    echo "***************************"
fi
if test "x${RUN_NP_TESTS}" = "x1" ; then
    echo ""
    echo "***************************"
    echo "* Process Distribution"
    echo "* RFC #41"
    ./test_pdistribution.sh || exitcode=1
    echo "***************************"
fi
if test "x${RUN_FSDETECT_TESTS}" = "x1" ; then
    echo ""
    echo "***************************"
    echo "* Filesystem Detection & File distribution"
    echo "* RFC #31"
    ./test_fsdetect.sh || exitcode=1
    echo "* RFC #53"
    ./test_trac_53.sh || exitcode=1
    echo "* RFC #32"
    ./test_trac_32.sh || exitcode=1
    echo "* RFC #44"
    ./test_trac_44.sh || exitcode=1
    echo "* RFC #60"
    ./test_trac_60.sh || exitcode=1
    echo "* RFC #5"
    ./test_trac_5.sh || exitcode=1
    echo "* Issue #3"
    ./test_issue_3.sh || exitcode=1
    echo "***************************"
fi
if test "x${RUN_SCH_TESTS}" = "x1" ; then
    echo ""
    echo "***************************"
    echo "* Scheduler Tests"
    echo "* RFC #4"
    echo "----------- PBS -----------"
    ./test_pbs.sh || exitcode=1
    echo "----------- SGE -----------"
    ./test_sge.sh || exitcode=1
    echo "----------- LSF -----------"
    echo "* RFC #11"
    ./test_lsf.sh || exitcode=1
    echo "---------- SLURM ----------"
    echo "* RFC #3"
    ./test_slurm.sh || exitcode=1
    echo "---------- DUMMY ----------"
    ./test_dummy.sh || exitcode=1
    echo "***************************"
fi
if test "x${RUN_OMP_TESTS}" = "x1" ; then
    echo ""
    echo "***************************"
    echo "* OMP Tests"
    echo "* RFC #21"
    ./test_unit_omp.sh || exitcode=1
    ./test_omp.sh || exitcode=1
    echo "***************************"
fi
if test "x${RUN_MPICH2_TESTS}" = "x1" ; then
    echo ""
    echo "***************************"
    echo "* MPICH2 Tests"
    export I2G_MPI_TYPE=mpich2
    # XXX this is for hydra 1.2.1p1 may change in other versions...
    export HYDRA_BOOTSTRAP=fork
    ./test_mpi.sh || exitcode=1
    echo "* RFC #50"
    ./test_trac_50.sh || exitcode=1
    if test "x${RUN_AFFINITY_TESTS}" = "x1" ; then
        echo "* RFC #48"
        ./test_affinity_trac_48.sh || exitcode=1
    fi
    echo "***************************"
fi
if test "x${RUN_MPICH_TESTS}" = "x1" ; then
    echo ""
    echo "***************************"
    echo "* MPICH Tests"
    export I2G_MPI_TYPE=mpich
    ./test_mpi.sh || exitcode=1
    echo "***************************"
fi
if test "x${RUN_OPENMPI_TESTS}" = "x1" ; then
    echo ""
    echo "***************************"
    echo "* Open MPI Tests"
    export I2G_MPI_TYPE=openmpi
    ./test_mpi.sh || exitcode=1
    # test for bug 38
    echo "* RFC #38"
    ./test_trac_38.sh || exitcode=1
    if test "x${RUN_AFFINITY_TESTS}" = "x1" ; then
        echo "* RFC #27"
        ./test_affinity_trac_27.sh || exitcode=1
    fi
    echo "***************************"
fi
if test "x${RUN_LAM_TESTS}" = "x1" ; then
    echo ""
    echo "***************************"
    echo "* LAM Tests"
    export I2G_MPI_TYPE=lam
    ./test_mpi.sh || exitcode=1
    echo "***************************"
fi
if test "x${RUN_MVAPICH2_TESTS}" = "x1" ; then
    echo ""
    echo "***************************"
    echo "* MVAPICH2 Tests"
    export I2G_MPI_TYPE=mvapich2
    ./test_mpi.sh || exitcode=1
    echo "***************************"
fi

echo ""

if test $REMOVE_MY_SHUNIT -eq 1 ; then
    rm $SHUNIT2
fi

for f in `cat $tempfiles`; do
    if [ -e $f ] ; then
        rm -rf $f
    fi
done
rm $tempfiles

if test $exitcode -ne 0 ; then
    echo "***************************"
    echo " SOME OF THE TESTS FAILED! "
    echo "***************************"
fi

exit $exitcode 
