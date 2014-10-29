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
#    unless vsctl('list-ports',
#      @resource[:bridge]).include? @resource[:interface]
#      super
#    end
    add_bridge = false
    @resource[:interfaces].each { |iface|
      if iface == :portname then
        iface = @resource[:name]
      end
      if interface_physical?(iface)
        template = DEFAULT
        extras   = nil

        if link?(iface)
          if @resource[:interfaces].length == 1 then 
            extras = dynamic_default(iface) if dynamic?(iface)
          end
          if File.exist?(BASE + iface)
            template = from_str(File.read(BASE + iface))
          end
        end

        port = IFCFG::Port.new(iface, @resource[:bridge])
        port.save(BASE + iface)
      end
    }
    if add_bridge then
      bridge = IFCFG::Bridge.new(@resource[:bridge], template)
      bridge.set(extras) if extras
      bridge.save(BASE + @resource[:bridge])

      ifdown(@resource[:bridge])
      @resource[:interfaces].each { |iface|
        if iface == :portname then
          iface = @resource[:name]
        end
        if interface_physical?(iface)
          ifdown(iface)
          ifup(iface)
        end
      }
      ifup(@resource[:bridge])
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
    @resource[:interfaces].each { |iface|
      if interface_physical?(iface)
        remove_bridge = true
        ifdown(iface)
        IFCFG::OVS.remove(iface)
      end
    }
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

  def interface_physical?(iface)
    if iface == :portname then
      self.class.interface_physical(@resource[:name])
    else
      self.class.interface_physical(iface)
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
