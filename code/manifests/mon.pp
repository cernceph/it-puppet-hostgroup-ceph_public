class hg_ceph_beesly::mon {

  Exec { path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ] }

  include hg_ceph_beesly::include::repo
  include hg_ceph_beesly::include::ceph_conf
  include hg_ceph_beesly::include::secrets

  $id = hiera('mon_id')

  # client.admin keyring
  # the first monitor creates it (then you need to copy it to the repo!)
  # all the other monitors need to get it here
  if $id != 0 {
    teigi::secret{ 'keyring':
      path => '/etc/ceph/keyring',
      before => [ Exec['ceph-mon-mkfs'], Exec['ceph-admin-key'] ]
    }
  }

  # mon. key to bootstrap the monitors
  teigi::secret{ 'keyring.mon':
    path => "/var/lib/ceph/tmp/keyring.mon.${id}",
    before => [ Exec['ceph-mon-mkfs'], Exec['ceph-mon-keyring'] ]
  }

  ceph::mon { "${id}":
    monitor_secret => 'skip', # we don't pass a secret. it is copied above.
    mon_addr       => $::ipaddress, # The host's «public» IP address
  }

  firewall {'100 allow ceph mon access from the universe.':
    proto  => 'tcp',
    dport  => '6789',
    action => 'accept'
  }

  file { '/usr/bin/ceph-health-cron':
    ensure => file,
    owner  => root, group => root, mode => 755,
    source => 'puppet:///modules/hg_ceph_beesly/ceph-health-cron',
  }

  cron { 'ceph-health':
    command => "/usr/bin/ceph-health-cron 5 ${id} | mailx -E -s \"${::hostgroup_0} health warn for \"`date +\"\\%Y-\\%m-\\%d\"` ceph-admins@cern.ch",
    minute  => '59',
    hour    => '*',
    require => File['/usr/bin/ceph-health-cron']
  } 

  file { '/usr/local/bin/ceph-restart-mons':
    ensure => file,
    owner  => root, group => root, mode => 755,
    source => 'puppet:///modules/hg_ceph_beesly/ceph-restart-mons',
  }

  file { '/usr/local/bin/ceph-compact-mons':
    ensure => file,
    owner  => root, group => root, mode => 755,
    source => 'puppet:///modules/hg_ceph_beesly/ceph-compact-mons',
  }

  if $id == 4 {
#    cron { 'ceph-compact-mons':
#      command => "/usr/local/bin/ceph-compact-mons --doit",
#      minute  => '50',
#      hour    => '8',
#      weekday => ['Monday','Wednesday','Friday'],
#      require => File['/usr/local/bin/ceph-compact-mons']
#    }

    # SLS Probe
    file { '/usr/local/sbin/cephinfo.py':
      ensure => file,
      owner  => root,
      group  => root,
      mode   => '0755',
      source => 'puppet:///modules/hg_ceph_beesly/sls/cephinfo.py',
    } ->
    file { '/usr/local/sbin/ceph-sls.py':
      ensure  => file,
      owner   => root,
      group   => root,
      mode    => '0755',
      source  => 'puppet:///modules/hg_ceph_beesly/sls/ceph-sls.py',
    } ->
    cron { 'ceph-sls':
      #command => '/usr/local/sbin/ceph-sls.py | tee /var/tmp/ceph-sls.`date +%s`.xml | curl -o /dev/null -s -F file=@- xsls.cern.ch',
      command => '/usr/local/sbin/ceph-sls.debug.sh',
      minute  => '*/5',
      hour    => '*',
    }
  }

  cron { 'ceph heartbeat':
    command => "/usr/bin/ceph --admin-daemon /var/run/ceph/ceph-mon.*.asok mon_status | /usr/bin/json_reformat | /bin/grep state | /bin/grep -q leader && /usr/bin/ceph status | mailx -E -s \"${::hostgroup_0} heartbeat for \"`date +\"\\%Y-\\%m-\\%d\"` ceph-admins@cern.ch",
    minute  => '0',
    hour    => '7'
  }

#  flume::agent { 'agent-ceph-log':
#    es_enabled => true,
#    conf_template => 'hg_ceph_beesly/monitoring/flume/agent-ceph-log.conf.erb',  # see 2.
#    conf_template_params => {
#      es_dns => 'cephes1.cern.ch',  # here put your ElasticSearch master hostname
#      es_cluster_name => 'ceph-cluster',  # here put your ElasticSearch cluster name
#      es_index_prefix => 'ceph.log',  # prefix for the index names
#    },
#    service_enabled => true,
#    flume_user => 'root',  # you might want to change that
#    flume_user_group => 'root',  # and that
#    jvm_Xms => '500m',
#    jvm_Xmx => '1000m',
#    classpath => '/usr/share/java/*',
#  }

  lemon::metric{'13099':} # ceph_mon_spaceUsed
  lemon::metric{'33503':} # exception.ceph_mon_too_large

  class {'lbclient': }

  lbclient::config {'cephmon-lb config':
      nologin   => 'on',
      tmpfull   => 'off',
      sshdaemon => 'off',
      xsessions => 'off',
      afs       => 'off'
  }

  lbd::client {"cephmon-lb alias":
    lbalias  => 'cephmon-lb.cern.ch'
  }

}
