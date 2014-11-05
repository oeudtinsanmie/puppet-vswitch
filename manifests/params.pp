# vswitch params
#
class vswitch::params {
      
  $defaultrepo = {
    enabled  => 1,
    gpgcheck => 1,
    tag   => "ovsrepo",
  }
  
  case $::osfamily {
    'Redhat': {
      $ovs_package_name = 'openvswitch'
      $ovs_service_name = 'openvswitch'
      $provider         = 'ovs'
      case $::operatingsystem {
        'RedHat' , 'CentOS' : {
          $fedora_base  = "http://dl.fedoraproject.org/pub"
          $key          = '/repodata/repomd.xml.key'
          $repos        = {
            'fedora-epel' => {
			        descr  => 'dl.fedoraproject.org epel mirror',
			        baseurl => "${fedora_base}/epel/${lsbmajdistrelease}/${architecture}",
			        gpgkey  => "${fedora_base}/epel/RPM-GPG-KEY-EPEL-${lsbmajdistrelease}",
			      },
			      'openstack-epel' => {
			        baseurl => "http://repos.fedorapeople.org/repos/openstack/openstack-havana/epel-6",
			        descr   => 'openstack havana epel repository',
			        gpgcheck => 0,
			      },         
          }
        }
        default: {
          $repos            = undef
        }
      }
    }
    'Debian': {
      $ovs_package_name = ['openvswitch-switch', 'openvswitch-datapath-dkms']
      $ovs_service_name = 'openvswitch-switch'
      $provider         = 'ovs'
      $repos            = undef
    }
    default: {
      fail " Osfamily ${::osfamily} not supported yet"
    }
  } # Case $::osfamily
}
