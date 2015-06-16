require 'pp'
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppetx', 'redhat', 'ifcfg.rb'))

BASE = '/etc/sysconfig/network-scripts/ifcfg-'

# When not seedling from interface file
DEFAULT = {
  'ONBOOT'        => 'yes',
  'BOOTPROTO'     => 'dhcp',
  'PEERDNS'       => 'no',
  'NM_CONTROLLED' => 'no',
  'NOZEROCONF'    => 'yes' }

Puppet::Type.type(:vs_port).provide(:ovs_redhat, :parent => :ovs) do
  desc 'Openvswitch port manipulation for RedHat OSes family'

  confine    :osfamily => :redhat
  defaultfor :osfamily => :redhat

  commands :ip     => 'ip'
  commands :ifdown => 'ifdown'
  commands :ifup   => 'ifup'
  commands :vsctl  => 'ovs-vsctl'
  
  def phys_create
    add_bridge = false
    if is_bond? then    
      # add bond
      bond = IFCFG::Bond.new(@resource[:name], @resource[:bridge])
      @resource[:interfaces].each { |iface|
        iface = @resource[:name] if is_port?(iface)
          
        if interface_physical?(iface)
          template = DEFAULT
          extras   = nil
          add_bridge = true
  
          if link?(iface)
            if File.exist?(BASE + @resource[:name])
              template = from_str(File.read(BASE + @resource[:name]))
            end
          end

          bond.append_key('BOND_IFACES', iface)
        end
      }
      [ :tag, :lacp ].each { |key|
        if @resource.to_hash.has_key? key then
          bond.append_key('OVS_OPTIONS', "#{key}=#{@resource[key]}")
        end
      }
      if @resource.to_hash.has_key? :trunks then
        bond.append_key('OVS_OPTIONS', "trunks=#{@resource[:trunks].join(',')}")
      end
      if bond.key?('BOND_IFACES') then
        bond.save(BASE + @resource[:name])
      end

    else
      # add bridge port
      iface = @resource[:interfaces][0]
      iface = @resource[:name] if is_port?(iface)
        
      if interface_physical?(iface)
        template = DEFAULT
        extras   = nil
        add_bridge = true
  
        if link?(iface)
          extras = dynamic_default(iface) if dynamic?(iface)
          if File.exist?(BASE + iface)
            template = from_str(File.read(BASE + iface))
          end
        end
  
        port = IFCFG::Port.new(iface, @resource[:bridge])
        if @resource.to_hash.has_key? :tag then
          port.append_key('OVS_OPTIONS', "tag=#{@resource[:tag]}")
        end
        if @resource.to_hash.has_key? :trunks then
          port.append_key('OVS_OPTIONS', "trunks=#{@resource[:trunks].join(',')}")
        end
        port.save(BASE + iface)
      end
  
    end
    if add_bridge then
      vlans = vsctl("--fake", "list-br").split("\n").keep_if{ |vlan| vlan.include?(@resource[:bridge])}
      bridge = IFCFG::Bridge.new(@resource[:bridge], template)
      bridge.del_key('OVS_OPTIONS="trunks')
      bridge.set(extras) if extras
      if is_bond? then
        @resource[:interfaces].each { |iface|
          iface = @resource[:name] if is_port?(iface)
          if interface_physical?(iface) and dynamic?(iface) then
            bridge.append_key('OVSDHCPINTERFACES', iface)
          end
        }
      end
      bridge.save(BASE + @resource[:bridge])

      ifdown(@resource[:bridge])
      if is_bond? then
        @resource[:interfaces].each { |iface|
          iface = @resource[:name] if is_port?(iface)
          if interface_physical?(iface)
            ifdown(iface)
            ifup(iface)
          end
        }
      else
        iface = @resource[:interfaces]
        iface = @resource[:name] if is_port?(iface)
        if interface_physical?(iface)
          ifdown(iface)
          ifup(iface)
        end
      end
      ifup(@resource[:bridge])
      vlans.each { | vlan |
        ifup(vlan)
      }
    end
  end

  def is_bond?
    if @resource[:interfaces].is_a?(Array) then
      @resource[:interfaces].length > 1
    else
      false
    end
  end

  def self.phys_exists?(interface, bridge)
    if interface_physical?(interface)
      IFCFG::OVS.exists?(interface) &&
      IFCFG::OVS.exists?(bridge)
    else
      true
    end
  end

  def phys_destroy
    remove_bridge = false
    if is_bond? then
      @resource[:interfaces].each { |iface|
        iface = @resource[:name] if is_port?(iface)
        if interface_physical?(iface)
          remove_bridge = true
          ifdown(iface)
          IFCFG::OVS.remove(iface)
        end
      }
      IFCFG::OVS.remove(@resource[:name])
    else
      iface = @resource[:interfaces]
      iface = @resource[:name] if is_port?(iface)
      if interface_physical?(iface)
        remove_bridge = true
        ifdown(iface)
        IFCFG::OVS.remove(iface)
      end
    
    end
    if remove_bridge == true then
      ifdown(@resource[:bridge])
      IFCFG::OVS.remove(@resource[:bridge])
    end
  end

  private
  
  def dynamic?(iface)
    device = ''
    device = ip('addr', 'show', iface)
    return device =~ /dynamic/ ? true : false
  end

  def link?(iface)
    if File.read("/sys/class/net/#{iface}/operstate") =~ /up/
      return true
    else
      return false
    end
  rescue Errno::ENOENT
    return false
  end

  def dynamic_default(iface)
    list = { 'OVSDHCPINTERFACES' => iface }
    # Persistent MAC address taken from interface
    bridge_mac_address = File.read("/sys/class/net/#{iface}/address").chomp
    if bridge_mac_address != ''
      list.merge!({ 'OVS_EXTRA' =>
        "\"set bridge #{@resource[:bridge]} other-config:hwaddr=#{bridge_mac_address}\"" })
    end
    list
  end
  
  def is_port?(iface)
    iface == :portname or iface == [ :portname ]
  end

  def interface_physical?(iface)
    if is_port?(iface) then
      self.class.interface_physical?(@resource[:name])
    else
      self.class.interface_physical?(iface)
    end
  end

  def self.interface_physical?(iface)
    # OVS ports don't have entries in /sys/class/net
    # Alias interfaces (ethX:Y) must use ethX entries
    interface = iface.sub(/:\d/, '')
    ! Dir["/sys/class/net/#{interface}"].empty?
  end

  def from_str(data)
    items = {}
    data.each_line do |line|
      if m = line.match(/^(.*)=(.*)$/)
        items.merge!(m[1] => m[2])
      end
    end
    items
  end
end
