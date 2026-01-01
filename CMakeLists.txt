cmake_minimum_required(VERSION 3.16)

project(AsusTufFanControl_Linux VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find Qt6 (or Qt5) packages
find_package(Qt6 6.2 REQUIRED COMPONENTS Quick Core Gui)

# Automate Qt meta-object compilation
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# i18n: Find Qt Linguist Tools (Optional)
find_package(Qt6 COMPONENTS LinguistTools)

# i18n: Auto-patch translations (Run python script to inject missing keys)
find_package(Python3 COMPONENTS Interpreter)
if(Python3_FOUND)
    message(STATUS "Running patch_translations.py to update translation files...")
    execute_process(COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/patch_translations.py
                    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
else()
    message(WARNING "Python3 not found. Translations might be incomplete.")
endif()

# i18n: Define Translation Files (22 languages)
set(TS_FILES
    translations/AsusTufFanControl_ta.ts  # Tamil
    translations/AsusTufFanControl_es.ts  # Spanish
    translations/AsusTufFanControl_fr.ts  # French
    translations/AsusTufFanControl_de.ts  # German
    translations/AsusTufFanControl_zh.ts  # Chinese
    translations/AsusTufFanControl_ja.ts  # Japanese
    translations/AsusTufFanControl_ru.ts  # Russian
    translations/AsusTufFanControl_pt.ts  # Portuguese
    translations/AsusTufFanControl_ko.ts  # Korean
    translations/AsusTufFanControl_it.ts  # Italian
    translations/AsusTufFanControl_ar.ts  # Arabic
    translations/AsusTufFanControl_bn.ts  # Bengali
    translations/AsusTufFanControl_tr.ts  # Turkish
    translations/AsusTufFanControl_id.ts  # Indonesian
    translations/AsusTufFanControl_vi.ts  # Vietnamese
    translations/AsusTufFanControl_pl.ts  # Polish
    translations/AsusTufFanControl_ur.ts  # Urdu
    translations/AsusTufFanControl_pa.ts  # Punjabi
    translations/AsusTufFanControl_fa.ts  # Persian/Farsi
    translations/AsusTufFanControl_sw.ts  # Swahili
    translations/AsusTufFanControl_mr.ts  # Marathi
    translations/AsusTufFanControl_hi.ts  # Hindi
)

# i18n: Create Translation Targets
if(Qt6LinguistTools_FOUND)
    qt6_add_translation(QM_FILES ${TS_FILES})
else()
    message(WARNING "Qt6 LinguistTools not found. Translations will not be updated automatically.")
    set(QM_FILES)
endif()

# Source files
set(PROJECT_SOURCES
        main.cpp
        src/FanController.cpp
        src/FanController.h
        src/SystemStatsMonitor.cpp
        src/SystemStatsMonitor.h
        src/MtpWorker.cpp
        src/MtpWorker.h
        src/AuraController.cpp
        src/AuraController.h
        src/FanCurveController.cpp
        src/FanCurveController.h
        resources.qrc
)

# Create the executable FIRST
add_executable(AsusTufFanControl_Linux ${PROJECT_SOURCES})

# i18n: Embed Translations into Resource System AFTER target is defined
if(QM_FILES)
    # Generate a QRC file pointing to ALL compiled .qm files
    set(GENERATED_QRC "${CMAKE_BINARY_DIR}/translations.qrc")
    set(QRC_CONTENT "<!DOCTYPE RCC><RCC version=\"1.0\">\n    <qresource prefix=\"/translations\">\n")
    foreach(QM_FILE ${QM_FILES})
        get_filename_component(QM_NAME ${QM_FILE} NAME)
        string(APPEND QRC_CONTENT "        <file alias=\"${QM_NAME}\">${QM_FILE}</file>\n")
    endforeach()
    string(APPEND QRC_CONTENT "    </qresource>\n</RCC>\n")
    file(WRITE "${GENERATED_QRC}" "${QRC_CONTENT}")
    # Add the generated QRC to the target
    target_sources(AsusTufFanControl_Linux PRIVATE ${GENERATED_QRC})
endif()

# Link libraries
target_link_libraries(AsusTufFanControl_Linux
    PRIVATE Qt6::Quick Qt6::Core Qt6::Gui
)

# Ensure QM files are built before the main target
if(QM_FILES)
    add_custom_target(translations ALL DEPENDS ${QM_FILES})
    add_dependencies(AsusTufFanControl_Linux translations)
endif()