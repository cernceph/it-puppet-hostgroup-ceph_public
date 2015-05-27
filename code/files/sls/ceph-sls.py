#!/usr/bin/env python
#
# ceph-sls.py
#
# Produce an XML file reporting the service level status of Ceph
#
# Author: Dan van der Ster (daniel.vanderster@cern.ch)
#

import commands
import cephinfo
import math

def get_availability():
  health = commands.getoutput('timeout 10 ceph health')
  if health == 'HEALTH_OK':
    return 100

  n_pgs = cephinfo.get_n_pgs()
  pg_states = cephinfo.get_pg_states()
  a_pgs = math.floor(100.0 * pg_states['active'] / n_pgs)

  n_mons = cephinfo.get_n_mons()
  n_quorum = cephinfo.get_n_mons_quorum()
  a_mon = 1 if n_quorum >= math.ceil( n_mons / 2 ) else 0

  availability = int(a_mon * a_pgs)
  return availability


def write_xml():
  osd_states = cephinfo.get_osd_states()
  osd_stats_sum = cephinfo.get_osd_stats_sum()
  pg_stats_sum = cephinfo.get_pg_stats_sum()['stat_sum']
  pg_map = cephinfo.stat_data['pgmap']
  latency = cephinfo.get_write_latency()
  pg_states = cephinfo.get_pg_states()
  read_latency = cephinfo.get_read_latency()
  cephinfo.rados_cleanup(latency[0])
  activity = cephinfo.get_smooth_activity(10)
  context = {
    "timestamp"          : commands.getoutput('date +%Y-%m-%dT%H:%M:%S'),
    "availability"       : get_availability(),
    "n_mons"             : cephinfo.get_n_mons(),
    "n_quorum"           : cephinfo.get_n_mons_quorum(),
    "n_pools"            : cephinfo.get_n_pools(),
    "n_osds"             : cephinfo.get_n_osds(),
    "n_osds_up"          : osd_states['up'],
    "n_osds_in"          : osd_states['in'],
    "n_pgs"              : cephinfo.get_n_pgs(),
    "n_pgs_active"       : pg_states['active'],
    "n_pgs_scrubbing"    : pg_states['scrubbing'],
    "n_pgs_deep"         : pg_states['deep'],
    "n_osd_gb_total"     : osd_stats_sum['kb'] / 1024 / 1024,
    "n_osd_gb_used"      : osd_stats_sum['kb_used'] / 1024 / 1024,
    "n_osd_gb_avail"     : osd_stats_sum['kb_avail'] / 1024 / 1024,
    "n_pg_gbytes"        : pg_stats_sum['num_bytes'] / 1024 / 1024 / 1024,
    "n_objects"          : pg_stats_sum['num_objects'],
    "n_object_copies"    : pg_stats_sum['num_object_copies'],
    "n_objects_degraded" : pg_stats_sum['num_objects_degraded'],
    "n_objects_unfound"  : pg_stats_sum['num_objects_unfound'],
    "n_read_gb"          : pg_stats_sum['num_read_kb'] / 1024 / 1024,
    "n_write_gb"         : pg_stats_sum['num_write_kb'] / 1024 / 1024,
    "latency_ms"         : latency[1][0]*1000,
    "latency_max_ms"     : latency[1][1]*1000,
    "latency_min_ms"     : latency[1][2]*1000,
    "read_latency_ms"    : read_latency[0]*1000,
    "read_latency_max_ms": read_latency[1]*1000,
    "read_latency_min_ms": read_latency[2]*1000,
    "n_openstack_volumes": cephinfo.get_n_openstack_volumes(),
    "n_openstack_images" : cephinfo.get_n_openstack_images(),
    "op_per_sec"         : activity[0],
    "read_mb_sec"        : activity[1],
    "write_mb_sec"       : activity[2],
  } 
  template = """<?xml version="1.0" encoding="utf-8"?>

<serviceupdate xmlns="http://sls.cern.ch/SLS/XML/update">
   
        <id>Ceph</id>
        <fullname>Ceph Production Storage Service</fullname>
        <group>IT/DSS</group>

        <contact>ceph.support\@cern.ch</contact>
        <webpage>https://twiki.cern.ch/twiki/bin/viewauth/DSSGroup/CephProject</webpage>
        <alarmpage>http://cern.ch/ceph/alarms.html</alarmpage>
 
        <timestamp>{timestamp}</timestamp>
 
        <availability>{availability}</availability>
 
        <refreshperiod>PT15M</refreshperiod>
 
        <availabilitythresholds>
                <threshold level="available">98</threshold>
                <threshold level="affected">90</threshold>
                <threshold level="degraded">80</threshold>
        </availabilitythresholds>

        <data>
                <grp name="Monitors">
		    <numericvalue name="n_mons" desc="Num Mons">{n_mons}</numericvalue>
		    <numericvalue name="n_quorum" desc="Num Mons in Quorum">{n_quorum}</numericvalue>
                </grp>
		<numericvalue name="n_pools" desc="Num Pools">{n_pools}</numericvalue>
                <grp name="OSDs">
		    <numericvalue name="n_osds" desc="Num OSDs">{n_osds}</numericvalue>
		    <numericvalue name="n_osds_up" desc="Num OSDs Up">{n_osds_up}</numericvalue>
		    <numericvalue name="n_osds_in" desc="Num OSDs In">{n_osds_in}</numericvalue>
                </grp>
                <grp name="PGs">
		    <numericvalue name="n_pgs" desc="Num PGs">{n_pgs}</numericvalue>
		    <numericvalue name="n_pgs_active" desc="Num PGs Active">{n_pgs_active}</numericvalue>
		    <numericvalue name="n_pgs_scrubbing" desc="Num PGs Scrubbing">{n_pgs_scrubbing}</numericvalue>
		    <numericvalue name="n_pgs_deep" desc="Num PGs Deep Scrubbing">{n_pgs_deep}</numericvalue>
                </grp>
                <grp name="Disk Space">
		    <numericvalue name="n_osd_gb_total" desc="OSD Gigabytes Total">{n_osd_gb_total}</numericvalue>
		    <numericvalue name="n_osd_gb_used" desc="OSD Gigabytes Used">{n_osd_gb_used}</numericvalue>
		    <numericvalue name="n_osd_gb_avail" desc="OSD Gigabytes Avail">{n_osd_gb_avail}</numericvalue>
		    <numericvalue name="n_pg_gbytes" desc="PG Gigabytes">{n_pg_gbytes}</numericvalue>
                </grp>
                <grp name="Objects">
		    <numericvalue name="n_objects" desc="Num Objects">{n_objects}</numericvalue>
		    <numericvalue name="n_object_copies" desc="Num Object Copies">{n_object_copies}</numericvalue>
		    <numericvalue name="n_objects_degraded" desc="Num Objects Degraded">{n_objects_degraded}</numericvalue>
		    <numericvalue name="n_objects_unfound" desc="Num Objects Unfound">{n_objects_unfound}</numericvalue>
                </grp>
                <grp name="Total RW">
		    <numericvalue name="n_read_gb" desc="Total Read (GB)">{n_read_gb}</numericvalue>
		    <numericvalue name="n_write_gb" desc="Total Write (GB)">{n_write_gb}</numericvalue>
                </grp>
                <grp name="4KB Write Latency (ms)">
		    <numericvalue name="latency_ms" desc="Average">{latency_ms}</numericvalue>
		    <numericvalue name="latency_max_ms" desc="Max">{latency_max_ms}</numericvalue>
		    <numericvalue name="latency_min_ms" desc="Min">{latency_min_ms}</numericvalue>
                </grp>
                <grp name="4KB Read Latency (ms)">
		    <numericvalue name="read_latency_ms" desc="Average">{read_latency_ms}</numericvalue>
		    <numericvalue name="read_latency_max_ms" desc="Max">{read_latency_max_ms}</numericvalue>
		    <numericvalue name="read_latency_min_ms" desc="Min">{read_latency_min_ms}</numericvalue>
                </grp>
                <grp name="OpenStack">
		    <numericvalue name="n_openstack_volumes" desc="Num OpenStack Volumes">{n_openstack_volumes}</numericvalue>
		    <numericvalue name="n_openstack_images" desc="Num OpenStack Images">{n_openstack_images}</numericvalue>
                </grp>
                <grp name="Throughput">
		    <numericvalue name="read_mb_sec" desc="Read MB/s">{read_mb_sec}</numericvalue>
		    <numericvalue name="write_mb_sec" desc="Write MB/s">{write_mb_sec}</numericvalue>
                </grp>
		<numericvalue name="op_per_sec" desc="Operations Per Second">{op_per_sec}</numericvalue>
	</data>

        <lemon>
                <cluster>ceph_dwight_mon</cluster>
                <cluster>ceph_dwight_osd</cluster>
        </lemon>

	<servicemanagers>
		<servicemanager email="daniel.vanderster@cern.ch" login="dvanders" main="true">Dan van der Ster</servicemanager>
	</servicemanagers>

</serviceupdate>"""
  print template.format(**context)
#  with open('ceph-sls.xml','w') as myfile:
#    myfile.write(template.format(**context))

cephinfo.get_json()
write_xml()
