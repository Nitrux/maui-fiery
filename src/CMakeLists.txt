# Copyright 2018-2020 Camilo Higuita <milo.h@aol.com>
# Copyright 2018-2020 Nitrux Latinoamericana S.C.
#
# SPDX-License-Identifier: GPL-3.0-or-later
remove_definitions(-DQT_NO_CAST_FROM_ASCII -DQT_STRICT_ITERATORS -DQT_NO_CAST_FROM_BYTEARRAY -DQT_NO_URL_CAST_FROM_STRING)


set(fiery_SRCS
    main.cpp
    models/historymodel.cpp
    controllers/downloadsmanager.cpp
    controllers/dbactions.cpp
    db/db.cpp
    models/downloadsmodel.cpp
    models/bookmarksmodel.cpp
    controllers/surf.cpp
    controllers/fierywebprofile.cpp
    controllers/requestinterceptor.cpp
    controllers/passwordmanager.cpp)

# Download the Steven Black aggregated hosts blocklist at configure time.
# The file is placed in the build tree to avoid polluting the source tree.
# If the network is unavailable the built-in fallback list is copied instead.
set(_blocklist "${CMAKE_CURRENT_BINARY_DIR}/blocklist.txt")
if(NOT EXISTS "${_blocklist}")
    message(STATUS "Downloading Steven Black aggregated hosts blocklist...")
    file(DOWNLOAD
        "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
        "${_blocklist}"
        SHOW_PROGRESS
        TIMEOUT 30
        STATUS _dl_status)
    list(GET _dl_status 0 _dl_code)
    if(NOT _dl_code EQUAL 0)
        message(WARNING "Blocklist download failed (${_dl_status}); using built-in fallback.")
        configure_file("${CMAKE_CURRENT_SOURCE_DIR}/blocklist.txt" "${_blocklist}" COPYONLY)
    endif()
endif()

qt_add_resources(fiery_ASSETS
    assets/img_assets.qrc
    assets.qrc)

qt_add_executable(${PROJECT_NAME}
    ${fiery_SRCS}
    ${fiery_ASSETS})

set_target_properties(${PROJECT_NAME} PROPERTIES UNITY_BUILD ON)

# Bundle the downloaded blocklist. The target form of qt_add_resources is used
# here because the file lives in the build tree, not the source tree.
qt_add_resources(${PROJECT_NAME} "blocklist"
    PREFIX "/"
    BASE "${CMAKE_CURRENT_BINARY_DIR}"
    FILES "${_blocklist}")

qt_policy(SET QTP0001 OLD) # keep :/app/maui/fiery/ resource prefix
qt_policy(SET QTP0004 OLD) # no qmldir required for subdirectories

qt_add_qml_module(${PROJECT_NAME} URI app.maui.fiery
    NO_PLUGIN
    QML_FILES
    main.qml
    views/widgets/SettingsDialog.qml
    views/browser/BrowserView.qml
    views/history/HistoryView.qml
    views/browser/BrowserLayout.qml
    views/browser/Browser.qml
    views/widgets/NavigationBar.qml
    views/browser/ActionsMenu.qml
    views/home/HomeView.qml
    views/AppView.qml)

find_package(PkgConfig REQUIRED)
pkg_check_modules(libsecret REQUIRED IMPORTED_TARGET libsecret-1)

target_precompile_headers(${PROJECT_NAME} PRIVATE
    <QObject>
    <QString>
    <QUrl>
    <QVariantMap>
    <QSqlQuery>
    <QtWebEngineQuick/QQuickWebEngineProfile>)

target_link_libraries(${PROJECT_NAME}
    PRIVATE
    MauiKit4
    MauiKit4::FileBrowsing
    Qt6::Widgets
    Qt6::Sql
    Qt6::Qml
    KF6::I18n
    KF6::CoreAddons
    KF6::Notifications

    Qt::WebEngineCore
    Qt::WebEngineQuick
    PkgConfig::libsecret)
