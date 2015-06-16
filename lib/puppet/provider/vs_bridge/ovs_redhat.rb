
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppetx', 'redhat', 'ifcfg.rb'))

BASE = '/etc/sysconfig/network-scripts/ifcfg-'

# When not seedling from interface file
DEFAULT = {
  'ONBOOT'        => 'yes',
  'BOOTPROTO'     => 'dhcp',
  'PEERDNS'       => 'no',
  'NM_CONTROLLED' => 'no',
  'NOZEROCONF'    => 'yes' }

Puppet::Type.type(:vs_bridge).provide(:ovs_redhat, :parent => :ovs) do
  desc 'Openvswitch port manipulation for RedHat OSes family'

  confine    :osfamily => :redhat
  defaultfor :osfamily => :redhat

  commands :ip     => 'ip'
  commands :ifdown => 'ifdown'
  commands :ifup   => 'ifup'
  commands :vsctl  => 'ovs-vsctl'
  
  def phys_create
    bridge = IFCFG::Bridge.new(@resource[:name], template)
    if @resource[:external_ids] then 
      extras = ""
      if @resource[:external_ids].is_a?(Array) then
        @resource[:external_ids].each { | id |
          key, val = id.split("=")
          extras += "br-set-external-id #{key} #{val} "
        }
      else
        key, val = @resource[:external_ids].split("=")
        extras += "br-set-external-id #{key} #{val} "
      end
    end
    bridge.set_key('OVS_EXTRA', extras) if extras
    bridge.save(BASE + @resource[:name])
  end
  
  def phys_destroy
    ifdown(@resource[:name])
    IFCFG::OVS.remove(@resource[:name])
  end

  def phys_create_vlan(vlan)
    bridge = IFCFG::Bridge.new("#{@resource[:name]}.#{vlan}", template)
    bridge.set_key('OVS_OPTIONS', "#{@resource[:name]} #{vlan}")
    bridge.save(BASE + "#{@resource[:name]}.#{vlan}")
  end
  
  def phys_destroy_vlan(vlan)
    IFCFG::OVS.remove("#{@resource[:name]}.#{vlan}")
  end
  
  def ifreset
    ifdown(@resource[:name])
    ifup(@resource[:name])
    if @resource[:vlans] then
      @resource[:vlans].each { |vlan|
        ifup("#{@resource[:name]}.#{vlan}")
      }
    end
  end
end