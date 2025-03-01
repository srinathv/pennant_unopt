cmake_minimum_required(VERSION 3.10)

project(pennant LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# The following three lines are not necessary on some systems, while
# leaving them out causes issues with finding HIP and rocBLAS on other
# systems. Beats me.
set(ROCM_PATH /opt/rocm CACHE STRING "Path to ROCm install")
list(APPEND CMAKE_MODULE_PATH ${ROCM_PATH}/hip/cmake)
list(APPEND CMAKE_PREFIX_PATH ${ROCM_PATH}/hip ${ROCM_PATH})

# Preferred way of working: don't change options in this file. Instead, call cmake with
# e.g. "-DPENNANT_MPI=OFF" if you want to change that setting
option(PENNANT_USE_MPI "Build with MPI support" ON)
option(PENNANT_USE_OPENMP "Build with OPENMP support" ON)
option(PENNANT_USE_GPU_AWARE_MPI "Build with GPU-aware MPI. Requires supporting MPI stack" OFF)
option(PENNANT_USE_XPMEM "XPMEM vs. CMA for all to all communication in MPI" OFF)
option(PENNANT_TIMERS "Put timers around important code sections and print stats" OFF)
option(PENNANT_ROCTX "Put important code sections in roctx ranges" OFF)
option(PENNANT_FAST_MATH "Use math optimizations that may not be IEEE 764 compliant" OFF)
option(PENNANT_UNSAFE_MATH_OPT "Use UNSAFE math optimizations that may not be IEEE 764 compliant" OFF)
option(PENNANT_MEM_ALIGN "Use memory alignment flags for some 64 units" OFF)
option(PENNANT_ARCH_GFX900 "Build with support for gfx900 (vega10)" OFF)
option(PENNANT_ARCH_GFX906 "Build with support for gfx906 (vega20, MI50/60)" OFF)
option(PENNANT_ARCH_GFX908 "Build with support for gfx908 (vega7nm, MI100)" OFF)
option(PENNANT_ARCH_GFX90A "Build with support for gfx90a (MI200)" OFF)
option(PENNANT_ARCH_GFX942 "Build with support for gfx942 (MI300)" OFF)
option(PENNANT_ARCH_GFX1030 "Build with support for gfx1030 (Navi21)" OFF)
option(PENNANT_SAVE_TEMPS "Save temporary compilation files for sources with device code" OFF)

# Pick your favorite GPU vendor
set(PENNANT_GPU_VENDOR "AMD" CACHE STRING "Are we using AMD or NVIDIA GPUs?")
string(TOLOWER ${PENNANT_GPU_VENDOR} lc_pennant_gpu_vendor) # set the lower case name for use to find paths
set_property(CACHE PENNANT_GPU_VENDOR PROPERTY STRINGS "AMD" "NVIDIA")

# Load CMake settings for building HIP code. Mark some CMake variables defined
# by the HIP package as advanced, so that they don't show up by default when
# using ccmake.
find_package(HIP REQUIRED)
mark_as_advanced(FORCE
  GPU_TARGETS
  AMDGPU_TARGETS
  AMDDeviceLibs_DIR
  HIP_CLANG_INCLUDE_PATH
  HIP_DIR
  HIP_VERBOSE_BUILD
  HSA_HEADER
  ROCclr_DIR
  amd_comgr_DIR
  hsa-runtime64_DIR)

# Use hipcc for compiling and linking
set(CMAKE_CXX_COMPILER ${HIP_HIPCC_EXECUTABLE})
#set(CMAKE_CXX_LINK_EXECUTABLE  ${HIP_HIPCC_EXECUTABLE})
# don't need to set linker, cmake uses hipcc 



# Basic set of PENNANT source files
set(pennant_sources
  src/Driver.cc
  src/ExportGold.cc
  src/GenMesh.cc
  src/HydroBC.cc
  src/Hydro.cc
  src/InputFile.cc
  src/main.cc
  src/Mesh.cc
  src/Parallel.cc
  src/PolyGas.cc
  src/QCS.cc
  src/TTS.cc
  src/WriteXY.cc)

if(PENNANT_USE_GPU_AWARE_MPI)
  SET(PENNANT_USE_MPI ON CACHE BOOL "Build with MPI support" FORCE)
endif()

# PENNANT source file that handles MPI comms, if MPI is supported
# may want to use MPI_CXX_ADDITIONAL_INCLUDE_DIRS 
if(PENNANT_USE_MPI)
  set(MPI_CXX_ADDITIONAL_INCLUDE_DIRS "$ENV{MPICH_DIR}/include")	  
  message("$ENV{MPICH_DIR} is MPICH_DIR") 
  #  list(APPEND pennant_sources src/HydroMPI.cc)
  list(APPEND PENNANT_COMPILATION_OPTIONS -I/${MPI_CXX_ADDITIONAL_INCLUDE_DIRS})
endif()


# PENNANT source file with functionality for timing various sections of the code
if(PENNANT_TIMERS)
  list(APPEND pennant_sources timers/scoped_timers.cpp)
endif()

# At this point, the list of sources is complete, and we can add them to the executable
add_executable(pennant ${pennant_sources})

# One timers include file is always included, even if we're not using
# timers; in that case, the macros in the include file evaluate to the empty string
target_include_directories(pennant PRIVATE timers)

# compilation options
# todo: differentiate between Debug, Release, RelWithDebug builds
if(PENNANT_GPU_VENDOR STREQUAL "AMD")
	#list(APPEND PENNANT_COMPILATION_OPTIONS "-g" "-O3" "-Wall" "-Wno-unused-result" "-Wno-unused-command-line-argument" "-Werror")
	list(APPEND PENNANT_COMPILATION_OPTIONS "-g" "-O3" "-Wall" "-Wno-unused-result" "-Wno-unused-command-line-argument" )
endif()
if(PENNANT_GPU_VENDOR STREQUAL "NVIDIA")
  list(APPEND PENNANT_COMPILATION_OPTIONS "-O3" "-Xcompiler" "-Wall -Wno-unknown-pragmas")
endif()

if(PENNANT_FAST_MATH)
  list(APPEND PENNANT_COMPILATION_OPTIONS "-ffp-contract=fast" "-ffast-math" )
endif()

if(PENNANT_UNSAFE_MATH_OPT)
  list(APPEND PENNANT_COMPILATION_OPTIONS "-funsafe-math-optimizations")
endif()

if(PENNANT_MEM_ALIGN)
  list(APPEND PENNANT_COMPILATION_OPTIONS "-faligned-allocation" "-fnew-alignment=64")
endif()

if(PENNANT_GPU_VENDOR STREQUAL "AMD")
  if(PENNANT_ARCH_GFX900)
    list(APPEND PENNANT_COMPILATION_OPTIONS "--offload-arch=gfx900")
    list(APPEND PENNANT_ARCH_LIST "gfx900")
    set(PENNANT_HAVE_ARCH true)
  endif()
  if(PENNANT_ARCH_GFX906)
    list(APPEND PENNANT_COMPILATION_OPTIONS "--offload-arch=gfx906")
    list(APPEND PENNANT_ARCH_LIST "gfx906")
    set(PENNANT_HAVE_ARCH true)
  endif()
  if(PENNANT_ARCH_GFX908)
    list(APPEND PENNANT_COMPILATION_OPTIONS "--offload-arch=gfx908")
    list(APPEND PENNANT_ARCH_LIST "gfx908")
    set(PENNANT_HAVE_ARCH true)
  endif()
  if(PENNANT_ARCH_GFX90A)
    list(APPEND PENNANT_COMPILATION_OPTIONS "--offload-arch=gfx90a")
    list(APPEND PENNANT_ARCH_LIST "gfx90a")
    set(PENNANT_HAVE_ARCH true)
  endif()
  if(PENNANT_ARCH_GFX942)
    list(APPEND PENNANT_COMPILATION_OPTIONS "--offload-arch=gfx942")
    list(APPEND PENNANT_ARCH_LIST "gfx942")
    set(PENNANT_HAVE_ARCH true)
  endif()
  if(PENNANT_ARCH_GFX1030)
    list(APPEND PENNANT_COMPILATION_OPTIONS "--offload-arch=gfx1030")
    list(APPEND PENNANT_ARCH_LIST "gfx1030")
    set(PENNANT_HAVE_ARCH true)
  endif()
  #  if(NOT PENNANT_HAVE_ARCH)
  # message(SEND_ERROR "You must specify at least one GPU architecture, e.g. -DPENNANT_ARCH_GFX90A=On")
  #endif()
endif()

if(PENNANT_GPU_VENDOR STREQUAL "NVIDIA")
  list(APPEND PENNANT_COMPILATION_OPTIONS "-arch=sm_70")
endif()

if(PENNANT_ROCTX)
  list(APPEND PENNANT_COMPILATION_OPTIONS "-I/opt/rocm/roctracer/include")
  target_compile_definitions(pennant PRIVATE USE_ROCTX)
  target_link_options(pennant PRIVATE "-L/opt/rocm/lib")
  target_link_libraries(pennant PRIVATE "roctx64")
endif()

target_compile_options(pennant PRIVATE ${PENNANT_COMPILATION_OPTIONS})

# Add compilation option to save temporary files just for the one source file that has device code
if(PENNANT_SAVE_TEMPS)
  set_source_files_properties(src/HydroGPU.cc PROPERTIES COMPILE_FLAGS -save-temps)
endif()

# Optionally configure MPI 
if(PENNANT_USE_MPI)
  # To select a specific MPI version, users should define an environment
  # variable MPI_HOME when running cmake or ccmake (only needed once)
  find_package(MPI REQUIRED)
  # show some of the MPI variable if we use ccmake, to help verifying
  # that we use the expected MPI version
  mark_as_advanced(CLEAR
    MPI_CXX_HEADER_DIR
    MPI_CXX_LINK_FLAGS
    MPI_CXX_ADDITIONAL_INCLUDE_DIRS 
    MPI_mpi_LIBRARY)

  target_compile_definitions(pennant PRIVATE USE_MPI)
  target_link_libraries(pennant PRIVATE $ENV{MPICH_DIR}/lib/libmpi.so)
  #target_link_libraries(pennant PRIVATE MPI_CXX_LIBRARIES)
endif()
if(PENNANT_USE_OPENMP)
  find_package(OpenMP)
  if(OpenMP_CXX_FOUND)
    target_link_libraries(pennant PRIVATE OpenMP::OpenMP_CXX)
    target_link_options(pennant PRIVATE "-fopenmp")  # can be done much more correctly
  endif()
endif()

if(PENNANT_USE_GPU_AWARE_MPI)
	set(PENNANT_LINK_OPTIONS "$ENV{PE_MPICH_GTL_DIR_${lc_pennant_gpu_vendor}_${PENNANT_ARCH_LIST}}" "$ENV{PE_MPICH_GTL_LIBS_${lc_pennant_gpu_vendor}_${PENNANT_ARCH_LIST}}")

  target_compile_definitions(pennant PRIVATE USE_GPU_AWARE_MPI)
  target_link_options(pennant PRIVATE ${PENNANT_LINK_OPTIONS})
  #  target_link_options(pennant PRIVATE "-L/opt/cray/pe/mpich/8.1.28/gtl/lib" "-lmpi_gtl_hsa")  
endif()

if(PENNANT_USE_XPMEM)
	set(PENNANT_LINK_OPTIONS ${PENNANT_LINK_OPTIONS} -lxpmem)
  	target_link_options(pennant PRIVATE ${PENNANT_LINK_OPTIONS})
endif()   

message("************* PENNANT_LINK_OPTIONS" , ${PENNANT_LINK_OPTIONS})

# Optionally configure the use of timing code
if(PENNANT_TIMERS)
  target_compile_definitions(pennant PRIVATE USE_TIMERS)
endif()

# If we save temporary files for the single file with device code, do a bit of
# automatic cleanup: only save the file(s) with the GPU ISA, and remove the rest
if(PENNANT_SAVE_TEMPS)
  foreach(PENNANT_ARCH ${PENNANT_ARCH_LIST})
    add_custom_command(TARGET pennant POST_BUILD
      COMMAND mv HydroGPU-hip-*${PENNANT_ARCH}.s HydroGPU.${PENNANT_ARCH}.s)
  endforeach()
    add_custom_command(TARGET pennant POST_BUILD
      COMMAND rm -f *-hip-* *-host-*)
endif()

# "make clean" doesn't take care of the (renamed) temporary ISA file for the single source
# file with device code; add that file to the list of files to be removed by "make clean".
foreach(PENNANT_ARCH ${PENNANT_ARCH_LIST})
  set_property(TARGET pennant APPEND PROPERTY ADDITIONAL_CLEAN_FILES HydroGPU.${PENNANT_ARCH}.s)
endforeach()



#install(PROGRAMS pennant DESTINATION ${CMAKE_INSTALL_DIR})
install(TARGETS pennant)
#install(PROGRAMS pennant TYPE bin DESTINATION bin)
