set(MAP_TEST_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/map_spectators_test.cpp
)

otclient_add_gtest(otclient_map_spectator_tests ${MAP_TEST_SOURCES})
