class hg_ceph_beesly::include::lb {

  ###
  # Firewall
  ###
  firewall { '100 Haproxy http+https frontend':
    state  => 'NEW',
    proto  => 'tcp',
    dport  => ['80', '443'],
    action => accept,
  }

  firewall { '100 Load Balancer Stick table synchronization':
    state  => 'NEW',
    proto  => 'tcp',
    dport  => '7777',
    action => accept,
  }

  ###
  # Syslog
  ###
  file { '/etc/rsyslog.d/50-udp.conf':
    ensure  => 'present',
    owner   => 'root',
    source  => 'puppet:///modules/hg_ceph_beesly/50-udp.rsyslog.conf',
    require => Class['rsyslog::config'],
    notify  => Class['rsyslog::service'],
  }

  ###
  # Certificate
  ###

  # Temporary
  exec {'Create_PEM_File':
    command => "cat /var/lib/puppet/ssl/certs/${::fqdn}.pem /var/lib/puppet/ssl/private_keys/${::fqdn}.pem > /etc/haproxy/cert.pem",
    creates => '/etc/haproxy/cert.pem',
    path    => ['/bin', '/usr/bin'],
    notify  => Service['haproxy'],
  }

  # Fetching Cert from TBag
  #teigi::secret{'frontend_pemcrt':
  #  key    => 'frontend_pemcrt',
  #  path   => '/etc/haproxy/cert.pem',
  #  owner  => 'root',
  #  group  => 'haproxy',
  #  mode   => '0440',
  #  notify => Service['haproxy'],
  #}

  ###
  # Haproxy config
  ###
  class { 'haproxy':
    global_options   => {
      'log'                       => "${::ipaddress} local0",
      'chroot'                    => '/var/lib/haproxy',
      'pidfile'                   => '/var/run/haproxy.pid',
      'maxconn'                   => '8000',
      'user'                      => 'haproxy',
      'group'                     => 'haproxy',
      'daemon'                    => '',
      'stats'                     => 'socket /var/lib/haproxy/stats',
      'tune.ssl.default-dh-param' => 2048,
      'ssl-default-bind-ciphers'  => 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128:AES256:AES:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK'
    },
    defaults_options => {
      'log'     => 'global',
      'stats'   => 'enable',
      'mode'    => 'http',
      'option'  => [
        'redispatch',
        'http-server-close',
        'contstats',
        'httplog'
      ],
      'retries' => '3',
      'timeout' => [
        'http-request 10s',
        'queue 1m',
        'connect 10s',
        'client 1m',
        'server 1m',
        'check 10s'
      ],
      'maxconn' => '8000'
    },
    restart_command  => '/etc/init.d/haproxy reload',
  }

  $ha_password = hiera('haproxy_stats_password')

  haproxy::backend { 'stats':
    options => {
      'stats' => ['enable', 'uri /haproxy_stats', "auth haproxy:${ha_password}", 'refresh 30s'],
    },
  }

  $peers    = "${::hostgroup_0}-peers-${::environment}"
  $frontend = "${::hostgroup_0}-frontend-${::environment}"
  $backend  = "${::hostgroup_0}-backend-${::environment}"

  haproxy::peers{ $peers: }

  @@haproxy::peer{ $::hostname:
    peers_name   => $peers,
    server_names => $::fqdn,
    port         => 7777,
  }

  haproxy::frontend { $frontend:
    bind    => {
      "${::ipaddress}:443" => ['ssl', 'no-sslv3', 'crt /etc/haproxy/cert.pem', 'verify none'],
      "${::ipaddress}:80"  => [],
    },
    options => {
      'timeout'         => ['http-request 1m', 'client 1m'],
      'default_backend' => $backend,
      'acl'             => ['acl_haproxy_stats url_beg /haproxy_stats'],
      'use_backend'     => ['stats if acl_haproxy_stats'],
      'capture'         => ['request header User-Agent len 256',
                            'request header Host len 128'
                        ],
    },
  }

  haproxy::backend{ $backend:
    options => {
      'balance'       => 'roundrobin',
      'timeout'       => ['server 1m', 'queue 1m', 'connect 1m'],
      'option'        => 'httpchk GET /',
      'http-response' => 'replace-value X-Storage-Url ^http://([a-z0-9.]+):[0-9]{1,5}(.*)$ https://\1\2',
      'stick-table'   => "type ip size 20k peers ${peers} expire 2h",
    },
  }

  @@haproxy::balancermember { "${::fqdn}-backend-${::environment}":
    listening_service => $backend,
    server_names      => $::hostname,
    ipaddresses       => $::ipaddress,
    ports             => 8080,
    options           => [
      'check',
      'weight 20',
    ],
  }

  ###
  # LB Client
  ###

  class {'lbclient': }

  lbclient::config {'s3 lbalias config':
    nologin   => 'on',
    tmpfull   => 'on',
    sshdaemon => 'on',
    xsessions => 'off',
    afs       => 'off'
  }

  lbd::client {'s3 LB alias':
    lbalias  => 'cs3.cern.ch'
  }

  ###
  # Haproxy statistics
  ###
  file {'/usr/local/bin/haproxy_stats.rb':
    ensure => present,
    mode   => '0755',
    source => 'puppet:///modules/hg_ceph_beesly/radosgw_haproxy_stats.rb'
  }

  cron { 'radosgw_haproxy_stats.rb':
    command => '/usr/local/bin/haproxy_stats.rb &> /dev/null',
    minute  => '*',
    hour    => '*',
  }

}
