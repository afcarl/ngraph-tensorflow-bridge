# Test intended to be run using pytest
#
# If pytest is not installed on your server, you can install it in a virtual
# environment:
#
#   $ virtualenv -p /usr/bin/python venv-pytest
#   $ source venv-pytest/bin/activate
#   $ pip -U pytest
#   $ pytest test_resnet20_cifar10_ngraph_cpu_validation.py
#   $ deactivte
#
# This test has no command-line parameters, as it is run via pytest.
# This test does have environment variables that can alter how the run happens:
#
#     Parameter              Purpose & Default (if any)
#
#     TEST_RESNET20_CIFAR10_COMPARE_TO   Reference JSON file to compare ngraph
#                                        run to; default = no file
#     TEST_RESNET20_CIFAR10_EPOCHS       Number of epochs (steps) to run;
#                                        default=250
#     TEST_RESNET20_CIFAR10_EVAL_EPOCHS  Number of epoch to run between each
#                                        eval; default=#-of-EPOCHS
#     TEST_RESNET20_CIFAR10_BATCH_SIZE   Batch size per step; default=128
#
#     TEST_RESNET20_CIFAR10_DATA_DIR     Directory where CIFAR10 datafiles are
#                                        located
#     TEST_RESNET20_CIFAR10_LOG_DIR      Optional: dir to write log files to
#
# JUnit XML files can be generated using pytest's command-line options.
# For example:
# $ pytest -s ./test_resnet20_cifar10_cpu_daily_validation.py --junit-xml=../validation_tests_resnet20_cifar10_cpu.xml --junit-prefix=daily_validation_resnet20_cifar10_cpu
#
# Example of ngraph command-line used:
# $ KMP_BLOCKTIME=1 OMP_NUM_THREADS=56 KMP_AFFINITY=granularity=fine,compact,1,0 python cifar10_main.py --data_dir /tmp/cifar10_input_data --train_epochs 1 --batch_size 128 --resnet_size=20 --select_device NGRAPH --model_dir /tmp/cifar10-ngraph --epochs_between_evals 1 --inter_op 2
#

import sys
import os
import re
import json
import datetime as DT

import lib_validation_testing as VT


# Constants

# Log files
kResnet20CPUNgLog          = 'test_resnet20_cifar10_cpu_ngraph.log'
kResnet20SummaryLog        = 'test_resnet20_cifar10_cpu_summary.log'
kResnet20JenkinsSummaryLog = 'test_resnet20_cifar10_cpu_jenkins_oneline.log'
kResnet20CPUNgJson         = 'test_resnet20_cifar10_cpu_ngraph.json'

# Acceptable accuracy
kAcceptableAccuracyDelta = 0.02  # 0.02 = 2%

# Default number of epochs (steps) is 250
kDefaultEpochs = 250

# As per Alex Krizhevsky's description of the CIFAR-10 dataset at:
#   https://www.cs.toronto.edu/~kriz/cifar.html
kTrainEpochSize = 50000  

# Batch size is set with --data_dir.  For now, it is a constant
kTrainBatchSize = 128

# Relative path (from top of bridge repo) to cifar10_main.py script
kResnet20ScriptPath = 'test/resnet/cifar10_main.py'

# Python program to run script.  This should just be "python" (or "python2"),
# as the virtualenv relies on PATH resolution to find the python executable
# in the virtual environment's bin directory.
kPythonProg = 'python'

# Date and time that testing started, for the run stats collected later
kRunDateTime = DT.datetime.now()


def test_resnet20_cifar10_ngraph_cpu_backend():

    # This *must* be run inside the test, because env. var. PYTEST_CURRENT_TEST
    # only exists when inside the test function.
    ngtfDir = VT.findBridgeRepoDirectory()
    script = os.path.join(ngtfDir, kResnet20ScriptPath)
    VT.checkScript(script)

    dataDir = os.environ.get('TEST_RESNET20_CIFAR10_DATA_DIR', None)
    if not os.path.isdir(dataDir):
        raise Exception('Directory %s does not exist' % str(dataDir))

    epochs = int(os.environ.get('TEST_RESNET20_CIFAR10_EPOCHS', kDefaultEpochs))

    compareToFile = os.environ.get('TEST_RESNET20_CIFAR10_COMPARE_TO', None)

    # If we have a compare-file, then read JSON data into referenceResults
    if compareToFile:

        print
        print('Comparing ngraph results with reference results in %s'
              % compareToFile)

        fIn = open(compareToFile, 'r')
        referenceResults = json.load(fIn)
        fIn.close()

    # if compareToFile
    else:  referenceResults = None

    # Run with NGraph CPU backend, saving timing and accuracy
    VT.checkNGraphEnvironment()
    ngraphLog = VT.runResnetScript(logID=' nGraph',
                                   useNGraph=True,
                                   script=script,
                                   python=kPythonProg,
                                   epochs=epochs,
                                   batchSize=kTrainBatchSize,
                                   dataDirectory=dataDir,
                                   verbose=False)  # log-device-placement
    ngraphResults = \
        VT.collect_resnet20_cifar10_results(runType='nGraph CPU backend',
                                            log=ngraphLog,
                                            date=str(kRunDateTime),
                                            epochs=epochs,
                                            batchSize=kTrainBatchSize)

    if referenceResults:
        print
        print('Reference results (from JSON file) are:')
        print(json.dumps(referenceResults, indent=4))

    print
    print('Collected results for *nGraph* in this run are:')
    print(json.dumps(ngraphResults, indent=4))
    
    lDir = None
    if os.environ.has_key('TEST_RESNET20_CIFAR10_LOG_DIR'):
        lDir = os.path.abspath(os.environ['TEST_RESNET20_CIFAR10_LOG_DIR'])
        # Dump logs to files, for inclusion in Jenkins artifacts
        VT.writeLogToFile(ngraphLog,
                          os.path.join(lDir, kResnet20CPUNgLog))
        VT.writeJsonToFile(json.dumps(ngraphResults, indent=4),
                           os.path.join(lDir, kResnet20CPUNgJson))
        # Write Jenkins description, for quick perusal of results
        if referenceResults:
            VT.write_jenkins_resnet20_cifar10_description(referenceResults,
                                                          ngraphResults,
                                                          kAcceptableAccuracyDelta,
                                                          epochs,
                                                          os.path.join(lDir,
                                                                       kResnet20JenkinsSummaryLog))

    print
    print '----- RESNET20 CIFAR10 Testing Summary ----------------------------------------'

    summaryLog = None
    if lDir != None:
        summaryLog = os.path.join(lDir, kResnet20SummaryLog)

    logOut = VT.LogAndOutput(logFile=summaryLog)

    if referenceResults:
        # Sanity checks on ngraph results vs compare-to reference results.
        # Error messages are printed here, and assertions are triggered at the
        # end of this function.

        if referenceResults['epochs'] != ngraphResults['epochs']:
            logOut.line('ERROR: epochs do not match -- ref: %s epochs, ngraph: %s epochs'
                        % (str(referenceResults['epochs']),
                           str(ngraphResults['epochs'])))

        if referenceResults['batch-size'] != ngraphResults['batch-size']:
            logOut.line('ERROR: batch-sizes do not match -- ref: %s, ngraph: %s'
                        % (str(referenceResults['batch-size']),
                           str(ngraphResults['batch-size'])))
    # End: if referenceResults

    # Report commands
    logOut.line()
    if referenceResults:
        logOut.line('Reference run using CPU: %s' % referenceResults['command'])
    logOut.line('Run with NGraph CPU:     %s' % ngraphResults['command'])

    # Report parameters
    logOut.line()
    logOut.line('Epochs:                %d' % epochs)
    logOut.line('Batch size:            %d' % kTrainBatchSize)
    logOut.line('Epoch size:            %d (fixed in CIFAR10)'
                % kTrainEpochSize)
    logOut.line('nGraph back-end used:  %s' % 'CPU')
    logOut.line('Data directory:        %s' % dataDir)

    if referenceResults:
        refAccuracy = float(referenceResults['accuracy'])
    ngAccuracy = float(ngraphResults['accuracy'])

    # Report accuracy
    if referenceResults:
        acceptableDelta = refAccuracy * kAcceptableAccuracyDelta
        deltaAccuracy = abs(refAccuracy - ngAccuracy)
    logOut.line()
    if referenceResults:
        logOut.line('Accuracy, in reference results:             %7.6f' % refAccuracy)
    logOut.line('Accuracy, in run with NGraph CPU:           %7.6f' % ngAccuracy)
    if referenceResults:
        logOut.line('Acceptable accuracy range (from reference) is: %4.2f%% of %7.6f'
                    % (kAcceptableAccuracyDelta * 100, refAccuracy))
        logOut.line('Acceptable accuracy delta is <= %7.6f'
                % float(acceptableDelta))
        logOut.line('Actual accuracy delta is %7.6f' % deltaAccuracy)
    # Report on times
    logOut.line()
    if referenceResults:
        logOut.line('Reference run took:       %f seconds'
                    % referenceResults['wallclock'])
    logOut.line('Run with NGraph CPU took: %f seconds'
                % ngraphResults['wallclock'])
    if referenceResults:
        logOut.line('NGraph was %f times faster than reference (wall-clock measurement)'
                    % (referenceResults['wallclock'] / ngraphResults['wallclock']))

    # Make sure all output has been flushed before running assertions
    logOut.flush()

    # All assertions are now done at the very end of the run, after all of
    # the summary output has been written.

    if referenceResults:

        assert referenceResults['epochs']     == ngraphResults['epochs']
        assert referenceResults['batch-size'] == ngraphResults['batch-size']

        assert deltaAccuracy <= acceptableDelta  # Assert for out-of-bounds accuracy
        
    # End: if referenceResults

# End: test_resnet20_cifar10_cpu_backend()
