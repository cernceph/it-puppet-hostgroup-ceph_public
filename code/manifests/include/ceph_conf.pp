class hg_ceph_beesly::include::ceph_conf {

  $loc = regsubst($::landb_location, ' ', '-', 'G')
  $crush_root = hiera('crush_root', '')
  $crush_use_ipservice = hiera('crush_use_ipservice', false)
  if $crush_root != '' {
    if $crush_use_ipservice {
      $osd_crush_location = "root=${crush_root} room=${loc}-${crush_root} ipservice=${::landb_service_name} rack=${::landb_rackname}-${crush_root} host=${::hostname}-${crush_root}"
    } else {
      $osd_crush_location = "root=${crush_root} room=${loc}-${crush_root} rack=${::landb_rackname}-${crush_root} host=${::hostname}-${crush_root}"
    }
  } else {
    if $crush_use_ipservice {
      $osd_crush_location = "room=${loc} ipservice=${::landb_service_name} rack=${::landb_rackname} host=${::hostname}"
    } else {
      $osd_crush_location = "room=${loc} rack=${::landb_rackname} host=${::hostname}"
    }
  }

  class { 'ceph::conf':
    fsid                      => hiera('ceph_fsid'),
    auth_type                 => 'cephx',
    journal_size_mb           => 20480,
    mon_osd_down_out_interval => 900,
    osd_pool_default_size     => 3,
    osd_crush_location        => $osd_crush_location,
  }

  augeas{'6_month_ceph_logs':
     changes => [
       "set /files/etc/logrotate.d/ceph/rule/rotate 183",
       "set /files/etc/logrotate.d/ceph/rule/ifempty notifempty",
     ],
     require => Package['ceph']
  }
}
