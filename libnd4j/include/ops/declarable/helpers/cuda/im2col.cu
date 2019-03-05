/*******************************************************************************
 * Copyright (c) 2015-2018 Skymind, Inc.
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
// Created by raver119 on 30.11.17.
//

#include <ops/declarable/helpers/im2col.h>

namespace nd4j {
namespace ops {
namespace helpers {


//////////////////////////////////////////////////////////////////////////
// input [bS, iC, iH, iW] is convoluted to output [bS, iC, kH, kW, oH, oW]
template <typename T>
__global__ static void im2colCuda(const void *in, void *out, 
                                  const Nd4jLong *inShapeInfo, const Nd4jLong *outShapeInfo, 
                                  const int kH, const int kW, 
                                  const int sH, const int sW, 
                                  const int pH, const int pW, 
                                  const int dH, const int dW, 
                                  const double zeroPadValD) {
        
    T zeroPadVal = static_cast<T>(zeroPadValD); //Value to use when value is padding. Usually 0 but not always
    const auto im  = reinterpret_cast<const T*>(in);
          auto col = reinterpret_cast<T*>(out);    

    __shared__ Nd4jLong colLen, *colStrides, *imStrides, *colShape;
    __shared__ int iH, iW;
    
    if (threadIdx.x == 0) {
        colLen  = shape::length(outShapeInfo);
        colShape = shape::shapeOf(const_cast<Nd4jLong*>(outShapeInfo));
        colStrides = shape::stride(outShapeInfo);
        imStrides = shape::stride(inShapeInfo);
        iH = inShapeInfo[3];
        iW = inShapeInfo[4];
    }

    __syncthreads();

    const int colRank = 6;
    Nd4jLong colIndices[colRank];   // rank of output
    
    const auto colInd = blockIdx.x * gridDim.x + threadIdx.x;
    
    if(colInd >= colLen) return;

    shape::ind2subC(colRank, colShape, colInd, colLen, colIndices);

    const auto imh = (-pH + colIndices[2] * dH) + colIndices[4]*sH;
    const auto imw = (-pW + colIndices[3] * dW) + colIndices[5]*sW;
                                                                        
    const auto colBuff = col + colIndices[0]*colStrides[0] + colIndices[1]*colStrides[1] + colIndices[2]*colStrides[2] + colIndices[3]*colStrides[3] + colIndices[4]*colStrides[4] + colIndices[5]*colStrides[5];
    const auto imBuff  = im  + colIndices[0]*imStrides[0]  + colIndices[1]*imStrides[1]  + imh*imStrides[2] + imw*imStrides[3]; 
                                                    
    if (static_cast<unsigned>(imh) >= static_cast<unsigned>(iH) || static_cast<unsigned>(imw) >= static_cast<unsigned>(iW))
        *colBuff = zeroPadVal;
    else 
        *colBuff = *imBuff;
}


//////////////////////////////////////////////////////////////////////////
template <typename T>            
static void im2colCudaLauncher(const int blocksPerGrid, const int threadsPerBlock, nd4j::graph::LaunchContext& context, const void *in, void *out, const Nd4jLong *inShapeInfo, const Nd4jLong *outShapeInfo, int kY, int kX, int sH, int sW, int pH, int pW, int dH, int dW, double zeroPadVal) {
       im2colCuda<T><<<blocksPerGrid, threadsPerBlock, 1024, *context.getCudaStream()>>>(in, out, inShapeInfo, outShapeInfo, kY, kX, sH, sW, pH, pW, dH, dW, zeroPadVal);
}

//////////////////////////////////////////////////////////////////////////
void im2col(nd4j::graph::LaunchContext& context, const NDArray& in, NDArray& out, const int kH, const int kW, const int sH, const int sW, const int pH, const int pW, const int dH, const int dW, const NDArray& arrZeroPadVal) {

    if(!in.isActualOnDeviceSide()) in.syncToDevice();

    const int threadsPerBlock = MAX_NUM_THREADS;
    const int blocksPerGrid = (out.lengthOf() + threadsPerBlock - 1) / threadsPerBlock;    // ceil

    BUILD_SINGLE_SELECTOR(out.dataType(), im2colCudaLauncher, (blocksPerGrid, threadsPerBlock, context, in.getSpecialBuffer(), out.getSpecialBuffer(), in.getSpecialShapeInfo(), out.getSpecialShapeInfo(), kH, kW, sH, sW, pH, pW, dH, dW, arrZeroPadVal.e<double>(0)), FLOAT_TYPES);

    in.tickReadDevice();
    out.tickWriteDevice();
}




BUILD_SINGLE_TEMPLATE(template void im2colCudaLauncher, (const int blocksPerGrid, const int threadsPerBlock, nd4j::graph::LaunchContext& context, const void *in, void *out, const Nd4jLong *inShapeInfo, const Nd4jLong *outShapeInfo, const int kY, const int kX, const int sH, const int sW, const int pH, const int pW, const int dH, const int dW, const double zeroPadVal), FLOAT_TYPES);

}
}
}