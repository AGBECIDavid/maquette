cmake_minimum_required(VERSION 3.16)
project(AgoojiyeHMI LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Network)

# Construction de PRODUCTION : -DAGOOJIYE_PRODUCTION=ON.
#
# Par défaut, le programme est une maquette de démonstration : le simulateur
# alimente l'état véhicule, et les outils de recette (HMI_VOICE, HMI_NAV,
# HMI_FAULT, HMI_ASSISTANT « @set: »…) répondent aux variables
# d'environnement. Rien de cela n'a sa place dans un véhicule : ces outils
# écrivent dans l'état affiché au conducteur.
#
# En production, ils ne sont pas désactivés mais ABSENTS du binaire, et le
# simulateur ne démarre pas. Une variable d'environnement oubliée ne peut
# alors rien changer.
option(AGOOJIYE_PRODUCTION "Binaire embarqué : sans simulateur ni outils de recette" OFF)
if(AGOOJIYE_PRODUCTION)
    message(STATUS "Construction de PRODUCTION : simulateur et outils de recette absents.")
else()
    message(STATUS "Construction de DÉMONSTRATION : simulateur actif, outils de recette présents. "
                   "Pour le véhicule : -DAGOOJIYE_PRODUCTION=ON")
endif()

# Micro : optionnel. Sans Qt Multimedia, l'assistant reste utilisable au
# clavier (Paramètres → Assistant vocal) et tout le reste est identique.
# -DAGOOJIYE_MIC=OFF s'en passe même s'il est installé (cible sans micro).
option(AGOOJIYE_MIC "Micro de l'assistant vocal (Qt Multimedia)" ON)
if(AGOOJIYE_MIC)
    find_package(Qt6 QUIET COMPONENTS Multimedia)
endif()
if(Qt6Multimedia_FOUND)
    message(STATUS "Qt Multimedia trouvé : le micro de l'assistant est disponible.")
elseif(NOT AGOOJIYE_MIC)
    message(STATUS "Micro désactivé (AGOOJIYE_MIC=OFF) : l'assistant reste au clavier.")
else()
    # Le remède dépend de la provenance de Qt : un paquet système ne sert à rien
    # à un Qt de l'installeur officiel, et inversement. On nomme donc le Qt
    # réellement utilisé.
    get_filename_component(_qt_root "${Qt6_DIR}/../../.." ABSOLUTE)
    if(_qt_root MATCHES "^/usr")
        set(_qt_fix "sudo apt install qt6-multimedia-dev")
    else()
        set(_qt_fix "ajoutez le module « Qt Multimedia » à ce Qt par son "
                    "Maintenance Tool (Add or remove components → Additional Libraries)")
    endif()
    message(STATUS "Qt Multimedia absent de ${_qt_root} : pas de micro, l'assistant "
                   "reste au clavier. Pour le micro : ${_qt_fix}, puis ./run.sh --clean")
endif()

# Synthèse vocale : optionnelle, et doublée d'un repli. Sans rien du tout,
# l'application se construit et tourne à l'identique — l'assistant reste
# affiché, il ne parle simplement pas.
#
# Attention : trouver le module ne suffit pas à faire du son. Il faut aussi son
# plugin de sortie (qt6-speech-speechd-plugin), qui manque souvent. C'est
# pourquoi VoiceAnnouncer sait aussi passer par `spd-say`.
find_package(Qt6 QUIET COMPONENTS TextToSpeech)
if(Qt6TextToSpeech_FOUND)
    message(STATUS "Qt TextToSpeech trouvé. S'il reste muet, le plugin de sortie "
                   "manque : installer qt6-speech-speechd-plugin.")
else()
    message(STATUS "Qt TextToSpeech absent : l'assistant passera par `spd-say` "
                   "s'il est installé (paquet speech-dispatcher).")
endif()

qt_standard_project_setup()

qt_add_executable(agoojiye-hmi
    main.cpp
    localurl.h
    voiceannouncer.h
    voiceannouncer.cpp
    voicelistener.h
    voicelistener.cpp
    mapdata.h
    mapdata.cpp
    navigation.h
    navigation.cpp
    mapview.h
    mapview.cpp
)

set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/AppState.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/VehicleData.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/VehicleSimulator.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/VoiceCommands.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/Assistant.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(agoojiye-hmi
    URI AgoojiyeHMI
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/AppState.qml
        qml/VehicleData.qml
        qml/VehicleSimulator.qml
        qml/VoiceCommands.qml
        qml/Assistant.qml
        qml/components/Icon.qml
        qml/components/AlertBanner.qml
        qml/components/StatusBar.qml
        qml/components/BottomNav.qml
        qml/components/SidebarItem.qml
        qml/components/ToggleSwitch.qml
        qml/components/SegmentedControl.qml
        qml/components/PanelCard.qml
        qml/components/MenuTile.qml
        qml/components/SettingRow.qml
        qml/components/StatTile.qml
        qml/components/LevelBar.qml
        qml/components/ImageAsset.qml
        qml/components/Divider.qml
        qml/components/Glow.qml
        qml/components/BatteryArc.qml
        qml/components/Vignette.qml
        qml/components/VoiceConsole.qml
        qml/components/AssistantBubble.qml
        qml/components/NavPlaceList.qml
        qml/components/NavRoutePanel.qml
        qml/components/NavGuidancePanel.qml
        qml/components/NavStepList.qml
        qml/screens/BootScreen.qml
        qml/screens/HvDiagnosticScreen.qml
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
        assets/images/dash-road.png
        assets/images/boot-shuttle.png
        assets/images/vehicule-car.png
        assets/images/album-blue.jpg
        assets/images/album-purple.jpg
        assets/images/adas-road.png
        assets/images/conduite-car.png
        assets/images/avatar-alice.jpg
        assets/images/settings-car.png
        map/gdiz.map.json
)

target_link_libraries(agoojiye-hmi
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
        Qt6::Network
)

if(AGOOJIYE_PRODUCTION)
    target_compile_definitions(agoojiye-hmi PRIVATE AGOOJIYE_PRODUCTION)
endif()

# Avertissements : le code du projet se compile sans aucun, et doit le rester.
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    set_source_files_properties(
        main.cpp mapdata.cpp navigation.cpp mapview.cpp voiceannouncer.cpp voicelistener.cpp
        PROPERTIES COMPILE_OPTIONS "-Wall;-Wextra")
endif()

if(Qt6Multimedia_FOUND)
    target_link_libraries(agoojiye-hmi PRIVATE Qt6::Multimedia)
    target_compile_definitions(agoojiye-hmi PRIVATE AGOOJIYE_HAS_MIC)
endif()

if(Qt6TextToSpeech_FOUND)
    target_link_libraries(agoojiye-hmi PRIVATE Qt6::TextToSpeech)
    target_compile_definitions(agoojiye-hmi PRIVATE AGOOJIYE_HAS_TTS)
endif()

# Tests unitaires : ctest --test-dir build --output-on-failure (./test.sh les
# lance). Optionnels — sans Qt Test, l'application se construit à l'identique.
option(AGOOJIYE_TESTS "Tests unitaires (Qt Test)" ON)
if(AGOOJIYE_TESTS)
    find_package(Qt6 QUIET COMPONENTS Test)
    if(Qt6Test_FOUND)
        enable_testing()
        qt_add_executable(tst_mapdata tests/tst_mapdata.cpp mapdata.h mapdata.cpp)
        target_include_directories(tst_mapdata PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
        target_compile_definitions(tst_mapdata PRIVATE
            MAP_FILE="${CMAKE_CURRENT_SOURCE_DIR}/map/gdiz.map.json")
        target_compile_options(tst_mapdata PRIVATE -Wall -Wextra)
        target_link_libraries(tst_mapdata PRIVATE Qt6::Core Qt6::Gui Qt6::Test)
        add_test(NAME mapdata COMMAND tst_mapdata)
        set_tests_properties(mapdata PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
    else()
        message(STATUS "Qt Test absent : pas de tests unitaires (sudo apt install qt6-base-dev).")
    endif()
endif()

include(GNUInstallDirs)
install(TARGETS agoojiye-hmi
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
