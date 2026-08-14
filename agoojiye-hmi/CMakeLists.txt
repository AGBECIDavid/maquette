cmake_minimum_required(VERSION 3.16)
project(AgoojiyeHMI LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)

qt_standard_project_setup()

qt_add_executable(agoojiye-hmi
    main.cpp
)

set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/AppState.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(agoojiye-hmi
    URI AgoojiyeHMI
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/AppState.qml
        qml/components/Icon.qml
        qml/components/StatusBar.qml
        qml/components/BottomNav.qml
        qml/components/SidebarItem.qml
        qml/components/ToggleSwitch.qml
        qml/components/SegmentedControl.qml
        qml/components/PanelCard.qml
        qml/components/MenuTile.qml
        qml/components/ImageAsset.qml
        qml/components/Divider.qml
        qml/components/Glow.qml
        qml/components/BatteryArc.qml
        qml/components/Vignette.qml
        qml/screens/AccueilScreen.qml
        qml/screens/DashboardScreen.qml
        qml/screens/MenuScreen.qml
        qml/screens/VehiculeScreen.qml
        qml/screens/NavigationScreen.qml
        qml/screens/MediaScreen.qml
        qml/screens/MediaNowScreen.qml
        qml/screens/AdasScreen.qml
        qml/screens/ConduiteScreen.qml
        qml/screens/PhoneScreen.qml
        qml/screens/EntretienScreen.qml
        qml/screens/SettingsScreen.qml
        qml/Icons.js
    RESOURCES
        assets/fonts/phosphor/Phosphor-Regular.ttf
        assets/fonts/phosphor/Phosphor-Fill.ttf
        assets/fonts/inter/Inter-Regular.otf
        assets/fonts/inter/Inter-Medium.otf
        assets/fonts/inter/Inter-SemiBold.otf
        assets/fonts/inter/Inter-Bold.otf
        assets/images/hero-car.png
        assets/images/dash-road.png
        assets/images/vehicule-car.png
        assets/images/nav-map.jpg
        assets/images/album-blue.jpg
        assets/images/album-purple.jpg
        assets/images/adas-road.png
        assets/images/conduite-car.png
        assets/images/avatar-alice.jpg
        assets/images/settings-car.png
)

target_link_libraries(agoojiye-hmi
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
)

include(GNUInstallDirs)
install(TARGETS agoojiye-hmi
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
