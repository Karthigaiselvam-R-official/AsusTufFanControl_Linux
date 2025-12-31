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

add_executable(AsusTufFanControl_Linux ${PROJECT_SOURCES})

# Link libraries
target_link_libraries(AsusTufFanControl_Linux
    PRIVATE Qt6::Quick Qt6::Core Qt6::Gui
)