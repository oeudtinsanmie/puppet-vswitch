require 'puppet'

Puppet::Type.type(:vs_port).provide(:ovs) do
  desc 'Openvswitch port manipulation'

  commands :vsctl => 'ovs-vsctl'

  mk_resource_methods
  
  def self.indent_space
    4
  end

  def initialize(value={})
    super(value)
    @property_flush = Hash[value]
    @property_flush[:ensure] = nil
  end

  def self.instances
    list_obj.collect { |obj|
      new(obj)
    }
  end
  
  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end
  
  def create
    @property_flush[:ensure] = :present
  end
  
  def destroy
    @property_flush[:ensure] = :absent
  end

  def self.phys_exists?(interface, bridge)
    true
  end
  
  def self.list_obj
    theAnswer = []
    portlist = vsctl('show').split("\n")
    prevIndent = 0
    bridge = nil
    for line in portlist
      indent = 0
      while line[indent, indent_space] == "    " do
        indent += indent_space
      end
      line = line[indent..-1]
      indent /= indent_space
      case indent
        when 1
          
          port = nil
          interface = nil
          bridge = nil
          if line.start_with? "Bridge " then
            name = line[7..-1].lstrip.rstrip
            if name.start_with? "\"" then
              name = name[1..-2]
            end
            bridge = name
          end
          
        when 2
          interface = nil
          if port != nil then
            [ :tag, :trunks ].each { |key|
              if port[key] == nil then
                port[key] = []
              end
            } 
            port[:interfaces].each { |iface|
              if iface == :portname then
                unless phys_exists?(port[:name], port[:bridge])
                  port[:ensure] = :absent
                end
              else
                unless phys_exists?(iface, port[:bridge])
                  port[:ensure] = :absent
                end
              end
            }
            theAnswer += [ port ]
          end
          port = nil
          if bridge != nil then
            if line.start_with? "Port " then
              name = line[5..-1].lstrip.rstrip
              if name.start_with? "\"" then
                name = name[1..-2]
              end
              port = {
                :ensure => :present,
                :name => name, 
                :interfaces => [],
                :bridge => bridge,
                :lacp => vsctl("get", "port", name, "lacp")
              }
            end
          end
        when 3
          interface = nil
          if bridge != nil and port != nil then
            if line.start_with? "tag: " then
              port[:tag] = line[5..-1].lstrip.rstrip.to_i
            end
            
          end
          if bridge != nil and port != nil then
            if line.start_with? "trunks: " then
              line = line[8..-1].lstrip.rstrip
              line = line[1..-2]
              port[:trunks] = line.split(',').collect { |vlan|
                vlan.to_i
              }
            end
            
          end
          if bridge != nil and port != nil then
            if line.start_with? "Interface " then
              name = line[10..-1].lstrip.rstrip
              if name.start_with? "\"" then
                name = name[1..-2]
              end
              interface = name
              if name == port[:name] then
                port[:interfaces] += [ :portname ]
              else
                port[:interfaces] += [ name ]
              end
            end
          end
        when 4
          if bridge != nil and port != nil and interface != nil then
            if line.lstrip.rstrip == 'type: internal' and port[:tag] != nil then
              port[:interfaces].delete(interface)
            end
          end
      end
      prevIndent = indent
    end
    if port != nil then
      theAnswer += [ port ]
    end
    
    theAnswer
  end

  def phys_create
  end
  
  def phys_destroy
  end
  
  def flush
    if @property_flush[:ensure] == :absent then
      phys_destroy
    end
    if @property_flush[:ensure] == :absent or (@resource[:interfaces] != [ :portname ] and @property_flush[:interfaces].sort != @resource[:interfaces].sort) then
      vsctl("del-port", @resource[:name])
      return
    end
    if @property_flush[:ensure] == :present or (@resource[:interfaces] != [ :portname ] and @property_flush[:interfaces].sort != @resource[:interfaces].sort) then
      if @resource[:interfaces] == [ :portname ] then
        vsctl("add-port", @resource[:bridge], @resource[:name])
      else
        cmd_list = [ "add-bond", @resource[:bridge], @resource[:name] ]
        cmd_list += @resource[:interfaces]
        vsctl(cmd_list)
      end
    end
    cmd_list =  [ "set", "port", @resource[:name] ]
    cmd_list += [ "lacp=#{@resource[:lacp]}" ]
    cmd_list += [ "tag=#{@resource[:tag]}" ]
    cmd_list += [ "trunks=#{@resource[:trunks].join(',')}" ]
    vsctl(cmd_list)
    
    if @property_flush[:ensure] == :present then
      phys_create
    end
  end
end
