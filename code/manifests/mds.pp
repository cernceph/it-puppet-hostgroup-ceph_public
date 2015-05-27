class hg_ceph_beesly::mds {

  Exec { path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ] }

  include hg_ceph_beesly::include::repo
  include hg_ceph_beesly::include::ceph_conf
  include hg_ceph_beesly::include::secrets

  $id = hiera('mds_id')

  teigi::secret{ 'keyring':
    path => "/etc/ceph/keyring",
    require => Package['ceph'],
  }

  ceph::mds { "${id}":
    require => File['/etc/ceph/keyring'],
  }

  firewall {'100 allow ceph mds access from the universe.':
    proto       => 'tcp',
    dport       => ['6800-7100'],
    action      => 'accept'
  }

}
