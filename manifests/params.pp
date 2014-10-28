# vswitch params
#
class vswitch::params {
  $build_prereqs = [ 
    'gcc',
    'make',
    'python-devel',
    'openssl-devel', 
    'kernel-devel', 
    'graphviz',
    'kernel-debug-devel', 
    'autoconf',
    'automake',
    'rpm-build',
    'redhat-rpm-config', 
    'libtool',
  ]
  case $::osfamily {
    'Redhat': {
      $ovs_package_name = 'openvswitch'
      $ovs_service_name = 'openvswitch'
      $provider         = 'ovs_redhat'
      $src_install      = true
      $src_version      = '2.3.0'
      $build_exec = {
        environment => [
          "HOME=/home/ovswitch",
        ], 
        user => "ovswitch",
        tag => "build-ovs",
      }
      if $::lsbmajdistrelease == undef {
        $majrelease = $::operatingsystemmajrelease
      }
      else {
        $majrelease = $::lsbmajdistrelease
      }
      case $::operatingsystem {
        'RedHat', 'CentOS' : {
          $spec             = 'rhel/openvswitch.spec'
          $kmod_spec        = "rhel/openvswitch-kmod-rhel${majrelease}.spec"
        }
        'Fedora': {
          $spec             = 'rhel/openvswitch-fedora.spec'
          $kmod_spec        = 'rhel/openvswitch-kmod-fedora.spec'
        }
      }
    }
    'Debian': {
      $ovs_package_name = ['openvswitch-switch', 'openvswitch-datapath-dkms']
      $ovs_service_name = 'openvswitch-switch'
      $provider         = 'ovs'
      $src_install      = false
      $src_version      = '2.3.0'
    }
    default: {
      fail " Osfamily ${::osfamily} not supported yet"
    }
  } # Case $::osfamily
}
