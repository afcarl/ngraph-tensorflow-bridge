/*******************************************************************************
 * Copyright 2017-2018 Intel Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *******************************************************************************/

#ifndef NGRAPH_AUTOBROADCAST_H_
#define NGRAPH_AUTOBROADCAST_H_

#include "ngraph/ngraph.hpp"

using NgraphNodePtr = std::shared_ptr<ngraph::Node>;

namespace xla {
namespace ngraph_plugin {

// broadcasts input ngraph nodes per numpy rules
class AutoBroadcast {
 private:
  struct Node {
    // pointer to an ngraph node
    // initialized by the constructor
    // conditionally replaced by ReshapeAndBroadcast
    NgraphNodePtr ptr;
    // initial shape of node
    const ngraph::Shape shape;
    // shape of node after ngraph::op::Reshape
    ngraph::Shape reshape;
    // axes (0-based) to broadcast by ngraph::op::Broadcast
    ngraph::AxisSet axes;
  } lhs_, rhs_;

  // shape of both nodes after ngraph::op::Broadcast
  ngraph::Shape broadcastshape_;

  // set reshape and axes (per node) and broadcast shape
  void SetShapesAndAxes();

  // conditionally replace node with...
  //   ngraph::op::Reshape (if node shape != node reshape) and/or
  //   ngraph::op::Broadcast (if node reshape != broadcast shape)
  //
  // NOTE: Reshape is needed to remove singular dimensions
  //       e.g. when adding (2,3) tensor A to (2,1) tensor B
  //            first Reshape tensor B to (2)
  //            then Broadcast tensor B to (2,3)
  void ReshapeAndBroadcast(Node& node);

 public:
  AutoBroadcast(NgraphNodePtr lhsNode, const ngraph::Shape& lhsShape,
                NgraphNodePtr rhsNode, const ngraph::Shape& rhsShape);
  NgraphNodePtr lhs() const { return lhs_.ptr; }
  NgraphNodePtr rhs() const { return rhs_.ptr; }
};

}  // namespace ngraph_plugin
}  // namespace xla

#endif
