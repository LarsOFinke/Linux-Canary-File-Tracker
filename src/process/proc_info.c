#define _GNU_SOURCE
#include "proc_info.h"

#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static void process_info_reset(ProcessInfo *info, pid_t pid)
{
    memset(info, 0, sizeof(*info));
    info->pid = pid;
    info->ppid = -1;
    info->uid = (uid_t)-1;
}

static void read_status(ProcessInfo *info)
{
    char path[64];
    snprintf(path, sizeof(path), "/proc/%d/status", info->pid);

    FILE *file = fopen(path, "r");
    if (!file)
        return;

    char line[512];
    while (fgets(line, sizeof(line), file)) {
        unsigned uid;
        int ppid;

        if (sscanf(line, "Uid:%u", &uid) == 1)
            info->uid = (uid_t)uid;
        else if (sscanf(line, "PPid:%d", &ppid) == 1)
            info->ppid = (pid_t)ppid;
    }

    fclose(file);
}

static void read_exe(ProcessInfo *info)
{
    char path[64];
    snprintf(path, sizeof(path), "/proc/%d/exe", info->pid);

    ssize_t n = readlink(path, info->exe, sizeof(info->exe) - 1);
    if (n >= 0)
        info->exe[n] = '\0';
}

static void read_cmdline(ProcessInfo *info)
{
    char path[64];
    snprintf(path, sizeof(path), "/proc/%d/cmdline", info->pid);

    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0)
        return;

    ssize_t n = read(fd, info->cmdline, sizeof(info->cmdline) - 1);
    close(fd);

    if (n <= 0)
        return;

    info->cmdline[n] = '\0';
    for (ssize_t i = 0; i < n - 1; i++) {
        if (info->cmdline[i] == '\0')
            info->cmdline[i] = ' ';
    }
}

int process_info_read(pid_t pid, ProcessInfo *info)
{
    process_info_reset(info, pid);

    if (pid <= 0)
        return -1;

    read_status(info);
    read_exe(info);
    read_cmdline(info);

    return info->exe[0] || info->cmdline[0] || info->ppid >= 0 ? 0 : -1;
}
