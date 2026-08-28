#ifndef FSTRACKER_PROC_INFO_H
#define FSTRACKER_PROC_INFO_H

#include <linux/limits.h>
#include <stddef.h>
#include <sys/types.h>

typedef struct {
    pid_t pid;
    pid_t ppid;
    uid_t uid;
    char exe[PATH_MAX];
    char cmdline[4096];
} ProcessInfo;

int process_info_read(pid_t pid, ProcessInfo *info);

#endif
