cmake_minimum_required(VERSION 3.16)
project(fs_tracker C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)

add_library(fstracker_core
    src/config.c
    src/event_names.c
    src/fanotify_source.c
    src/jsonl_sink.c
    src/proc_info.c
)
target_include_directories(fstracker_core PUBLIC include)
target_compile_options(fstracker_core PRIVATE -Wall -Wextra -Wpedantic)

add_executable(fs-tracker src/main.c)
target_link_libraries(fs-tracker PRIVATE fstracker_core)
target_compile_options(fs-tracker PRIVATE -Wall -Wextra -Wpedantic)

enable_testing()
add_executable(test_event_names tests/test_event_names.c src/event_names.c)
target_include_directories(test_event_names PRIVATE include)
target_compile_options(test_event_names PRIVATE -Wall -Wextra -Wpedantic)
add_test(NAME event_names COMMAND test_event_names)

add_executable(test_config tests/test_config.c src/config.c)
target_include_directories(test_config PRIVATE include)
target_compile_options(test_config PRIVATE -Wall -Wextra -Wpedantic)
add_test(NAME config COMMAND test_config)

add_executable(test_jsonl_sink tests/test_jsonl_sink.c src/jsonl_sink.c src/event_names.c)
target_include_directories(test_jsonl_sink PRIVATE include)
target_compile_options(test_jsonl_sink PRIVATE -Wall -Wextra -Wpedantic)
add_test(NAME jsonl_sink COMMAND test_jsonl_sink)
