######################################################################
#
# DESCRIPTION: CMake configuration file for Verilator
#
# Include it in your CMakeLists.txt using:
#
#     find_package(verilate)
#
#  This script adds a verilate function.
#
#     add_executable(simulator <your-c-sources>)
#     verilate(simulator SOURCES <your-hdl-sources>)
#
# Copyright 2003-2024 by Wilson Snyder. This program is free software; you
# can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License Version 3 or the Perl Artistic License
# Version 2.0.
# SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
#
######################################################################

cmake_minimum_required(VERSION 3.13)

# Prefer VERILATOR_ROOT from environment
if (DEFINED ENV{VERILATOR_ROOT})
  set(VERILATOR_ROOT "$ENV{VERILATOR_ROOT}" CACHE PATH "VERILATOR_ROOT")
endif()

set(VERILATOR_ROOT "${CMAKE_CURRENT_LIST_DIR}" CACHE PATH "VERILATOR_ROOT")

find_program(VERILATOR_BIN NAMES verilator_bin verilator_bin.exe
  HINTS ${VERILATOR_ROOT}/bin ENV VERILATOR_ROOT
  NO_CMAKE_PATH NO_CMAKE_ENVIRONMENT_PATH NO_CMAKE_SYSTEM_PATH)

if (NOT VERILATOR_ROOT)
  message(FATAL_ERROR "VERILATOR_ROOT cannot be detected. Set it to the appropriate directory (e.g. /usr/share/verilator) as an environment variable or CMake define.")
endif()

if (NOT VERILATOR_BIN)
  message(FATAL_ERROR "Cannot find verilator_bin excecutable.")
endif()

set(verilator_FOUND 1)

include(CheckCXXSourceCompiles)
function(_verilator_check_cxx_libraries LIBRARIES RESVAR)
  # Check whether a particular link option creates a valid executable
  set(_VERILATOR_CHECK_CXX_LINK_OPTIONS_SRC "int main() {return 0;}\n")
  set(CMAKE_REQUIRED_FLAGS)
  set(CMAKE_REQUIRED_DEFINITIONS)
  set(CMAKE_REQUIRED_INCLUDES)
  set(CMAKE_REQUIRED_LINK_OPTIONS)
  set(CMAKE_REQUIRED_LIBRARIES ${LIBRARIES})
  set(CMAKE_REQUIRED_QUIET)
  check_cxx_source_compiles("${_VERILATOR_CHECK_CXX_LINK_OPTIONS_SRC}" "${RESVAR}")
  set("${RESVAR}" "${${RESVAR}}" PARENT_SCOPE)
endfunction()

# Check compiler flag support. Skip on MSVC, these are all GCC flags.
if (NOT CMAKE_CXX_COMPILER_ID MATCHES MSVC)
  if (NOT DEFINED VERILATOR_CFLAGS OR NOT DEFINED VERILATOR_MT_CFLAGS)
    include(CheckCXXCompilerFlag)
    foreach (FLAG )
      string(MAKE_C_IDENTIFIER ${FLAG} FLAGNAME)
      check_cxx_compiler_flag(${FLAG} ${FLAGNAME})
      if (${FLAGNAME})
        list(APPEND VERILATOR_CFLAGS ${FLAG})
      endif()
    endforeach()
    foreach (FLAG )
      string(MAKE_C_IDENTIFIER ${FLAG} FLAGNAME)
      _verilator_check_cxx_libraries("${FLAG}" ${FLAGNAME})
      if (${FLAGNAME})
        list(APPEND VERILATOR_MT_CFLAGS ${FLAG})
      endif()
    endforeach()
  endif()
endif()

if (${CMAKE_CXX_COMPILER_ID} STREQUAL "AppleClang")
  add_link_options(-Wl,-U,__Z15vl_time_stamp64v,-U,__Z13sc_time_stampv)
endif()

define_property(TARGET
  PROPERTY VERILATOR_THREADED
  BRIEF_DOCS "Deprecated and has no effect (ignored)"
  FULL_DOCS "Deprecated and has no effect (ignored)"
)

define_property(TARGET
  PROPERTY VERILATOR_TRACE_THREADED
  BRIEF_DOCS "Verilator multithread tracing enabled"
  FULL_DOCS "Verilator multithread tracing enabled"
)

define_property(TARGET
  PROPERTY VERILATOR_TIMING
  BRIEF_DOCS "Verilator timing enabled"
  FULL_DOCS "Verilator timing enabled"
)

define_property(TARGET
  PROPERTY VERILATOR_COVERAGE
  BRIEF_DOCS "Verilator coverage enabled"
  FULL_DOCS "Verilator coverage enabled"
)

define_property(TARGET
  PROPERTY VERILATOR_TRACE
  BRIEF_DOCS "Verilator trace enabled"
  FULL_DOCS "Verilator trace enabled"
)

define_property(TARGET
  PROPERTY VERILATOR_TRACE_VCD
  BRIEF_DOCS "Verilator VCD trace enabled"
  FULL_DOCS "Verilator VCD trace enabled"
)

define_property(TARGET
  PROPERTY VERILATOR_TRACE_FST
  BRIEF_DOCS "Verilator FST trace enabled"
  FULL_DOCS "Verilator FST trace enabled"
)

define_property(TARGET
  PROPERTY VERILATOR_SYSTEMC
  BRIEF_DOCS "Verilator SystemC enabled"
  FULL_DOCS "Verilator SystemC enabled"
)

define_property(TARGET
    PROPERTY VERILATOR_TRACE_STRUCTS
    BRIEF_DOCS "Verilator trace structs enabled"
    FULL_DOCS "Verilator trace structs enabled"
)


function(verilate TARGET)
  cmake_parse_arguments(VERILATE "COVERAGE;TRACE;TRACE_FST;SYSTEMC;TRACE_STRUCTS"
                                 "PREFIX;TOP_MODULE;THREADS;TRACE_THREADS;DIRECTORY"
                                 "SOURCES;VERILATOR_ARGS;INCLUDE_DIRS;OPT_SLOW;OPT_FAST;OPT_GLOBAL"
                                 ${ARGN})
  if (NOT VERILATE_SOURCES)
    message(FATAL_ERROR "Need at least one source")
  endif()

  if (NOT VERILATE_PREFIX)
    list(LENGTH VERILATE_SOURCES NUM_SOURCES)
    if (${NUM_SOURCES} GREATER 1)
      message(WARNING "Specify PREFIX if there are multiple SOURCES")
    endif()
    list(GET VERILATE_SOURCES 0 TOPSRC)
    get_filename_component(_SRC_NAME ${TOPSRC} NAME_WE)
    string(MAKE_C_IDENTIFIER V${_SRC_NAME} VERILATE_PREFIX)
  endif()

  if (VERILATE_TOP_MODULE)
    list(APPEND VERILATOR_ARGS --top ${VERILATE_TOP_MODULE})
  endif()

  if (VERILATE_THREADS)
    list(APPEND VERILATOR_ARGS --threads ${VERILATE_THREADS})
  endif()

  if (VERILATE_TRACE_THREADS)
    list(APPEND VERILATOR_ARGS --trace-threads ${VERILATE_TRACE_THREADS})
  endif()

  if (VERILATE_COVERAGE)
    list(APPEND VERILATOR_ARGS --coverage)
  endif()

  if (VERILATE_TRACE AND VERILATE_TRACE_FST)
    message(FATAL_ERROR "Cannot have both TRACE and TRACE_FST")
  endif()

  if (VERILATE_TRACE)
    list(APPEND VERILATOR_ARGS --trace)
  endif()

  if (VERILATE_TRACE_FST)
    list(APPEND VERILATOR_ARGS --trace-fst)
  endif()

  if (VERILATE_SYSTEMC)
    list(APPEND VERILATOR_ARGS --sc)
  else()
    list(APPEND VERILATOR_ARGS --cc)
  endif()

  if (VERILATE_TRACE_STRUCTS)
      list(APPEND VERILATOR_ARGS --trace-structs)
  endif()

  foreach(INC ${VERILATE_INCLUDE_DIRS})
    list(APPEND VERILATOR_ARGS -y "${INC}")
  endforeach()

  string(TOLOWER ${CMAKE_CXX_COMPILER_ID} COMPILER)
  if (COMPILER STREQUAL "appleclang")
    set(COMPILER clang)
  elseif (NOT COMPILER MATCHES "^msvc$|^clang$")
    set(COMPILER gcc)
  endif()

  get_target_property(BINARY_DIR "${TARGET}" BINARY_DIR)
  get_target_property(TARGET_NAME "${TARGET}" NAME)
  set(VDIR "${BINARY_DIR}/CMakeFiles/${TARGET_NAME}.dir/${VERILATE_PREFIX}.dir")

  if (VERILATE_DIRECTORY)
    set(VDIR "${VERILATE_DIRECTORY}")
  endif()

  file(MAKE_DIRECTORY ${VDIR})

  set(VERILATOR_COMMAND "${CMAKE_COMMAND}" -E env "VERILATOR_ROOT=${VERILATOR_ROOT}"
                        "${VERILATOR_BIN}" --compiler ${COMPILER}
                        --prefix ${VERILATE_PREFIX} --Mdir ${VDIR} --make cmake
                        ${VERILATOR_ARGS} ${VERILATE_VERILATOR_ARGS}
                        ${VERILATE_SOURCES})

  set(VARGS_FILE "${VDIR}/verilator_args.txt")
  set(VCMAKE "${VDIR}/${VERILATE_PREFIX}.cmake")
  set(VCMAKE_COPY "${VDIR}/${VERILATE_PREFIX}_copy.cmake")

  if (NOT EXISTS "${VARGS_FILE}" OR NOT EXISTS "${VCMAKE_COPY}")
    set(VERILATOR_OUTDATED ON)
  else()
    file(READ "${VARGS_FILE}" PREVIOUS_VERILATOR_COMMAND)
    if(NOT VERILATOR_COMMAND STREQUAL PREVIOUS_VERILATOR_COMMAND)
      set(VERILATOR_OUTDATED ON)
    endif()
  endif()

  if (VERILATOR_OUTDATED)
    message(STATUS "Executing Verilator...")
    execute_process(
      COMMAND ${VERILATOR_COMMAND}
      WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
      RESULT_VARIABLE _VERILATOR_RC
      OUTPUT_VARIABLE _VERILATOR_OUTPUT
      ERROR_VARIABLE _VERILATOR_OUTPUT)
    if (_VERILATOR_RC)
      string(REPLACE ";" " " VERILATOR_COMMAND_READABLE "${VERILATOR_COMMAND}")
      message("Verilator command: \"${VERILATOR_COMMAND_READABLE}\"")
      message("Output:\n${_VERILATOR_OUTPUT}")
      message(FATAL_ERROR "Verilator command failed (return code=${_VERILATOR_RC})")
    endif()
    execute_process(COMMAND "${CMAKE_COMMAND}" -E copy "${VCMAKE}" "${VCMAKE_COPY}")
  endif()
  file(WRITE "${VARGS_FILE}" "${VERILATOR_COMMAND}")

  include("${VCMAKE_COPY}")

  set(GENERATED_C_SOURCES ${${VERILATE_PREFIX}_CLASSES_FAST}
                          ${${VERILATE_PREFIX}_CLASSES_SLOW}
                          ${${VERILATE_PREFIX}_SUPPORT_FAST}
                          ${${VERILATE_PREFIX}_SUPPORT_SLOW})
  # No need for .h's as the .cpp will get written same time
  set(GENERATED_SOURCES ${GENERATED_C_SOURCES})

  add_custom_command(OUTPUT ${GENERATED_SOURCES} "${VCMAKE}"
                     COMMAND ${VERILATOR_COMMAND}
                     WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                     DEPENDS "${VERILATOR_BIN}" ${${VERILATE_PREFIX}_DEPS} VERBATIM)
  # Reconfigure if file list has changed
  # (check contents rather than modified time to avoid unnecessary reconfiguration)
  add_custom_command(OUTPUT "${VCMAKE_COPY}"
                     COMMAND "${CMAKE_COMMAND}" -E copy_if_different
                     "${VCMAKE}" "${VCMAKE_COPY}"
                     DEPENDS "${VCMAKE}" VERBATIM)

  if (${VERILATE_PREFIX}_COVERAGE)
    # If any verilate() call specifies COVERAGE, define VM_COVERAGE in the final build
    set_property(TARGET ${TARGET} PROPERTY VERILATOR_COVERAGE ON)
  endif()

  if (${VERILATE_PREFIX}_TRACE_VCD)
    # If any verilate() call specifies TRACE, define VM_TRACE in the final build
    set_property(TARGET ${TARGET} PROPERTY VERILATOR_TRACE ON)
    set_property(TARGET ${TARGET} PROPERTY VERILATOR_TRACE_VCD ON)
  endif()

  if (${VERILATE_PREFIX}_TRACE_FST)
    # If any verilate() call specifies TRACE_FST, define VM_TRACE_FST in the final build
    set_property(TARGET ${TARGET} PROPERTY VERILATOR_TRACE ON)
    set_property(TARGET ${TARGET} PROPERTY VERILATOR_TRACE_FST ON)
  endif()

  if (${VERILATE_PREFIX}_SC)
    # If any verilate() call specifies SYSTEMC, define VM_SC in the final build
    set_property(TARGET ${TARGET} PROPERTY VERILATOR_SYSTEMC ON)
  endif()

  if (${VERILATE_PREFIX}_TRACE_STRUCTS)
    set_property(TARGET ${TARGET} PROPERTY VERILATOR_TRACE_STRUCTS ON)
  endif()

    # Add the compile flags only on Verilated sources
  target_include_directories(${TARGET} PUBLIC ${VDIR})
  target_sources(${TARGET} PRIVATE ${GENERATED_SOURCES} "${VCMAKE_COPY}"
                                   ${${VERILATE_PREFIX}_GLOBAL}
                                   ${${VERILATE_PREFIX}_USER_CLASSES})
  foreach(_VSOURCE ${VERILATE_SOURCES} ${${VERILATE_PREFIX}_DEPS})
    get_filename_component(_VSOURCE "${_VSOURCE}" ABSOLUTE BASE_DIR)
    list(APPEND VHD_SOURCES "${_VSOURCE}")
  endforeach()
  target_sources(${TARGET} PRIVATE ${VHD_SOURCES})

  # Add the compile flags only on Verilated sources
  foreach(VSLOW ${${VERILATE_PREFIX}_CLASSES_SLOW} ${${VERILATE_PREFIX}_SUPPORT_SLOW})
    foreach(OPT_SLOW ${VERILATE_OPT_SLOW} ${${VERILATE_PREFIX}_USER_CFLAGS})
      set_property(SOURCE "${VSLOW}" APPEND_STRING PROPERTY COMPILE_FLAGS " ${OPT_SLOW}")
    endforeach()
  endforeach()
  foreach(VFAST ${${VERILATE_PREFIX}_CLASSES_FAST} ${${VERILATE_PREFIX}_SUPPORT_FAST})
    foreach(OPT_FAST ${VERILATE_OPT_FAST} ${${VERILATE_PREFIX}_USER_CFLAGS})
      set_property(SOURCE "${VFAST}" APPEND_STRING PROPERTY COMPILE_FLAGS " ${OPT_FAST}")
    endforeach()
  endforeach()
  foreach(VGLOBAL ${${VERILATE_PREFIX}_GLOBAL})
    foreach(OPT_GLOBAL ${VERILATE_OPT_GLOBAL} ${${VERILATE_PREFIX}_USER_CFLAGS})
      set_property(SOURCE "${VGLOBAL}" APPEND_STRING PROPERTY COMPILE_FLAGS " ${OPT_GLOBAL}")
    endforeach()
  endforeach()

  target_include_directories(${TARGET} PUBLIC "${VERILATOR_ROOT}/include"
                                               "${VERILATOR_ROOT}/include/vltstd")
  target_compile_definitions(${TARGET} PRIVATE
    VM_COVERAGE=$<BOOL:$<TARGET_PROPERTY:VERILATOR_COVERAGE>>
    VM_SC=$<BOOL:$<TARGET_PROPERTY:VERILATOR_SYSTEMC>>
    VM_TRACE=$<BOOL:$<TARGET_PROPERTY:VERILATOR_TRACE>>
    VM_TRACE_VCD=$<BOOL:$<TARGET_PROPERTY:VERILATOR_TRACE_VCD>>
    VM_TRACE_FST=$<BOOL:$<TARGET_PROPERTY:VERILATOR_TRACE_FST>>
  )

  target_link_libraries(${TARGET} PUBLIC
    ${${VERILATE_PREFIX}_USER_LDLIBS}
  )

  target_link_libraries(${TARGET} PUBLIC
    ${VERILATOR_MT_CFLAGS}
  )

  target_compile_features(${TARGET} PRIVATE cxx_std_11)

  if (${VERILATE_PREFIX}_TIMING)
    check_cxx_compiler_flag(-fcoroutines-ts COROUTINES_TS_FLAG)
    target_compile_options(${TARGET} PRIVATE $<IF:$<BOOL:${COROUTINES_TS_FLAG}>,-fcoroutines-ts,-fcoroutines>)
  endif()
endfunction()

function(_verilator_find_systemc)
  if (NOT TARGET Verilator::systemc)
    # Find SystemC include file "systemc.h" in the following order:
    # 1. SYSTEMC_INCLUDE (environment) variable
    # 2. SYSTEMC_ROOT (environment) variable
    # 3. SYSTEMC (environment) variable
    # 4. Use CMake module provided by SystemC installation
    #    (eventually requires CMAKE_PREFIX_PATH set)

    find_path(SYSTEMC_INCLUDEDIR NAMES systemc.h
      HINTS "${SYSTEMC_INCLUDE}   " ENV SYSTEMC_INCLUDE)
    find_path(SYSTEMC_INCLUDEDIR NAMES systemc.h
      HINTS "${SYSTEMC_ROOT}" ENV SYSTEMC_ROOT
      PATH_SUFFIXES include)
    find_path(SYSTEMC_INCLUDEDIR NAMES systemc.h
      HINTS "${SYSTEMC}" ENV SYSTEMC
      PATH_SUFFIXES include)

    # Find SystemC library in the following order:
    # 1. SYSTEMC_LIBDIR (environment) variable
    # 2. SYSTEMC_ROOT (environment) variable
    # 3. SYSTEMC (environment) variable
    # 4. Use CMake module provided by SystemC installation
    #    (eventually requires CMAKE_PREFIX_PATH set)

    # Find SystemC using include and library paths
    find_library(SYSTEMC_LIBRARY NAMES systemc
      HINTS "${SYSTEMC_LIBDIR}" ENV SYSTEMC_LIBDIR)
    find_library(SYSTEMC_LIBRARY NAMES systemc
      HINTS "${SYSTEMC_ROOT}" ENV SYSTEMC_ROOT
      PATH_SUFFIXES lib)
    find_library(SYSTEMC_LIBRARY NAMES systemc
      HINTS "${SYSTEMC}" ENV SYSTEMC
      PATH_SUFFIXES lib)

    if (SYSTEMC_INCLUDEDIR AND SYSTEMC_LIBRARY)
      add_library(Verilator::systemc INTERFACE IMPORTED)
      set_target_properties(Verilator::systemc
        PROPERTIES
          INTERFACE_INCLUDE_DIRECTORIES "${SYSTEMC_INCLUDEDIR}"
          INTERFACE_LINK_LIBRARIES "${SYSTEMC_LIBRARY}")
      return()
    endif()

    find_package(SystemCLanguage QUIET)
    if (SystemCLanguage_FOUND)
      add_library(Verilator::systemc INTERFACE IMPORTED)
      set_target_properties(Verilator::systemc
        PROPERTIES
          INTERFACE_LINK_LIBRARIES "SystemC::systemc")
      return()
    endif()

    message("SystemC not found. This can be fixed by doing either of the following steps:")
    message("- set the SYSTEMC_INCLUDE and SYSTEMC_LIBDIR (environment) variables; or")
    message("- set SYSTEMC_ROOT (environment) variable; or")
    message("- set SYSTEMC (environment) variable; or")
    message("- use the CMake module of your SystemC installation (may require CMAKE_PREFIX_PATH)")
    message(FATAL_ERROR "SystemC not found")
  endif()
endfunction()

function(verilator_link_systemc TARGET)
  _verilator_find_systemc()
  target_link_libraries("${TARGET}" PUBLIC Verilator::systemc)
  target_compile_options(${TARGET} PRIVATE $ENV{SYSTEMC_CXX_FLAGS} ${SYSTEMC_CXX_FLAGS})
endfunction()

function(verilator_generate_key OUTPUT_VARIABLE)
  execute_process(COMMAND ${VERILATOR_BIN} --generate-key
                  OUTPUT_VARIABLE KEY_VAL
                  RESULT_VARIABLE KEY_RET)
  if (KEY_RET)
    message(FATAL_ERROR "verilator --generate-key failed")
  endif()
  string(STRIP ${KEY_VAL} KEY_VAL)
  set(${OUTPUT_VARIABLE} ${KEY_VAL} PARENT_SCOPE)
endfunction()
