#!/bin/bash

# MPI-Start unit tests for mpi-start main code

oneTimeSetUp() {
    export I2G_MPI_START_ENABLE_TESTING="TEST"
    # source the mpi-start code to have all functions
    . $I2G_MPI_START
    mpi_start_check_options
    mpi_start_get_plugin "openmp.hook" 1
    . $MPI_START_PLUGIN_FILES 
}

oneTimeTearDown () {
    clean_up
}

setUp () {
    unset I2G_MPI_NP
    unset I2G_MPI_APPLICATION
    unset I2G_MPI_START_DEBUG
    unset I2G_MPI_START_VERBOSE
    unset I2G_MPI_START_TRACE
    unset I2G_MPI_SINGLE_PROCESS
    unset MPI_USE_OMP
    unset MPI_START_ENV_VARIABLES 
    unset I2G_MPI_PER_NODE
    unset I2G_MPI_PER_SOCKET
    unset I2G_MPI_PER_CORE
    unset OMP_NUM_THREADS
    export MPI_START_SOCKETS=2
    export MPI_START_COREPERSOCKET=4
    export MPI_START_NSLOTS_PER_HOST=5
}

tearDown() {
    for file in $MPI_START_CLEANUP_FILES; do
        [ -f $file ] && rm -f $file
    done
}

testDefaultEnabled() {
    pre_run_hook
    echo $MPI_START_ENV_VARIABLES | grep 'OMP_NUM_THREADS' >& /dev/null
    st=$?
    assertEquals 0 $st
}

testEnable() {
    export MPI_USE_OMP=1
    pre_run_hook
    echo $MPI_START_ENV_VARIABLES | grep 'OMP_NUM_THREADS' >& /dev/null
    st=$?
    assertEquals 0 $st
}

testDisable() {
    export MPI_USE_OMP=0
    pre_run_hook
    echo $MPI_START_ENV_VARIABLES | grep 'OMP_NUM_THREADS' >& /dev/null
    st=$?
    assertEquals 1 $st
}

testNodeDistribution() {
    export I2G_MPI_APPLICATION_STDOUT=`$MYMKTEMP`
    I2G_MPI_PER_NODE=1
    pre_run_hook
    mpi_start_execute_wrapper echo $OMP_NUM_THREADS
    assertEquals 8 `cat $I2G_MPI_APPLICATION_STDOUT`
    I2G_MPI_PER_NODE=2
    pre_run_hook
    mpi_start_execute_wrapper echo $OMP_NUM_THREADS
    assertEquals 4 `cat $I2G_MPI_APPLICATION_STDOUT`
    I2G_MPI_PER_NODE=4
    pre_run_hook
    mpi_start_execute_wrapper echo $OMP_NUM_THREADS
    assertEquals 2 `cat $I2G_MPI_APPLICATION_STDOUT`
    I2G_MPI_PER_NODE=8
    pre_run_hook
    mpi_start_execute_wrapper echo $OMP_NUM_THREADS
    assertEquals 1 `cat $I2G_MPI_APPLICATION_STDOUT`
    I2G_MPI_PER_NODE=16
    pre_run_hook
    mpi_start_execute_wrapper echo $OMP_NUM_THREADS
    assertEquals 1 `cat $I2G_MPI_APPLICATION_STDOUT`
    I2G_MPI_PER_NODE=3
    pre_run_hook
    mpi_start_execute_wrapper echo $OMP_NUM_THREADS
    assertEquals 2 `cat $I2G_MPI_APPLICATION_STDOUT`
    rm -f $I2G_MPI_APPLICATION_STDOUT
}

testSocketDistribution() {
    export I2G_MPI_APPLICATION_STDOUT=`$MYMKTEMP`
    I2G_MPI_PER_SOCKET=1
    pre_run_hook
    mpi_start_execute_wrapper echo $OMP_NUM_THREADS
    assertEquals 4 `cat $I2G_MPI_APPLICATION_STDOUT`
    I2G_MPI_PER_SOCKET=2
    pre_run_hook
    mpi_start_execute_wrapper echo $OMP_NUM_THREADS
    assertEquals 2 `cat $I2G_MPI_APPLICATION_STDOUT`
    I2G_MPI_PER_SOCKET=4
    pre_run_hook
    mpi_start_execute_wrapper echo $OMP_NUM_THREADS
    assertEquals 1 `cat $I2G_MPI_APPLICATION_STDOUT`
    I2G_MPI_PER_SOCKET=8
    pre_run_hook
    mpi_start_execute_wrapper echo $OMP_NUM_THREADS
    assertEquals 1 `cat $I2G_MPI_APPLICATION_STDOUT`
    I2G_MPI_PER_SOCKET=3
    pre_run_hook
    mpi_start_execute_wrapper echo $OMP_NUM_THREADS
    assertEquals 1 `cat $I2G_MPI_APPLICATION_STDOUT`
    rm -f $I2G_MPI_APPLICATION_STDOUT
}

testCoreDistribution() {
    export I2G_MPI_APPLICATION_STDOUT=`$MYMKTEMP`
    I2G_MPI_PER_CORE=1
    pre_run_hook
    mpi_start_execute_wrapper echo $OMP_NUM_THREADS
    assertEquals 1 `cat $I2G_MPI_APPLICATION_STDOUT`
    I2G_MPI_PER_CORE=2
    pre_run_hook
    mpi_start_execute_wrapper echo $OMP_NUM_THREADS
    assertEquals 1 `cat $I2G_MPI_APPLICATION_STDOUT`
    I2G_MPI_PER_CORE=3
    pre_run_hook
    mpi_start_execute_wrapper echo $OMP_NUM_THREADS
    assertEquals 1 `cat $I2G_MPI_APPLICATION_STDOUT`
    rm -f $I2G_MPI_APPLICATION_STDOUT
}

testNoDistribution() {
    export I2G_MPI_APPLICATION_STDOUT=`$MYMKTEMP`
    pre_run_hook
    mpi_start_execute_wrapper echo $OMP_NUM_THREADS
    assertEquals 5 `cat $I2G_MPI_APPLICATION_STDOUT`
    rm -f $I2G_MPI_APPLICATION_STDOUT
}
. $SHUNIT2

