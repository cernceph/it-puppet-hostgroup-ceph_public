class hg_ceph_beesly {
  Exec { path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ] }

  ensure_packages( [ 'mosh', 'tmux', 'iperf3', 'perf', 'fio', 'iotop', 'iftop', 'iptraf', 'atop', 'dstat', 'bash-completion', 'telnet', 'wassh' ] )

  $ceph_release = hiera('ceph_release')

  osrepos::ai121yumrepo { 'cernceph':
    descr    => "CERN Ceph ${ceph_release} repository",
    baseurl  => "http://ceph.web.cern.ch/ceph/yum/${ceph_release}/el6/x86_64/",
    gpgcheck => 0,
    enabled  => 1,
    priority => 4,
  }

  osrepos::ai121yumrepo { 'cernceph-test':
    descr    => "CERN Ceph ${ceph_release} Test repository",
    baseurl  => "http://ceph.web.cern.ch/ceph/yum/${ceph_release}-test/el6/x86_64/",
    gpgcheck => 0,
    enabled  => 0,
    priority => 3,
  }

  firewall {'101 allow mosh access from the universe.':
    proto       => 'udp',
    dport       => ['60000-61000'],
    action      => 'accept'
  }

  sysctl { "net.netfilter.nf_conntrack_max": val => "1024000", }
  sysctl { "net.nf_conntrack_max": val => "1024000", }

  sysctl { "vm.vfs_cache_pressure": val => "100", } # explicit cache pressure
  sysctl { "vm.zone_reclaim_mode": val => "0", } # reclaim causes OSD freezes

  sysctl { 'net.core.somaxconn': val => "4096" }
  sysctl { 'net.core.netdev_max_backlog': val => "50000" }
  sysctl { 'net.ipv4.tcp_max_syn_backlog': val => "30000" }
  sysctl { 'net.ipv4.tcp_max_tw_buckets': val => "2000000" }
  sysctl { 'net.ipv4.tcp_fin_timeout': val => "10" }
  sysctl { 'net.ipv4.ip_local_port_range': val => "10000 65535" }

  lemon::metric{'10531':} # IO_error https://metricmgr.cern.ch/metric/10531/
  lemon::metric{'10532':} # FileSystem_error https://metricmgr.cern.ch/metric/10532/
  lemon::metric{'10533':} # UncorrectableError https://metricmgr.cern.ch/metric/10533/
  lemon::metric{'13049':} # SCSI_Medium_Error https://metricmgr.cern.ch/metric/13049/

  # exclude /var/lib/ceph from the updatedb cron
  file { '/etc/updatedb.conf':
    ensure => file,
    owner  => root, group => root, mode => 644,
    source => 'puppet:///modules/hg_ceph_beesly/updatedb.conf'
  }

  file { '/etc/profile.d/ceph_prompt.sh':
    ensure => file,
    owner  => root, group => root, mode => 644,
    source => 'puppet:///modules/hg_ceph_beesly/ceph_prompt.sh'
  }

  # Configure abrt module
  class { 'abrt':
    opengpgcheck        => 'no',
    maxcrashreportssize => '0',
    detailedmailsubject => 'true',
    blacklist           => ['nspluginwrapper', 'valgrind', 'strace', 'mono-core', 'lemon-agent', 'lemon-sensor', 'hwcollect', 'ceph-osd', 'xfs_db'],
    blacklistedpaths    => ['/usr/share/doc/*', '*/example*', '/usr/bin/nspluginviewer', '/usr/lib/xulrunner-*/plugin-container', '/usr/bin/hwcollect'],
    abrt_sosreport      => false
  }

  # The following will add SSH (the default port for allow_hosts) access from a hostgroup of hosts.
  #$beesly_hosts = query_nodes('(hostgroup_0="ceph_beesly")',  ipaddress)
  #::cernfw::allow_host{$beesly_hosts:}

  # allow ssh from dvanders-hpi5
  ::cernfw::allow_host{['137.138.34.33']:}

}
