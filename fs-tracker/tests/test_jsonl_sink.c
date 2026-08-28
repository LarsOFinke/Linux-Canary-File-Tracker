#define _GNU_SOURCE
#include "fstracker/jsonl_sink.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(void)
{
    char target_template[] = "/tmp/fs-tracker-target-XXXXXX";
    int target_fd = mkstemp(target_template);
    assert(target_fd >= 0);
    close(target_fd);

    char log_template[] = "/tmp/fs-tracker-log-XXXXXX";
    int log_fd = mkstemp(log_template);
    assert(log_fd >= 0);
    close(log_fd);

    assert(unlink(log_template) == 0);
    assert(link(target_template, log_template) == 0);

    JsonlSink sink;
    char err[256] = {0};
    assert(jsonl_sink_open(&sink, log_template, target_template, err, sizeof(err)) < 0);
    assert(sink.file == NULL);
    assert(strstr(err, "watched target") != NULL);

    assert(unlink(log_template) == 0);
    assert(unlink(target_template) == 0);
    return 0;
}
