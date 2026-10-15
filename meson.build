project('fiery', 'cpp', version: '4.0.5', meson_version: '>=1.0.0', default_options: ['cpp_std=c++17', 'buildtype=release'])
qt6 = import('qt6')
cpp_compiler = meson.get_compiler('cpp')
if cpp_compiler.get_id() == 'gcc' and cpp_compiler.has_argument('-Wno-sfinae-incomplete')
    add_project_arguments('-Wno-sfinae-incomplete', language: 'cpp')
endif
qt = dependency('qt6', version: '>=6.9', modules: ['Widgets', 'Qml', 'Sql', 'Network', 'DBus', 'WebEngineCore', 'WebEngineQuick'])
kf6_core = dependency('KF6CoreAddons', version: '>=6.13')
kf6_i18n = declare_dependency(
    include_directories: include_directories(get_option('prefix') / 'include' / 'KF6' / 'KI18n'),
    dependencies: [cpp_compiler.find_library('KF6I18n'), cpp_compiler.find_library('KF6I18nQml')],
)
kf6_notifications = declare_dependency(
    include_directories: include_directories(get_option('prefix') / 'include' / 'KF6' / 'KNotifications'),
    dependencies: [cpp_compiler.find_library('KF6Notifications')],
)
mauikit = dependency('MauiKit4', version: '>=4.0.5')
filebrowsing = dependency('MauiKitFileBrowsing4', version: '>=4.0.5')
libsecret = dependency('libsecret-1', required: true)
cpp_args = []
if host_machine.cpu_family() == 'x86_64'
    cpp_args += ['-march=x86-64-v3', '-O3']
endif
fiery_version = configure_file(
    input: 'meson-content.in',
    output: 'fiery_version.h',
    configuration: {'CONTENT': ('''#pragma once
#define FIERY_VERSION_STRING "4.0.5"
#define GIT_BRANCH "Stable"
#define GIT_COMMIT_HASH "4.0.5"
''')}
)
fiery_includes = include_directories('src')
blocklist_download = run_command('curl', '-fsSL', 'https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts', check: false)
if blocklist_download.returncode() == 0 and blocklist_download.stdout().strip() != ''
    configure_file(
    input: 'meson-content.in',
    output: 'blocklist.txt',
    configuration: {'CONTENT': (blocklist_download.stdout())}
)
    blocklist_path = join_paths(meson.current_build_dir(), 'blocklist.txt')
else
    blocklist_path = join_paths(meson.current_source_dir(), 'src/blocklist.txt')
endif
blocklist_qrc = configure_file(
    input: 'meson-content.in',
    output: 'blocklist.qrc',
    configuration: {'CONTENT': ('''<RCC>
    <qresource prefix="/">
        <file alias="blocklist.txt">''' + blocklist_path + '''</file>
    </qresource>
</RCC>
''')}
)
fiery_sources = ['src/main.cpp', 'src/models/historymodel.cpp', 'src/controllers/downloadsmanager.cpp', 'src/controllers/dbactions.cpp', 'src/db/db.cpp', 'src/models/downloadsmodel.cpp', 'src/models/bookmarksmodel.cpp', 'src/controllers/surf.cpp', 'src/controllers/fierywebprofile.cpp', 'src/controllers/requestinterceptor.cpp', 'src/controllers/passwordmanager.cpp', 'src/controllers/widevineinstaller.cpp']
qt_sources = qt6.preprocess(qresources: ['src/assets.qrc', blocklist_qrc, 'src/qml.qrc'], moc_headers: ['src/models/historymodel.h', 'src/controllers/downloadsmanager.h', 'src/controllers/dbactions.h', 'src/db/db.h', 'src/models/downloadsmodel.h', 'src/models/bookmarksmodel.h', 'src/controllers/surf.h', 'src/controllers/fierywebprofile.h', 'src/controllers/requestinterceptor.h', 'src/controllers/passwordmanager.h', 'src/controllers/widevineinstaller.h'])
executable('fiery', fiery_sources + qt_sources + [fiery_version], dependencies: [qt, kf6_core, kf6_i18n, kf6_notifications, mauikit, filebrowsing, libsecret], include_directories: fiery_includes, cpp_args: cpp_args, install: true)
install_data('org.maui.fiery.desktop', install_dir: get_option('datadir') / 'applications')
install_data('org.maui.fiery.metainfo.xml', install_dir: get_option('datadir') / 'metainfo')
install_data('src/fiery.notifyrc', install_dir: get_option('datadir') / 'knotifications6')
