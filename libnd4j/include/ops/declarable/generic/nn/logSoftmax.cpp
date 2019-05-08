/*******************************************************************************
 * Copyright (c) 2015-2019 Skymind, Inc.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Apache License, Version 2.0 which is available at
 * https://www.apache.org/licenses/LICENSE-2.0.
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 ******************************************************************************/

//
// @author Yurii Shyrma (iuriish@yahoo.com), created on 01.02.2018
//

#include <op_boilerplate.h>
#if NOT_EXCLUDED(OP_log_softmax)

#include <ops/declarable/CustomOperations.h>
#include <ops/declarable/helpers/activations.h>

namespace nd4j {
namespace ops {


    DECLARE_TYPES(log_softmax) {
        getOpDescriptor()
                ->setAllowedInputTypes({ALL_FLOATS})
                ->setSameMode(true);
    }

CONFIGURABLE_OP_IMPL(log_softmax, 1, 1, true, 0, 0) {
    auto input  = INPUT_VARIABLE(0);
    auto output = OUTPUT_VARIABLE(0);
    
    const int rank = input->rankOf();
    const int dim  = block.getIArguments()->size() > 0 ? INT_ARG(0) : rank - 1;

    REQUIRE_TRUE(dim < rank, 0, "LOG_SOFTMAX OP: the value of input integer parameter (dimension) must be less than input array rank %i, but got dimension = %i instead !", rank, dim);

    if(input->isVector()) {
        
        if(rank == 1 || input->sizeAt(dim) != 1)
            helpers::logSoftMaxForVector(*input, *output);
        else
            *output = 0.;
    }
    else {
        auto exponents = input->transform(transform::Exp);
        auto sumAlongDim = exponents.reduceAlongDims(reduce::Sum, {dim}, true);
        output->assign( *input - sumAlongDim.transform(transform::Log) );
    }
    
    return Status::OK();
}

    DECLARE_TYPES(log_softmax_bp) {
        getOpDescriptor()
                ->setAllowedInputTypes(0, DataType::ANY)
                ->setAllowedInputTypes(1, {ALL_FLOATS})
                ->setAllowedOutputTypes({ALL_FLOATS});
    }


CONFIGURABLE_OP_IMPL(log_softmax_bp, 2, 1, true, 0, 0) {
    auto input = INPUT_VARIABLE(0);
    auto gradO = INPUT_VARIABLE(1);
    auto gradI = OUTPUT_VARIABLE(0);

    const int rank = input->rankOf();
    const int dim  = block.getIArguments()->size() > 0 ? INT_ARG(0) : rank - 1;

    REQUIRE_TRUE(dim < rank, 0, "LOG_SOFTMAX_BP OP: the value of input integer parameter (dimension) must be less than input array rank %i, but got dimension = %i instead !", rank, dim);

    helpers::softmax(*input, *gradI, dim);
        
    gradI->assign( *gradO - (*gradI * *gradO).reduceAlongDims(reduce::Sum, {dim}, true) );

    return Status::OK();
}



}
}

#endif
