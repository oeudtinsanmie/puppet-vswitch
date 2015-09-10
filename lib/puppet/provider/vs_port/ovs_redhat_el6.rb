
require File.expand_path(File.join(File.dirname(__FILE__), 'ovs.rb'))

Puppet::Type.type(:vs_port).provide(:ovs_redhat_el6, :parent => :ovs_redhat) do
  desc 'Openvswitch port manipulation for RedHat OSes family'

  confine    :osfamily => :redhat, :operatingsystemmajrelease => 6
  defaultfor :osfamily => :redhat, :operatingsystemmajrelease => 6

  private

  def dynamic?(iface)
    # iproute doesn't behave as expected on rhel6 for dynamic interfaces
    if File.read(BASE + iface) =~ /^BOOTPROTO=['"]?dhcp['"]?$/
      return true
    else
      return false
    end
  end
end
