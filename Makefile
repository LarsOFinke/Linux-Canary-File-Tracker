CC ?= cc
CPPFLAGS ?= -Isrc/actions -Isrc/config -Isrc/events -Isrc/monitoring -Isrc/output -Isrc/process
CFLAGS ?= -std=gnu11 -O2 -Wall -Wextra -Wpedantic
LDFLAGS ?=
PYTHON ?= python3
VENV_DIR := .venv
BUILD_DIR := dist
TARGET := $(BUILD_DIR)/fs-tracker
MAILER_NAME := canary-mailer
MAILER_TARGET := $(BUILD_DIR)/$(MAILER_NAME)
MAILER_DIR := tools/canary-mailer
MAILER_SPEC := $(MAILER_DIR)/canary-mailer.spec
MAILER_APP := $(MAILER_DIR)/app.py
SOURCES := \
	src/app/main.c \
	src/actions/action.c \
	src/config/config.c \
	src/events/event_names.c \
	src/monitoring/fanotify_source.c \
	src/output/jsonl_sink.c \
	src/process/proc_info.c
.PHONY: all clean test format mailer

all: $(TARGET) $(MAILER_TARGET)

$(TARGET): $(SOURCES)
	mkdir -p $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) $(SOURCES) -o $@

$(MAILER_TARGET): $(MAILER_APP) $(MAILER_SPEC) $(MAILER_DIR)/requirements.txt
	mkdir -p $(BUILD_DIR)
	test -d "$(VENV_DIR)" || $(PYTHON) -m venv "$(VENV_DIR)"
	. "$(VENV_DIR)/bin/activate" && python -m pip install --upgrade pip >/dev/null && \
	python -m pip install -r "$(MAILER_DIR)/requirements.txt" >/dev/null && \
	pyinstaller --clean --noconfirm "$(MAILER_SPEC)"

mailer: $(MAILER_TARGET)

test:
	test_dir=$$(mktemp -d); \
	trap 'rm -rf "$$test_dir"' EXIT INT TERM; \
	$(CC) $(CPPFLAGS) $(CFLAGS) tests/test_event_names.c src/events/event_names.c -o "$$test_dir/test_event_names" && \
	"$$test_dir/test_event_names" && \
	$(CC) $(CPPFLAGS) $(CFLAGS) tests/test_config.c src/config/config.c -o "$$test_dir/test_config" && \
	"$$test_dir/test_config" && \
	$(CC) $(CPPFLAGS) $(CFLAGS) tests/test_jsonl_sink.c src/output/jsonl_sink.c src/events/event_names.c src/process/proc_info.c -o "$$test_dir/test_jsonl_sink" && \
	"$$test_dir/test_jsonl_sink" && \
	. "$(VENV_DIR)/bin/activate" && python -m unittest tests/test_canary_mailer.py

format:
	clang-format -i src/*/*.c src/*/*.h tests/*.c

clean:
	rm -rf $(BUILD_DIR)
	rm -f canary-mailer.spec
