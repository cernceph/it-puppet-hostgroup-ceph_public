#!/bin/sh

. /etc/tune-profiles/functions

start() {
    set_cpu_governor performance
    /usr/libexec/tuned/pmqos-static.py cpu_dma_latency=1
    set_transparent_hugepages never
	# multiply_disk_readahead 4
    #for f in /sys/block/sd*/queue/iosched/write_expire; do echo 500 > $f; done
    #for f in /sys/block/sd*/queue/iosched/writes_starved; do echo 1 > $f; done
    #for f in /sys/block/sd*/queue/iosched/front_merges; do echo 0 > $f; done

    return 0
}

stop() {
    restore_cpu_governor
    /usr/libexec/tuned/pmqos-static.py disable
    restore_transparent_hugepages
    # restore_disk_readahead

	return 0
}

process $@
