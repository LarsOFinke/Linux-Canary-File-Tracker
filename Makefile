CC ?= cc
CPPFLAGS ?= -Isrc/config -Isrc/events -Isrc/monitoring -Isrc/output -Isrc/process
CFLAGS ?= -std=gnu11 -O2 -Wall -Wextra -Wpedantic
LDFLAGS ?=

BUILD_DIR := dist
TARGET := $(BUILD_DIR)/fs-tracker
SOURCES := \
	src/app/main.c \
	src/config/config.c \
	src/events/event_names.c \
	src/monitoring/fanotify_source.c \
	src/output/jsonl_sink.c \
	src/process/proc_info.c
OBJECTS := $(SOURCES:%.c=$(BUILD_DIR)/%.o)

TEST_TARGETS := $(BUILD_DIR)/test_event_names $(BUILD_DIR)/test_config $(BUILD_DIR)/test_jsonl_sink

.PHONY: all clean test format

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(LDFLAGS) -o $@ $(OBJECTS)

$(BUILD_DIR)/%.o: %.c
	mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/test_event_names: tests/test_event_names.c src/events/event_names.c
	mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) $^ -o $@

$(BUILD_DIR)/test_config: tests/test_config.c src/config/config.c
	mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) $^ -o $@

$(BUILD_DIR)/test_jsonl_sink: tests/test_jsonl_sink.c src/output/jsonl_sink.c src/events/event_names.c src/process/proc_info.c
	mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) $^ -o $@

test: $(TEST_TARGETS)
	./$(BUILD_DIR)/test_event_names
	./$(BUILD_DIR)/test_config
	./$(BUILD_DIR)/test_jsonl_sink

format:
	clang-format -i src/*/*.c src/*/*.h tests/*.c

clean:
	rm -rf $(BUILD_DIR)
