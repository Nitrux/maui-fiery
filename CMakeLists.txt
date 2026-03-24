cmake_minimum_required(VERSION 3.16)

# Suppress Qt CMake developer warnings about QML plugin static imports
# (irrelevant for shared/dynamic builds, which is the only build type supported)
set(CMAKE_SUPPRESS_DEVELOPER_WARNINGS TRUE CACHE BOOL "" FORCE)

# ── Widevine / DRM build requirement ─────────────────────────────────────────
# Widevine CDM decrypts the stream, but Qt WebEngine must also be able to
# *decode* the resulting video.  Streaming services (Netflix, Spotify, etc.)
# always deliver DRM content in H.264/AAC, which are proprietary codecs.
# If the Qt WebEngine library in use was NOT built with proprietary-codec
# support (-webengine-proprietary-codecs), Widevine will load but video will
# not play.  Most Debian/Ubuntu-derived distro packages ship with proprietary
# codecs enabled; verify with:
#   strings $(qmake6 -query QT_INSTALL_LIBS)/libQt6WebEngineCore.so.6 | grep -i h264
# If building Qt from source, configure the qtwebengine module with:
#   -webengine-proprietary-codecs
# ─────────────────────────────────────────────────────────────────────────────

set(FIERY_VERSION 4.0.2)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
    add_compile_options($<$<CONFIG:Release>:-march=x86-64-v3>
                        $<$<CONFIG:Release>:-O3>)
endif()

set(CMAKE_INCLUDE_CURRENT_DIR ON)

set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

project(fiery VERSION ${FIERY_VERSION})

set(QT_MAJOR_VERSION 6)

set(REQUIRED_QT_VERSION 6.8.2)
set(REQUIRED_KF_VERSION 5.240.0)

find_package(ECM ${REQUIRED_KF_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake" ${ECM_MODULE_PATH})

if(UNIX AND NOT APPLE AND NOT ANDROID)
    include(KDEInstallDirs)
    include(KDECMakeSettings)
endif()

include(KDECompilerSettings NO_POLICY_SCOPE)
include(KDEClangFormat)
include(ECMSetupVersion)
include(ECMSourceVersionControl)
include(FeatureSummary)

find_package(Qt6 ${REQUIRED_QT_VERSION} REQUIRED NO_MODULE COMPONENTS Widgets Qml Sql Network)
find_package(KF6 ${KF5_VERSION} REQUIRED COMPONENTS I18n CoreAddons Notifications)

find_package(Qt6WebEngineCore REQUIRED)
find_package(Qt6WebEngineQuick REQUIRED)

find_package(MauiKit4 REQUIRED COMPONENTS FileBrowsing)

if(${ECM_SOURCE_UNDER_VERSION_CONTROL})
    execute_process(
        COMMAND git rev-parse --abbrev-ref HEAD
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_BRANCH
        OUTPUT_STRIP_TRAILING_WHITESPACE)

    # Get the latest abbreviated commit hash of the working branch
    execute_process(
        COMMAND git log -1 --format=%h
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        OUTPUT_VARIABLE GIT_COMMIT_HASH
        OUTPUT_STRIP_TRAILING_WHITESPACE)

    add_definitions(-DGIT_COMMIT_HASH="${GIT_COMMIT_HASH}")
    add_definitions(-DGIT_BRANCH="${GIT_BRANCH}")

else()
    add_definitions(-DGIT_COMMIT_HASH="${FIERY_VERSION}")
    add_definitions(-DGIT_BRANCH="Stable")
endif()

ecm_setup_version(${FIERY_VERSION}
    VARIABLE_PREFIX FIERY
    VERSION_HEADER "${CMAKE_CURRENT_BINARY_DIR}/fiery_version.h")

add_subdirectory(src)

ki18n_install(po)

install(TARGETS ${PROJECT_NAME} ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
install(FILES org.kde.fiery.desktop DESTINATION ${KDE_INSTALL_APPDIR})
install(FILES org.kde.fiery.metainfo.xml DESTINATION ${KDE_INSTALL_METAINFODIR})
install(FILES src/assets/fiery.svg DESTINATION ${KDE_INSTALL_ICONDIR}/hicolor/scalable/apps)
install(FILES src/fiery.notifyrc DESTINATION ${KDE_INSTALL_KNOTIFYRCDIR})

feature_summary(WHAT ALL   FATAL_ON_MISSING_REQUIRED_PACKAGES)
file(GLOB_RECURSE ALL_CLANG_FORMAT_SOURCE_FILES *.cpp *.h)
kde_clang_format(${ALL_CLANG_FORMAT_SOURCE_FILES})
