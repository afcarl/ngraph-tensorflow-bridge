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

#include <dlfcn.h>
#include <iostream>

#include "ngraph/ngraph.hpp"
#include "tensorflow/compiler/xla/status_macros.h"
#include "tensorflow/compiler/xla/xla_plugin.h"

#include "ngraph_compiler.h"
#include "transfer_manager.h"

//-----------------------------------------------------------------------------
//  Misc. function declarations
//-----------------------------------------------------------------------------

static xla::plugin::DeviceInfo s_DeviceInfo = {"nGraphDevice", "NGRAPH",
                                               "NGRAPH_JIT", 1, 20};

extern "C" xla::plugin::Info GetPluginData();

//-----------------------------------------------------------------------------
//  We keep a singleton instance of the NGraphCompiler object.
//-----------------------------------------------------------------------------
static xla::ngraph_plugin::NGraphCompiler s_Compiler;

static std::vector<tensorflow::DataType> knGraphPluginSupportedDatatypes = {
    {tensorflow::DT_INT32, tensorflow::DT_FLOAT, tensorflow::DT_BOOL,
     tensorflow::DT_DOUBLE, tensorflow::DT_INT64}};

//-----------------------------------------------------------------------------
//  Plugin Interface Implementation functions
//-----------------------------------------------------------------------------
std::string Version() { return "0.0.0.0"; }

xla::plugin::DeviceInfo DeviceInfo() { return s_DeviceInfo; }

#include "ngraph/util.hpp"

bool Init(perftools::gputools::Platform::Id platform_id) {
  // Determine the full path of this DSO
  Dl_info dlInfo;

  dladdr((const void*)&ngraph::aligned_free, &dlInfo);
  if (dlInfo.dli_sname == NULL || dlInfo.dli_saddr == NULL) {
    std::cerr << "Cannot determine location of the DSO. "
                 "nGraph device won't be available"
              << std::endl;
    return false;
  }

  std::string dso_path(dlInfo.dli_fname);
  size_t loc = dso_path.find_last_of("/\\");
  std::string ngraph_directory = dso_path.substr(0, loc);

  auto handle = dlopen((ngraph_directory + "/libiomp5.so").c_str(),
                       RTLD_NOW | RTLD_GLOBAL);
  if (handle == nullptr) {
    LOG(WARNING) << "Error loading the plugin library. "
                    "nGraph device won't be available";
    return false;
  }

  handle = dlopen((ngraph_directory + "/libngraph.so").c_str(),
                  RTLD_NOW | RTLD_GLOBAL);
  if (handle == nullptr) {
    LOG(WARNING) << "Error loading the plugin library. "
                    "nGraph device won't be available";
    return false;
  }

  return true;
}

xla::TransferManagerInterface* GetTransferManager() {
  static std::unique_ptr<xla::TransferManagerInterface> tx_manager =
      std::unique_ptr<xla::TransferManagerInterface>(new TransferManager());
  return tx_manager.get();
}

// from NGraphCompiler
xla::StatusOr<std::unique_ptr<xla::HloModule>> RunHloPasses(
    std::unique_ptr<xla::HloModule> module,
    perftools::gputools::StreamExecutor* executor,
    xla::DeviceMemoryAllocator* device_allocator) {
  return s_Compiler.RunHloPasses(std::move(module), executor, device_allocator)
      .ValueOrDie();
}

// from NGraphCompiler
std::unique_ptr<xla::Executable> RunBackend(
    std::unique_ptr<xla::HloModule> hlo_module,
    ::perftools::gputools::StreamExecutor* stream_exec) {
  return s_Compiler
      .RunBackend(std::move(hlo_module), stream_exec,
                  /*device_allocator=*/nullptr)
      .ValueOrDie();
}

std::vector<tensorflow::DataType> SupportedDataTypes() {
  return knGraphPluginSupportedDatatypes;
}
//-----------------------------------------------------------------------------
// Utility functions
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
//  Global data for this Plugin
//-----------------------------------------------------------------------------

static xla::plugin::Info s_PluginInfo = {
    Version,    DeviceInfo,        Init, GetTransferManager, RunHloPasses,
    RunBackend, SupportedDataTypes};

//-----------------------------------------------------------------------------
// DSO Entry point
//-----------------------------------------------------------------------------
xla::plugin::Info GetPluginData() { return s_PluginInfo; }
