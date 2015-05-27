class hg_ceph_beesly::radosgw {

  Exec { path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ] }

  include hg_ceph_beesly::include::repo
  include hg_ceph_beesly::include::ceph_conf
  include hg_ceph_beesly::include::secrets
  include hg_ceph_beesly::include::lb

  File['/etc/yum-puppet.repos.d/ceph.repo'] -> Package['ceph-radosgw']

  teigi::secret{ "ceph.client.radosgw.${::hostname}.keyring":
    path => "/etc/ceph/ceph.client.radosgw.${::hostname}.keyring",
    before  => Exec['ceph-radosgw-keyring']
  }

  ceph::radosgw { "$::hostname":
    dns_name    => 'cs3.cern.ch'
  }

  firewall {'100 allow traffic on 8080 (civetweb) and 443 from universe.':
    proto       => 'tcp',
    dport       => ['8080','443'],
    action      => 'accept'
  }

  # Disable selinux
  augeas{'disable_selinux':
    context => '/files/etc/sysconfig/selinux',
    changes => 'set SELINUX permissive'
  }

  ensure_packages( ['s3cmd'] )

  sysctl { 'net.ipv4.tcp_timestamps': val => '0' }

}
