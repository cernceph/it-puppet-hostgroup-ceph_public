class hg_ceph_beesly::osd {

  Exec { path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ] }

  include hg_ceph_beesly::include::ceph_conf
  include hg_ceph_beesly::include::secrets

  # get all disks that are not journals
  $journals = unique(values(hiera("${::boardproductname}_journals")))
  $disks_external = split($::disks_external, ',')
  $disks = delete_undef_values(difference($disks_external, $journals))

  firewall {'100 allow ceph osd access from the universe.':
    proto       => 'tcp',
    dport       => ['6800-7100'],
    action      => 'accept'
  }
  ->
  teigi::secret{ 'keyring':
    path => "/etc/ceph/keyring",
    require => Class['hg_ceph_beesly::include::ceph_conf'],
  }
  ->
  teigi::secret{ 'keyring.bootstrap-osd':
    path => "/var/lib/ceph/bootstrap-osd/ceph.keyring",
  }
  ->
  class { 'ceph::osd':
    public_address   => $::ipaddress,
    cluster_address  => $::ipaddress,
    require          => Class['ceph::conf']
  }
  ->
  hg_ceph_beesly::create_osd { $disks: }

  # make the OSDs less likely to get into swap (which might cause short OSD freezes)
  sysctl { "vm.swappiness": val => "10", }
  sysctl { "vm.min_free_kbytes": val => "524288", }
  sysctl { "net.ipv4.tcp_slow_start_after_idle": val => "0", }

  file { '/etc/tune-profiles/ceph-osd':
    ensure => directory
  }
  ->
  file { '/etc/tune-profiles/ceph-osd/ktune.sh':
    ensure => file,
    owner  => root, group => root, mode => 755,
    source => 'puppet:///modules/hg_ceph_beesly/tune-profiles/ceph-osd/ktune.sh',
  }
  ->
  file { '/etc/tune-profiles/ceph-osd/ktune.sysconfig':
    ensure => file,
    owner  => root, group => root, mode => 644,
    source => 'puppet:///modules/hg_ceph_beesly/tune-profiles/ceph-osd/ktune.sysconfig',
  }
  ->
  file { '/etc/tune-profiles/ceph-osd/sysctl.ktune':
    ensure => file,
    owner  => root, group => root, mode => 644,
    source => 'puppet:///modules/hg_ceph_beesly/tune-profiles/ceph-osd/sysctl.ktune',
  }
  ->
  file { '/etc/tune-profiles/ceph-osd/tuned.conf':
    ensure => file,
    owner  => root, group => root, mode => 644,
    source => 'puppet:///modules/hg_ceph_beesly/tune-profiles/ceph-osd/tuned.conf',
  }

  file { '/etc/selinux/fixfiles_exclude_dirs':
    ensure  => file,
    mode    => 644,
    content => "/var/lib/ceph\n"
  }
}
