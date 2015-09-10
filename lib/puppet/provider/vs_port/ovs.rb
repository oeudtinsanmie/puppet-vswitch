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
    unless @property_flush[:ensure] == :partial
      @property_flush[:ensure] = nil
    end
  end

  def self.instances
    list_obj.collect { |obj|
      new(Puppet::Util::symbolizehash(obj))
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
    unless @property_flush[:ensure] == :partial
      @property_flush[:ensure] = :present
    end
  end
  
  def destroy
    @property_flush[:ensure] = :absent
  end

  def self.phys_exists?(interface, bridge)
    true
  end
  
  def self.validate(port)
    port[:interfaces].each { |iface|
      if iface == :portname then
        unless phys_exists?(port[:name], port[:bridge])
          port[:ensure] = :partial
        end
      else
        unless phys_exists?(iface, port[:bridge])
          port[:ensure] = :partial
        end
      end
    }
    port
  end

  def self.list_obj
    theAnswer = []
    portlist = vsctl('show').split("\n")
    prevIndent = 0
    bridge = nil
    port = nil
    for line in portlist
      indent = 0
      while line[indent, indent_space] == "    " do
        indent += indent_space
      end
      line = line[indent..-1]
      indent /= indent_space
      case indent
        when 1
          
          if port != nil and !port[:interfaces].empty? then
            theAnswer += [ validate(port) ]
          end
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
          if port != nil and !port[:interfaces].empty? then
            theAnswer += [ validate(port) ]
          end
          port = nil
          if bridge != nil then
            if line.start_with? "Port " then
              name = line[5..-1].lstrip.rstrip
              if name.start_with? "\"" then
                name = name[1..-2]
              end
              lacp = vsctl("get", "port", name, "lacp").lstrip.rstrip
              port = {
                :ensure => :present,
                :name => name, 
                :interfaces => [],
                :bridge => bridge,
              }
              unless lacp == "[]"
                port[:lacp] = lacp
              end
            end
          end
        when 3
          interface = nil
          if bridge != nil and port != nil then
            if line.start_with? "tag: " then
              port[:vtag] = line[5..-1].lstrip.rstrip.to_i
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
              if name == port[:name] then
                interface = :portname
                port[:interfaces] += [ :portname ]
              else
                interface = name
                port[:interfaces] += [ name ]
              end
            end
          end
        when 4
          if bridge != nil and port != nil and interface != nil then
            if line.lstrip.rstrip == 'type: internal' then
              port[:interfaces].delete(interface)
            end
          end
      end
      prevIndent = indent
    end
    if port != nil and !port[:interfaces].empty? then
      theAnswer += [ validate(port) ]
    end
    
    theAnswer
  end

  def phys_create
  end
  
  def phys_destroy
  end
  
  def modified_bond?
    if was_simple_port? then
      if !is_simple_port? then
        @property_flush[:interfaces].sort != @resource[:interfaces].sort
      else
        true
      end
    else
      false
    end
  end

  def simple_port?(hash)
    hash[:interfaces] == [ :portname ] or hash[:interfaces] == :portname
  end

  def is_simple_port?
    simple_port?(@resource)
  end

  def was_simple_port?
    @property_flush[:interfaces] != nil and simple_port?(@property_flush)
  end

  def flush
    if @property_flush[:ensure] == :absent then
      phys_destroy
    end
    if @property_flush[:ensure] == :absent or modified_bond? then
      vsctl("del-port", @resource[:name])
      return
    end
    if @property_flush[:ensure] == :present or modified_bond? then
      if is_simple_port? then
        vsctl("add-port", @resource[:bridge], @resource[:name])
      else
        cmd_list = [ "add-bond", @resource[:bridge], @resource[:name] ]
        cmd_list += @resource[:interfaces]
        vsctl(cmd_list)
      end
    end
    cmd_list =  [ "set", "port", @resource[:name] ]

    aliases = {
       :vtag => "tag", 
    }
    [ :vtag, :lacp ].each { |key|
      if @resource.to_hash.has_key? key then
        keystring = (aliases.has_key? key) ? aliases[key] : key 
        cmd_list += [ "#{keystring}=#{@resource[key]}" ]
      end
    }  
    if @resource.to_hash.has_key?(:trunks) then
      cmd_list += [ "trunks=#{@resource[:trunks].join(',')}" ]
    end
    vsctl(cmd_list)
    
    if @property_flush[:ensure] == :present or @property_flush[:ensure] == :partial then
      phys_create
    end
  end
end
