class hg_ceph_beesly::include::repo {
  class { 'ceph::yum::ceph':
    release => hiera('ceph_release')
  }

  file { '/etc/yum-puppet.repos.d/ceph.repo':
    ensure  => file,
    replace => false,
    require => Yumrepo['ceph']
  }
}
