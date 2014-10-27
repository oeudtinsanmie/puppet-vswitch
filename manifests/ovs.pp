# vswitch: open-vswitch
#
class vswitch::ovs(
  $package_ensure = 'present',
  $src_install    = $::vswitch::params::src_install,
  $src_version    = $::vswitch::params::src_version,
) {

  include 'vswitch::params'
  
  define vswitch::ovs::resolvedep ($pkg = $title) {
    if !defined(Package[$pkg]) {
      package { $pkg:
        ensure => present,
        tag => "vswitch-dep",
      }
    }
    else {
      Package <| title == $pkg |> {
        tag => "vswitch-dep",
      }
    }
  }

  case $::osfamily {
    'Debian': {
      # OVS doesn't build unless the kernel headers are present.
      $kernelheaders_pkg = "linux-headers-${::kernelrelease}"
      if ! defined(Package[$kernelheaders_pkg]) {
        package { $kernelheaders_pkg: ensure => $package_ensure }
      }
      case $::operatingsystem {
        'ubuntu': {
          $ovs_status = '/sbin/status openvswitch-switch | fgrep "start/running"'
        }
        default: {
          $ovs_status = '/etc/init.d/openvswitch-switch status | fgrep "is running"'
        }
      }
      service {'openvswitch':
        ensure      => true,
        enable      => true,
        name        => $::vswitch::params::ovs_service_name,
        hasstatus   => false, # the supplied command returns true even if it's not running
        # Not perfect - should spot if either service is not running - but it'll do
        status      => $ovs_status
      }
      exec { 'rebuild-ovsmod':
        command     => '/usr/sbin/dpkg-reconfigure openvswitch-datapath-dkms > /tmp/reconf-log',
        creates     => "/lib/modules/${::kernelrelease}/updates/dkms/openvswitch_mod.ko",
        require     => [Package['openvswitch-datapath-dkms', $kernelheaders_pkg]],
        before      => Package['openvswitch-switch'],
        refreshonly => true
      }
      if $src_install {
        fail( "${::osfamily} not yet supported for src install by puppet-vswitch")
      }
    }
    'Redhat': {
      service {'openvswitch':
        ensure      => true,
        enable      => true,
        name        => $::vswitch::params::ovs_service_name,
      }
      if $src_install {
        class { "rpmbuild": }
        rpmbuild::env::userhome { "ovswitch": }
        
        user { "ovswitch":
        }
        
        vswitch::ovs::resolvedep { $::vswitch::params::build_prereqs: }
        
        archive { "openvswitch-${src_version}":
          ensure    => present,
          url       => "http://openvswitch.org/releases/openvswitch-${src_version}.tar.gz",
          target    => "/home/ovswitch/rpmbuild/SOURCES",
          checksum  => false,
        }
        
        exec { "build-ovs-rpm" :
          command => "/usr/bin/rpmbuild -bb ${::vswitch::params::spec}",
          user => "ovswitch",
          cwd => "/home/ovswitch/rpmbuild/SOURCES/openvswitch-${src_version}",
          tag => "build-ovs",
        }
        exec { "build-ovs-kmod-rpm" :
          command => "/usr/bin/rpmbuild -bb ${::vswitch::params::kmod_spec}",
          user => "ovswitch",
          cwd => "/home/ovswitch/rpmbuild/SOURCES/openvswitch-${src_version}",
          tag => "build-ovs",
        }
        
        exec { "yuminstall-ovs":
          command => "yum localinstall /home/ovswitch/rpmbuild/RPMS/${::architecture}/openvswitch-${src_version}-1.${::architecture}.rpm",
          tag => "install-ovs",
        }
        exec { "yuminstall-kmod-ovs":
          command => "yum localinstall /home/ovswitch/rpmbuild/RPMS/${::architecture}/kmod-openvswitch-${src_version}-1.el${::vswitch::params::majrelease}.${::architecture}.rpm",
          tag => "install-ovs",
        }
        
        User['ovswitch'] -> File <| owner == "ovswitch" |> -> Archive["openvswitch-${src_version}"] -> Package <| tag == "vswitch-dep" |> -> Exec <| tag == "build-ovs" |> -> Exec <| tag == "install-ovs" |> -> Service['openvswitch']
      }
    }
    default: {
      fail( "${::osfamily} not yet supported by puppet-vswitch")
    }
  }
  
  if !$src_install {
	  package { $::vswitch::params::ovs_package_name:
	    ensure  => $package_ensure,
	    before  => Service['openvswitch'],
	  }
  }

  Service['openvswitch'] -> Vs_port<||>
  Service['openvswitch'] -> Vs_bridge<||>
}
