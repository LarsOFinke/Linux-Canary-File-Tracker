CC ?= cc
CPPFLAGS ?= -Isrc/actions -Isrc/config -Isrc/events -Isrc/monitoring -Isrc/output -Isrc/process
CFLAGS ?= -std=gnu11 -O2 -Wall -Wextra -Wpedantic
LDFLAGS ?=

BUILD_DIR := dist
TARGET := $(BUILD_DIR)/fs-tracker
SOURCES := \
	src/app/main.c \
	src/actions/action.c \
	src/config/config.c \
	src/events/event_names.c \
	src/monitoring/fanotify_source.c \
	src/output/jsonl_sink.c \
	src/process/proc_info.c
.PHONY: all clean test format

all: $(TARGET)

$(TARGET): $(SOURCES)
	mkdir -p $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $(SOURCES) -o $@

test:
	test_dir=$$(mktemp -d); \
	trap 'rm -rf "$$test_dir"' EXIT INT TERM; \
	$(CC) $(CPPFLAGS) $(CFLAGS) tests/test_event_names.c src/events/event_names.c -o "$$test_dir/test_event_names" && \
	"$$test_dir/test_event_names" && \
	$(CC) $(CPPFLAGS) $(CFLAGS) tests/test_config.c src/config/config.c -o "$$test_dir/test_config" && \
	"$$test_dir/test_config" && \
	$(CC) $(CPPFLAGS) $(CFLAGS) tests/test_jsonl_sink.c src/output/jsonl_sink.c src/events/event_names.c src/process/proc_info.c -o "$$test_dir/test_jsonl_sink" && \
	"$$test_dir/test_jsonl_sink"

format:
	clang-format -i src/*/*.c src/*/*.h tests/*.c

clean:
	rm -rf $(BUILD_DIR)
