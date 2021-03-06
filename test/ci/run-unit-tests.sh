#!/usr/bin/env bash
#
# Purpose:
#   Run all unit tests for ngraph-tensorflow integration. This file should be
#   updated whenever a new unit test is updated.
#
# Usage:
#   NGRAPH_VLOG_LEVEL=2 ./run-unit-tests.sh
#
# Todo:
#   - Reduce repeated code once we have more tests
#   - Consider gtest_filter in exclude mode instead of include
#
# The grand goal:
#   Instead of calling individual test files, we should be simply calling
#   ```
#   bazel test //tensorflow/compiler/xla/tests
#   ```
#   to run all XLA_NGRAPH and XLA_CPU tests, once we support all tests.


# Environment setup
set -u

# Print ngraph vlog level
if [ -z ${NGRAPH_VLOG_LEVEL+x} ]
then
    echo "NGRAPH_VLOG_LEVEL is not set, default to 0"
    NGRAPH_VLOG_LEVEL=0
else
    echo NGRAPH_VLOG_LEVEL=${NGRAPH_VLOG_LEVEL}
fi

# The directory of this script
declare THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

TF_DIR="${THIS_SCRIPT_DIR}"

# If the location of the plugin DSO is not specified, then use the one in 
# the installed location i.e., Python site-packages/tensorflow/plugins
if [ -z ${USER_PLUGIN_PATH+x} ]
then
    PY_SITE_PKG_DIR=`python -c 'from distutils.sysconfig import get_python_lib; print(get_python_lib())'`
    export USER_PLUGIN_PATH=$PY_SITE_PKG_DIR"/tensorflow/plugins/libngraph_plugin.so"
fi

# Check to make sure that the plugin DSO exists
if [ ! -e $USER_PLUGIN_PATH ]; then
    echo "Plugin DSO File not found: " $USER_PLUGIN_PATH
    exit 1
fi
echo "Using plugin from this directory: " $USER_PLUGIN_PATH


# Concatenate array as a str
function get_gtest_filter_str {
    # prefix
    echo -n "*"
    # body
    local d=":*.";
    echo -n "$1";
    shift;
    printf "%s" "${@/#/$d}";
    # postfix
    echo -n ""
}

declare -i NUM_FAILED=0
declare -i NUM_PASSED=0

# Fetch all the dependencies using this command
#  bazel fetch //tensorflow/compiler/xla/tests:all

# Build and run test
function build_and_run_tests {
    # parse
    local target=$1
    local name_target="${target##*:}"
    local bin_target="${target/:/\/}"
    local enabled_test_names=("${@:2}")
    echo "Test target:" ${target}
    echo "Test name:" ${name_target}
    echo "Test bin target:" ${bin_target}

    # run - using bazel test
    # Commented out for now as there are some issues ...
    # GTEST_FILTER=$(get_gtest_filter_str ${enabled_test_names[@]})
    # NGRAPH_VLOG_LEVEL=${NGRAPH_VLOG_LEVEL} \
    #     bazel test \
    #         //$target --action_env=USER_PLUGIN_PATH=$USER_PLUGIN_PATH \
    #         --test_arg=--gtest_output="xml:${TF_DIR}/unit_test_results_${name_target}.xml" \
    #         --test_arg=--gtest_filter=""${GTEST_FILTER}""

    bazel build //${target} 

    UNIT_TEST_PROG="${TF_DIR}/bazel-bin/${bin_target}"
    NGRAPH_VLOG_LEVEL=${NGRAPH_VLOG_LEVEL} \
        "${UNIT_TEST_PROG}" \
            --gtest_output="xml:${TF_DIR}/unit_test_results_${name_target}.xml" \
            --gtest_filter=$(get_gtest_filter_str ${enabled_test_names[@]})
    #store the resulting exit code
    local TEST_EXIT_CODE=${?}

    if (( TEST_EXIT_CODE == 0 )); then
        ((NUM_PASSED += 1))
    else
        ((NUM_FAILED += 1))
    fi
}

# xla/tests:pad_test_dynamic_plugin
test_target="tensorflow/compiler/xla/tests:pad_test_dynamic_plugin"
declare -a enabled_tests=(
  "Pad1DS0ToS0Array"
  "Pad1DS0ToS5Array"
  "Pad1DS3Array"
  "Pad4D_2x0x3x2_FloatArray"
  "Pad4DFloat_1x1x3x2_Array"
  "Pad4DFloatArrayWithInteriorPadding"
  "Pad4DFloatArrayMinorFirstSmall"
  "Pad4DFloatArrayMinorFirstNonTrivialMinorDimensions"
  # "Pad4DU8Array"                                       # expect fail for now: U8 not implemented by bridge
  "Pad4DPredArray"
  "Large2DPad"
  "AllTypes2DPad"
  "High2DPad"
  "NegativePadding2D"
  "NegativeAndInteriorPadding2D"
  "ReducePad"
)
build_and_run_tests ${test_target} ${enabled_tests[@]}

# xla/tests:convolution_dimension_numbers_test_dynamic_plugin
test_target="tensorflow/compiler/xla/tests:convolution_dimension_numbers_test_dynamic_plugin"
declare -a enabled_tests=(
  "InvalidInputDimensionNumbers"
  "InvalidWeightDimensionNumbers"
  "InvalidOutputDimensionNumbers"
  "TwoConvsWithDifferentDimensionNumbers"
)
build_and_run_tests ${test_target} ${enabled_tests[@]}

# xla/tests:convolution_test_dynamic_plugin
test_target="tensorflow/compiler/xla/tests:convolution_test_dynamic_plugin"
declare -a enabled_tests=(
  "ForwardPassConvolution_3x3x256_256_OutputZ_Iota"
  "Convolve_1x1x1x2_1x1x1x2_Valid"
  "Convolve_1x1x4x4_1x1x2x2_Valid"
  "Convolve_1x1x4x4_1x1x2x2_Same"
  "Convolve_1x1x4x4_1x1x3x3_Same"
  "Convolve1D_1x2x5_1x2x2_Valid"
  "Convolve3D_1x4x2x3x3_2x2x2x3x3_Valid"
)
build_and_run_tests ${test_target} ${enabled_tests[@]}

# xla/tests:convolution_variants_test_dynamic_plugin
test_target="tensorflow/compiler/xla/tests:convolution_variants_test_dynamic_plugin"
declare -a enabled_tests=(
  "Minimal"
  "MinimalWithBatch"
  "Flat1x1"
  "Deep1x1"
  "Filter1x2in1x2"
  "Filter1x2in1x3"
  "Filter1x2in2x2"
  "Filter2x1in2x2"
  "Filter2x2in2x2"
  "Filter1x2in2x3WithDepthAndBatch"
  "Filter1x1stride1x2in1x4"
  "Filter1x1stride1x2in1x5"
  "Filter1x3stride1x2in1x4"
  "Filter1x3stride1x2in1x5"
  "Filter1x1stride2x2in3x3"
  "Filter3x1in1x1Padded"
  "Filter5x1in3x1Padded"
  "Filter3x3in2x2Padded"
  "Filter1x1in2x1WithPaddingAndDepth"
  "Filter2x2Stride1x1Input3x3"
  "Filter1x2Stride1x1Input1x3"
  "Filter2x1x8x8Input1x1x8x8"
  "Filter1x1x1x1Input16x1x1x1"
  "Filter1x1x2x2Input16x1x2x2"
  "Filter1x1x2x2Input3x1x2x2"
  "Filter1x1x8x8Input16x1x8x8"
  "Filter2x2x8x8Input1x2x8x8"
  "Filter2x2x8x8Input2x2x8x8"
  "Filter2x2x8x8Input32x2x8x8"
  "Filter16x16x1x1Input16x16x1x1"
  "FlatRhsDilation"
  "FlatLhsDilation1D"
  "FlatLhsDilation"
  "NegativePaddingOnBothEnds"
  "NegativePaddingLowAndPositivePaddingHigh"
  "PositivePaddingLowAndNegativePaddingHigh"
  "PositivePaddingAndDilation"
  "NegativePaddingAndDilation"
  "RandomData_Input1x1x2x3_Filter2x1x1x2"
  "RandomData_Input1x16x1x1_Filter1x16x1x1"
  "RandomData_Input16x16x1x1_Filter1x16x1x1"
  "RandomData_Input16x16x1x1_Filter16x16x1x1"
  "RandomData_Input16x16x16x16_Filter16x16x16x16"
  "Filter1x2x1x1Input1x2x3x1GeneralPadding"
  "Filter1x1x1x1Input1x2x3x1GeneralPadding"
  "Filter1x1x1x1Input1x2x3x1NoPadding"
  "Filter1x1x2x3Input1x2x3x2NoPadding"
  "BackwardInputLowPaddingLessThanHighPadding"
  "BackwardInputLowPaddingGreaterThanHighPadding"
  "BackwardInputEvenPadding"
  "BackwardInputWithNegativePaddingHigh"
  "BackwardFilterLowPaddingLessThanHighPadding"
  "BackwardFilterLowPaddingGreaterThanHighPadding"
  "BackwardFilterEvenPadding"
  "BackwardInputEvenPadding1D"
  "BackwardFilterEvenPadding1D"
  "BackwardInputEvenPadding3D"
  "BackwardFilterEvenPadding3D"
)
build_and_run_tests ${test_target} ${enabled_tests[@]}

# xla/tests:array_elementwise_ops_test_dynamic_plugin
test_target="tensorflow/compiler/xla/tests:array_elementwise_ops_test_dynamic_plugin"
declare -a enabled_tests=(
  "NegConstantZeroElementF32"
  "NegConstantF32"
  "NegConstantS32"
  #"NegConstantZeroElementC64"                #complex type unimplemented
  #"NegConstantC64"                           #complex type unimplemented
  "NegConstantS64"
  #"IsFiniteZeroElementF32s"                  #IsFinite op unimplemented
  #"IsFiniteScalarF32"                        #IsFinite op unimplemented
  #"IsFiniteR1F32s"                           #IsFinite op unimplemented
  "AddTwoConstantF32s"
  "AddTwoConstantZeroElementF32s"
  #"AddTwoConstantC64s"                       #complex type unimplemented
  #"AddTwoConstantZeroElementC64s"            #complex type unimplemented
  #"AddTwoConstantU64s"                       #unsigned type not bridged
  "SubTwoConstantS64s"
  "SubTwoConstantF32s"
  "SubTwoConstantZeroElementF32s"
  "SubTwoConstantS32s"
  #SubTwoConstantC64s                         #complex type unimplemented
  #SubTwoConstantZeroElementC64s              #complex type unimplemented
  "SubTwoConstantZeroElementS32s"
  "DivTwoConstantF32s"
  "DivTwoConstantZeroElementF32s"
  #"DivS32s"                                  #remainder op unimplemented
  #DivU32s                                    #unsigned type not bridged
  #DivTwoConstantC64s                         #complex type unimplemented
  #DivTwoConstantZeroElementC64s              #complex type unimplemented
  #"RemF32s"                                  #remainder op unimplemented
  #"RemZeroElementF32s"                       #remainder op unimplemented
  #RemF64s                                    #remainder op unimplemented
  "MulTwoConstantF32s"
  "MulTwoConstantZeroElementF32s"
  "MulTwoConstantS32s"
  "MulTwoConstantZeroElementS32s"
  #MulTwoConstantU32s                         #unsigned type not bridged
  #MulTwoConstantC64s                         #complex type unimplemented
  #MulTwoConstantZeroElementC64s              #complex type unimplemented
  #AndPredR1                                  #BoolOps unimplemented
  #AndPredR2
  #AndZeroElementPredR1
  #AndS32R1
  #AndS32R2
  #AndZeroElementS32R1
  #AndU32R1
  #AndU32R2
  #AndZeroElementU32R1
  #OrPredR1
  #OrPredR2
  #OrZeroElementPredR1
  #OrS32R1
  #OrS32R2
  #OrZeroElementS32R1
  #OrU32R1
  #OrU32R2
  #OrZeroElementU32R1 
  #NotPredR1 
  #NotPredR2 
  #NotZeroElementPredR1 
  #NotS32R1 
  #NotS32R2 
  #NotZeroElementS32R1
  #NotU32R1 
  #NotU32R2 
  #NotZeroElementU32R1
  #ShiftLeftS32                               #Shift ops unimplemented
  #ShiftRightArithmeticS32                    #Shift ops unimplemented
  #ShiftRightLogicalS32                       #Shift ops unimplemented
  #ShiftLeftU32                               #Shift ops unimplemented
  #ShiftRightArithmeticU32                    #Shift ops unimplemented
  #ShiftRightLogicalU32                       #Shift ops unimplemented
  "CompareEqF32s"
  "CompareEqZeroElementF32s"
  "CompareGeF32s"
  "CompareGtF32s"
  "CompareLeF32s"
  "CompareLtF32s"
  "CompareEqS32s"
  "CompareEqZeroElementS32s"
  #CompareEqC64s                              #complex type unimplemented
  #CompareEqZeroElementC64s                   #complex type unimplemented
  #CompareNeC64s                              #complex type unimplemented
  "CompareNeF32s"
  "CompareNeS32s"
  "CompareGeS32s"
  "CompareGtS32s"
  "CompareLeS32s"
  "CompareLtS32s"
  #CompareEqU32s                              #unsigned type not bridged
  #CompareNeU32s                              #unsigned type not bridged
  #CompareGeU32s                              #unsigned type not bridged
  #CompareGtU32s                              #unsigned type not bridged
  #CompareLeU32s                              #unsigned type not bridged
  #CompareLtU32s                              #unsigned type not bridged
  "PowF32s"
  "PowNonIntegerF32s"
  "PowZeroElementF32s"
  "PowSpecialF32"
  "PowOfExpF32"
  "LogOfPowerF32"
  "MulOfExpF32"
  "DivOfExpF32"
  "Div3_lhs_F32"
  "Div3_rhs_F32"
  "DivOfPowerF32"
  "Div4F32"
  "SquareIn4D"
  "SquareIn4DZeroElements"
  #"MinF32s"                                  #Unknown nGraph bug
  #MinF64s                                    #F64 type not bridged
  "MinZeroElementF32s"
  #"MaxF32s"                                  #Unknown nGraph bug
  "MaxZeroElementF32s"
  #MaxF64s                                    #F64 type not bridged
  "MaxS32s"
  "MinS32s"
  #MaxU32s                                    #unsigned type not bridged
  #MinU32s                                    #unsigned type not bridged
  "MaxTenF32s"
  "MaxR1S1AndR1S0F32s"
  #"MaxR1S0AndR2S0x2F32s"                     #Unknown nGraph bug
  "Max1DAnd2DF32s"
  #"Max1DAnd2DZeroElementF32s"                #Unknown nGraph bug
  "Max3DAndScalarS32s"
  "Max3DAndScalarZeroElementS32s"
  "Min2DTo1DF32s"
  "Min2DTo1DZeroElementF32s"
  "Min2DTo4DF32s"
  "Min2DTo4DZeroElementF32s"
  "MinTenS32s"
  "MaxTenS32s"
  #"RemTwoConstantS32s"                       #remainder op unimplemented
  "NonNanClampF32"
  "ClampF32Scalar"
  "ClampF32ScalarVector"
  "ClampS32Vector"
  "ClampS32ScalarVector"
  #ClampU32Vector                             #data type U32 unimplemented
  #ClampU32ScalarVector                       #data type U32 unimplemented
  "AddTwoParametersF32s"
  "AddTwoParametersZeroElementF32s"
  "AddParameterToConstantF32s"
  "CosF32s"
  "SinF32s"
  #Atan2F32s                                  #atan2 op unimplemented
  "TanhF32s"
  "TanhF32sVector"
  "ExpF32sVector"
  "LogF32sVector"
  "AddChainFoldLeft"
  "AddChainFoldRight"
  "AddWithNeg"
  "AddChainTwoSide"
  "2DBinaryOpF32s"
  "ScalarPlus2DF32"
  "2DPlusScalarF32"
  "Add1DTo2DF32"
  "Compare1DTo2DS32Eq"
  "Compare1DTo2DS32Ne"
  "Compare1DTo2DS32Ge"
  "Compare1DTo2DS32Gt"
  "Compare1DTo2DS32Le"
  "Compare1DTo2DS32Lt"
  "Mul2Dby1DF32"
  "Add2DTo2DWithDegenerateDim1"
  "Add2DTo2DWithDegenerateDim0"
  "Add2DsWithDegenerateDimsOuterProduct"
  "Add1DTo2DF32TwoWaysOver1"
  "Add1DTo2DF32TwoWaysOver0"
  "3DBinaryOpF32s"
  "Add1DTo3DTwoWaysOver2"
  "Add1DTo3DTwoWaysOver0"
  "Add2DTo3D"
  "CompareGtR3F32sWithDegenerateDim2"
  "4DBinaryOpF32s"
  "R4PlusR1InDim1"
  "R4_16x16x2x2_Plus_R1_16"
  "CannotAddOpaques"
  "IdentityBroadcastOfSameRankIsAllowed"
  "NonIdentityBroadcastOfSameRankIsDisallowed"
  "ImplictBroadcastInFusedExpressions"
)
build_and_run_tests ${test_target} ${enabled_tests[@]}

# xla/tests:broadcast_simple_test
test_target="tensorflow/compiler/xla/tests:broadcast_simple_test_dynamic_plugin"
declare -a enabled_tests=(
    "ScalarNoOpBroadcast"
    "ScalarTo2D_2x3"
    "ScalarParamTo2D_2x3"
    "ScalarTo2D_2x0"
    "ScalarTo2D_0x2"
    "1DTo2D"
    "LogicalAnd2DTo3D_Pred"
    "ZeroElement_1DTo2D"
    "1DToZeroElement2D"
    "InDimensionAndDegenerateBroadcasting"
    "Add3DTo3DDegenerate_1_2"
    "Add3DTo3DDegenerate_0_1"
    "Add3DTo3DDegenerate_0_2"
    "Add3DTo3DDegenerate_0"
    "Add3DTo3DDegenerate_1"
    "Add3DTo3DDegenerate_2"
    "Add3DTo3DDegenerate_0_1_2"
    "Add2DTo2DDegenerate_0"
    "Add2DTo2DDegenerate_1"
    "Add1DTo3DInDim0"
    "Add1DTo3DInDim1"
    "Add1DTo3DInDim2"
    "Add1DTo3DInDimAll"
    "Add1DTo3DInDimAllWithScalarBroadcast"
    "InvalidBinaryAndDegenerateBroadcasting"
    "InvalidInDimensionBroadcasting"
    "InvalidDegenerateBroadcasting"
)
build_and_run_tests ${test_target} ${enabled_tests[@]}

# xla/tests:dot_operation_test
test_target="tensorflow/compiler/xla/tests:dot_operation_test_dynamic_plugin"
declare -a enabled_tests=(
    "ZeroElementVectorDotF32"
    "TrivialMatrixVectorDotF32"
    "OneElementVectorDotF32"
    # "OneElementVectorDotF64"
    "VectorDotF32"
    # "VectorDotF64"
    "Dot_0x2_2x0"  # 0d dot bug
    "Dot_0x2_2x3"  # 0d dot bug
    "Dot_3x2_2x0"  # 0d dot bug
    "Dot_2x0_0x2"  # 0d dot bug
    # "MatrixDotF32_12_117_7_MinorToMajorTF"
    # "MatrixDotF32_12_117_7_MinorToMajorFT"
    "MatrixDotF32_12_117_7_MinorToMajorTT"
    # "MatrixDotF32_12_117_7_MinorToMajorFF"
    "MatrixDotF32_270_270_520_MinorToMajorTT"
    # "MatrixDotF32_270_270_520_MinorToMajorTF"
    # "MatrixDotF32_270_270_520_MinorToMajorFT"
    # "MatrixDotF32_270_270_520_MinorToMajorFF"
    "MatrixDotF32_260_3_520_MinorToMajorTT"
    # "MatrixDotF32_260_3_520_MinorToMajorTF"
    # "MatrixDotF32_260_3_520_MinorToMajorFT"
    # "MatrixDotF32_260_3_520_MinorToMajorFF"
    # "SquareMatrixDotF32MinorToMajorFF"
    # "SquareMatrixDotF32MinorToMajorFT"
    # "SquareMatrixDotF32MinorToMajorTF"
    "SquareMatrixDotF32MinorToMajorTT"
    # "SquareMatrixDotF64"
    # "NonsquareMatrixDotF32MajorToMinorFF"
    # "NonsquareMatrixDotF32MajorToMinorFT"
    # "NonsquareMatrixDotF32MajorToMinorTF"
    "NonsquareMatrixDotF32MajorToMinorTT"
    # "NonsquareMatrixDotF64"
    # "ConcurrentMatMul"
    # "BatchMatMul"
    # "TransposeFolding"
)
# DISABLED 
# This is a templatized test in which they are using F16 as the
# data type. However, since this is invoked by the dynamic plugin, we 
# have to come up with a way to properly disable the tests. 
# TODO
#build_and_run_tests ${test_target} ${enabled_tests[@]}

# xla/tests:log_test
test_target="tensorflow/compiler/xla/tests:log_test_dynamic_plugin"
declare -a enabled_tests=(
    "LogZeroValues"
    "LogTenValues"
)
build_and_run_tests ${test_target} ${enabled_tests[@]}

# xla/tests:tuple_test
test_target="tensorflow/compiler/xla/tests:tuple_test_dynamic_plugin"
declare -a enabled_tests=(
    "TupleConstant"
    "TupleCreate"
    "TupleCreateWithZeroElementEntry"
    "EmptyTupleCreate"
    "GetTupleElement"
    "GetTupleElementWithZeroElements"
    "AddTupleElements"
    "TupleGTEToTuple"
    # "SelectBetweenPredTuples"
    "TupleGTEToTupleToGTEAdd"
    # "SelectBetweenTuplesOnFalse"
    # "TuplesInAMap"
    # "SelectBetweenTuplesOnTrue"
    # "SelectBetweenTuplesElementResult"
    # "SelectBetweenTuplesCascaded"
    # "SelectBetweenTuplesReuseConstants"
    # "NestedTuples"
    # "GetTupleElementOfNestedTuple"
)
# DISABLED
# TODO: Figure out why it's failing
#build_and_run_tests ${test_target} ${enabled_tests[@]}

# xla/tests:vector_ops_simple_test_dynamic_plugin
test_target="tensorflow/compiler/xla/tests:vector_ops_simple_test_dynamic_plugin"
declare -a enabled_tests=(
  "ExpTenValues"
  "ExpManyValues"
  "ExpIn4D"
  "NegateTenFloatValues"
  "NegateTenInt32Values"
  # "NegateUint32Values" #Unsigned unimplemented
  "SquareTenValues"
  "ReciprocalTenValues"
  "SqrtZeroes"
  "SqrtSixValues"
  "InvSqrtSevenValues"
  # "AddTenValuesViaMap"
  "MaxTenValues"
  "MaxTenValuesFromParams"
  "Max15000ValuesFromParams"
  "MaxTenValuesWithScalar"
  "MinTenValues"
  "MinMaxTenValues"
  # "ClampTenValuesConstant"
  # "ClampTwoValuesConstant"
  # "ClampTenValuesConstantNonzeroLower"
  # "MapTenValues"
  # "RemainderTenValuesS32"
  "VectorPredicateEqual"
  "VectorPredicateNotEqual"
)
build_and_run_tests ${test_target} ${enabled_tests[@]}

# xla/tests:reduce_test_dynamic_plugin
test_target="tensorflow/compiler/xla/tests:reduce_test_dynamic_plugin"
declare -a enabled_tests=(
  "ReduceR1_0_F32_To_R0"
  "ReduceR1_1_F32_To_R0"
  "ReduceR1_2_F32_To_R0"
  "ReduceR1_16_F32_To_R0"
  "ReduceR1_128_F32_To_R0"
  "ReduceR1_129_F32_To_R0"
  "ReduceR1_240_F32_To_R0"
  "ReduceR1_256_F32_To_R0"
  "ReduceR1_1024_F32_To_R0"
  "ReduceR1_2048_F32_To_R0"
  "ReduceR1_16K_F32_To_R0"
  "ReduceR1_16KP1_F32_To_R0"
  "ReduceR1_64K_F32_To_R0"
  "ReduceR1_1M_F32_To_R0"
  "ReduceR1_16M_F32_To_R0"
  "ReduceR2_0x0_To_R0"
  "ReduceR2_0x2_To_R0"
  "ReduceR2_1x1_To_R0"
  "ReduceR2_2x0_To_R0"
  "ReduceR2_2x2_To_R0"
  "ReduceR2_8x8_To_R0"
  "ReduceR2_9x9_To_R0"
  "ReduceR2_50x111_To_R0"
  "ReduceR2_111x50_To_R0"
  "ReduceR2_111x50_01_To_R0"
  "ReduceR2_1024x1024_To_R0"
  "ReduceR2_1000x1500_To_R0"
  "ReduceR2_0x2_To_R1"
  "ReduceR2_1x1_To_R1"
  "ReduceR2_2x2_To_R1"
  "ReduceR2_8x8_To_R1"
  "ReduceR2_9x9_To_R1"
  "ReduceR2_50x111_To_R1"
  "ReduceR2_111x50_To_R1"
  #"ReduceR2_111x50_01_To_R1"
  "ReduceR2_1024x1024_To_R1"
  "ReduceR2_1000x1500_To_R1"
  #"AndReduceAllOnesR1_10_Pred" #BoolOps unimplemented
  #"AndReduceOnesAndZerosR1_10_Pred" #BoolOps unimplemented
  #"OrReduceAllOnesR1_10_Pred" #BoolOps unimplemented
  #"OrReduceOnesAndZerosR1_10_Pred" #BoolOps unimplemented
  "ReduceElementwiseR2_111x50_To_R1"
  "TransposeAndReduceElementwiseR2_111x50_To_R1"
  "TransposeAndReduceR3_12x111x50_To_R2"
  #"Reshape_111x2x25Reduce_111x50_To_R1"
  "AddReduce2DScalarToR0"
  "MaxReduce2DScalarToR0"
  "MaxReduce2DToR0"
  "MinReduce2DToR0"
  #"UnsignedInt_MinReduce" #Unsigned unimplemented
  #"UnsignedInt_MaxReduce" #Unsigned unimplemented
  "Reduce2DAmong1"
  "Reduce2DAmong0and1"
  "Reduce2DAmongY"
  "ReduceR3AmongDims_1_2"
  "ReduceR3AmongDims_0_1"
  "ReduceR3ToR0"
  "ReduceR3AmongDim0"
  "ReduceR3AmongDim1"
  "ReduceR3AmongDim2"
  #"VectorizedReduce_Add" #Unsigned unimplemented
  #"VectorizedReduce_Multiply" #Unsigned unimplemented
  #"VectorizedReduce_Max" #Unsigned unimplemented
  #"VectorizedReduce_Min" #Unsigned unimplemented
  #"VectorizedReduce_BooleanAnd" #BoolOps unimplemented
  #"VectorizedReduce_BooleanOr" #BoolOps unimplemented
  "OperationOnConstantAsInitValue"
  #"ReduceAndPredR2_128x64_To_R1" #Unsigned unimplemented
  #"ReduceOrPredR2_64x32_To_R1" #Unsigned unimplemented
)
build_and_run_tests ${test_target} ${enabled_tests[@]}

# xla/tests:transpose_test_dynamic_plugin
test_target="tensorflow/compiler/xla/tests:transpose_test_dynamic_plugin"
declare -a enabled_tests=(
  "Transpose0x0"
  "Transpose0x42"
  "Transpose7x0"
  # "Transpose2x2"
  "Transpose0x2x3_2x3x0"
  # "Transpose1x2x3_2x3x1"
  # "Transpose1x2x3_3x2x1"
  # "Transpose1x2x3_1x2x3"
  # "MultiTranspose3x2"
  "Small_1x1"
  # "Small_2x2"

)
build_and_run_tests ${test_target} ${enabled_tests[@]}

# xla/tests:convert_test_dynamic_plugin
test_target="tensorflow/compiler/xla/tests:convert_test_dynamic_plugin"
declare -a enabled_tests=(
  "ConvertR1S32ToR1S32"
  "ConvertR1F32ToR1F32"
  "ConvertR1S32ToR1F32"
  "ConvertR1PREDToR1S32"
  "ConvertR1PREDToR1F32"
  "ConvertR1S0S32ToR1S0F32"
  "ConvertR1F32ToR1S32"
  "ConvertR1S64ToR1F32"
  #"ConvertR1U32ToR1F32"
  #"ConvertR1F32ToR1U32"
  #"ConvertR1U32ToR1S64"
  "ConvertR1S32ToR1S64"
  #"ConvertR1U8ToR1F32"
  #"ConvertR1U8ToR1S32"
  #"ConvertR1U8ToR1U32"
  #"ConvertR1F32ToR1F64"
  #"ConvertR1F64ToR1F32"
  "ConvertS32Extremes"
  #"ConvertMapToS32"
  #"ConvertMapToF32"
  "ConvertReshape"
  #"ConvertR1F16ToR1F32"
  #"ConvertR1F32ToR1F16"
)
build_and_run_tests ${test_target} ${enabled_tests[@]}

# xla/tests:select_test_dynamic_plugin
test_target="tensorflow/compiler/xla/tests:select_test_dynamic_plugin"
declare -a enabled_tests=(
  "SelectScalarF32True"
  "SelectScalarS32True"
  "SelectScalarF32False"
  "SelectR1S0F32WithConstantR1S0PRED"
  "SelectR1F32WithConstantR1PRED"
  "SelectR1S0F32WithCmpR1S0S32s"
  "SelectR1F32WithCmpR1S32s"
  "SelectR1F32WithCmpR1F32s"
  "SelectR1F32WithCmpR1F32sFromParamsSmall"
  "SelectR1F32WithCmpR1F32sFromParamsLarge"
  "SelectR1F32WithCmpR1S32ToScalar"
  "SelectR1F32WithCmpR1F32ToScalar"
  "SelectR1S0F32WithScalarPredicate"
  "SelectR1F32WithScalarPredicateTrue"
  "SelectR1F32WithScalarPredicateFalse"
)
build_and_run_tests ${test_target} ${enabled_tests[@]}

# xla/tests:reverse_test_dynamic_plugin
test_target="tensorflow/compiler/xla/tests:reverse_test_dynamic_plugin"
declare -a enabled_tests=(
    "ReverseScalar"
    "Reverse0x0FloatArray"
    "Reverse0x1FloatArray"
    "Reverse1x0FloatArray"
    "Reverse1x1FloatArray"
    "Reverse2x0x4x3FloatArrayDim02"
    "Reverse2x0x4x3FloatArrayDim13"
    # "Reverse4DU8ArrayOnDim23"
    "Reverse4DFloatArrayOnDim01"
)
build_and_run_tests ${test_target} ${enabled_tests[@]}

# xla/tests:select_and_scatter_test_dynamic_plugin
test_target="tensorflow/compiler/xla/tests:select_and_scatter_test_dynamic_plugin"
declare -a enabled_tests=(
  # "R1S0F32" # nGraph zero-size tensor bug
  "R1F32"
  "R1S32"
  "R1S32OverlappingWindow"
  "R2S32"
  #"R2F32Tie" # same padding unimplemented
  "ReshapeR2S32"
  "R2S32OverlappingWindow"
  # "R2S32SamePadding" # same padding padding
  # "R2S32SamePaddingOverlappingWindow" # same padding padding
  "R2F32OverlappingR2Source"
  "R4F32Valid"
  "R4F32Overlap"
  "R4F32OverlapSmall"
  "R4F32RefValidFixedSmall"
  "R1F32OverlappingWindowMaxScatter"
  "R1F32OverlappingWindowMinScatter"
)
build_and_run_tests ${test_target} ${enabled_tests[@]}

echo "TensorFlow Unit test results: PASSED: " ${NUM_PASSED}
echo "TensorFlow Unit test results: FAILED: " ${NUM_FAILED}
if [[ -z ${XLA_NGRAPH_BACKEND+x} ]]
then
    echo "nGraph Backend: Default"
else
    echo "nGraph Backend: ${XLA_NGRAPH_BACKEND}"
fi

if (( NUM_FAILED == 0 )); then
    exit 0
else
    exit 1
fi
