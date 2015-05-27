class hg_ceph_beesly::include::secrets {
  file { '/root/.ssh':
    ensure => 'directory'
  }

  teigi::secret{ 'id_rsa':
    path    => '/root/.ssh/id_rsa',
    require => File['/root/.ssh']
  }

  teigi::secret{ 'id_rsa.pub':
    path    => '/root/.ssh/id_rsa.pub',
    require => File['/root/.ssh']
  }

  teigi::secret{ 'authorized_keys':
    path    => '/root/.ssh/authorized_keys',
    mode    => '600',
    require => File['/root/.ssh']
  }
}
