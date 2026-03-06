cmake_minimum_required(VERSION 3.14)
project("mtl")

find_package(PkgConfig REQUIRED)
pkg_check_modules(DPDK REQUIRED libdpdk)
pkg_check_modules(JSON_C REQUIRED json-c IMPORTED_TARGET)
pkg_check_modules(BPF libbpf IMPORTED_TARGET)
pkg_check_modules(XDP libxdp IMPORTED_TARGET)

if(BPF_FOUND AND XDP_FOUND)
	find_program(XDP_CLANG clang)
	find_program(XDP_LLVM_STRIP llvm-strip)
	
	if(NOT XDP_CLANG OR NOT XDP_LLVM_STRIP)
		message(FATAL_ERROR "Cannot find clang and llvm-strip that needed for af_xdp backend")
	endif()

	set(MTL_HAS_XDP_BACKEND TRUE)
else()
	message(STATUS "Cannot found libxdp or libbpf, no af_xdp backend")
	set(MTL_HAS_XDP_BACKEND FALSE)
endif()

execute_process(COMMAND git describe --abbrev=8 --always OUTPUT_VARIABLE MTL_GIT OUTPUT_STRIP_TRAILING_WHITESPACE)

set(MTL_COMPILER ${CMAKE_C_COMPILER_ID}-${CMAKE_C_COMPILER_VERSION})

# version
file(READ ../VERSION MTL_VERSION)
string(REPLACE "." ";" MTL_VERSION_LIST ${MTL_VERSION})
list(GET MTL_VERSION_LIST 0 MTL_VERSION_MAJOR)
list(GET MTL_VERSION_LIST 1 MTL_VERSION_MINOR)
list(GET MTL_VERSION_LIST 2 MTL_VERSION_LAST)
list(GET MTL_VERSION_LIST 3 MTL_VERSION_EXTRA)
math(EXPR MTL_VERSION_MAJOR ${MTL_VERSION_MAJOR})
math(EXPR MTL_VERSION_MINOR ${MTL_VERSION_MINOR})
math(EXPR MTL_VERSION_LAST ${MTL_VERSION_LAST})

set(CMAKE_BUILD_RPATH_USE_ORIGIN ON)

include_directories(../include ${CMAKE_CURRENT_BINARY_DIR})

add_link_options("LINKER:-z,defs")				# fail if unresolved
add_link_options("LINKER:--as-needed")

# MTL
configure_file(mtl_build_config.h.in mtl_build_config.h)

add_library(mtl SHARED
	../lib/src/mt_main.c
	../lib/src/mt_sch.c
	../lib/src/mt_cni.c
	../lib/src/mt_ptp.c
	../lib/src/mt_arp.c
	../lib/src/mt_dhcp.c
	../lib/src/mt_mcast.c
	../lib/src/mt_util.c
	../lib/src/mt_dma.c
	../lib/src/mt_admin.c
	../lib/src/mt_config.c
	../lib/src/mt_socket.c
	../lib/src/mt_stat.c
	../lib/src/mt_rtcp.c
	../lib/src/mt_flow.c
	../lib/src/mt_instance.c
	../lib/src/mt_log.c
	../lib/src/mt_pcap.c
	# ../lib/src/mt_tap.c

	../lib/src/datapath/mt_queue.c
	../lib/src/datapath/mt_shared_queue.c
	../lib/src/datapath/mt_shared_rss.c
	../lib/src/datapath/mt_dp_socket.c

	../lib/src/dev/mt_dev.c
	#../lib/src/dev/mt_rdma_ud.c

	../lib/src/st2110/st_tx_video_session.c
	../lib/src/st2110/st_video_transmitter.c
	../lib/src/st2110/st_rx_video_session.c
	../lib/src/st2110/st_tx_audio_session.c
	../lib/src/st2110/st_audio_transmitter.c
	../lib/src/st2110/st_rx_audio_session.c
	../lib/src/st2110/st_tx_ancillary_session.c
	../lib/src/st2110/st_rx_ancillary_session.c
	../lib/src/st2110/st_ancillary_transmitter.c
	../lib/src/st2110/st_ancillary.c
	../lib/src/st2110/st_tx_fastmetadata_session.c
	../lib/src/st2110/st_rx_fastmetadata_session.c
	../lib/src/st2110/st_fastmetadata_transmitter.c
	../lib/src/st2110/st_avx2.c
	../lib/src/st2110/st_avx512.c
	../lib/src/st2110/st_avx512_vbmi.c
	../lib/src/st2110/st_convert.c
	../lib/src/st2110/st_fmt.c
	../lib/src/st2110/st_rx_timing_parser.c

	../lib/src/st2110/pipeline/st_plugin.c
	../lib/src/st2110/pipeline/st22_pipeline_tx.c
	../lib/src/st2110/pipeline/st22_pipeline_rx.c
	../lib/src/st2110/pipeline/st20_pipeline_tx.c
	../lib/src/st2110/pipeline/st20_pipeline_rx.c
	../lib/src/st2110/pipeline/st30_pipeline_tx.c
	../lib/src/st2110/pipeline/st30_pipeline_rx.c

	../lib/src/st2110/experimental/st20_redundant_combined_rx.c

	../lib/src/udp/udp_rxq.c
	../lib/src/udp/udp_main.c
	../lib/src/udp/ufd_main.c
	)

target_compile_definitions(mtl PRIVATE __MTL_LIB_BUILD__="${MTL_VERSION}")
target_compile_definitions(mtl PRIVATE __MTL_GIT__="${MTL_GIT}")
target_compile_definitions(mtl PRIVATE ALLOW_EXPERIMENTAL_API)

target_compile_options(mtl PRIVATE -msse4.2 -DMTL_HAS_AVX2 -DMTL_HAS_AVX512 -DMTL_HAS_AVX512_VBMI2)
target_compile_options(mtl PRIVATE ${DPDK_STATIC_CFLAGS})

target_link_options(mtl PRIVATE ${DPDK_STATIC_LDFLAGS})
target_link_libraries(mtl PRIVATE ${DPDK_STATIC_LIBRARIES} PkgConfig::JSON_C)

if(MTL_HAS_XDP_BACKEND)
	target_compile_definitions(mtl PRIVATE MTL_HAS_XDP_BACKEND)
	target_sources(mtl PRIVATE ../lib/src/dev/mt_af_xdp.c)
	target_link_libraries(mtl PRIVATE PkgConfig::XDP PkgConfig::BPF)
endif()

set_target_properties(mtl PROPERTIES POSITION_INDEPENDENT_CODE TRUE)

# MtlManager
configure_file(mtlm_build_config.h.in mtlm_build_config.h)

add_executable(MtlManager
	../manager/mtl_manager.cpp
	)

target_compile_definitions(MtlManager PRIVATE __MTLM_GIT__="${MTL_GIT}")

set_target_properties(MtlManager PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED TRUE)

if(MTL_HAS_XDP_BACKEND)
	target_compile_definitions(MtlManager PRIVATE MTL_HAS_XDP_BACKEND)
	target_link_libraries(MtlManager PRIVATE PkgConfig::XDP PkgConfig::BPF)

	add_custom_command(OUTPUT mtl.xdp.o
		COMMAND ${XDP_CLANG} ARGS -g -O2 -target bpf -c ${CMAKE_CURRENT_SOURCE_DIR}/../manager/mtl.xdp.c -o mtl.xdp.temp.o
		COMMAND ${XDP_LLVM_STRIP} ARGS -g mtl.xdp.temp.o -o mtl.xdp.o
		MAIN_DEPENDENCY ${CMAKE_CURRENT_SOURCE_DIR}/../manager/mtl.xdp.c
		VERBATIM
		)
	add_custom_target(XDP DEPENDS mtl.xdp.o)
	add_dependencies(MtlManager XDP)
endif()

# install

include(GNUInstallDirs)
# hack for meson on debian, we use GNUInstallDirs internals!!!!
if("${CMAKE_INSTALL_PREFIX}" MATCHES "^/usr/local/?$")
	_GNUInstallDirs_LIBDIR_get_default(CMAKE_INSTALL_LIBDIR /usr)
	GNUInstallDirs_get_absolute_install_dir(CMAKE_INSTALL_FULL_LIBDIR CMAKE_INSTALL_LIBDIR LIBDIR)
endif()

install(TARGETS mtl MtlManager)
if(MTL_HAS_XDP_BACKEND)
	install(FILES ${CMAKE_CURRENT_BINARY_DIR}/mtl.xdp.o DESTINATION lib/bpf)
endif()