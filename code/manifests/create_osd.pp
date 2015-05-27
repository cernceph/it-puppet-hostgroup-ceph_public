define hg_ceph_beesly::create_osd {
  if $::ssds and $name in $::ssds {
    notify { "Refusing to prepare SSD ${name} as an OSD": }
  } else {
    $journals = hiera("${::boardproductname}_journals")
    $journal = $journals[$name]
    if $journal or $journal == "" {
      ceph::osd::udevice { $name:
        journal => $journal
      }
    } else {
      notify { "Journal for OSD ${name} not defined": }
    }
  }
}
