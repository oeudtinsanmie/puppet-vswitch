require 'puppet'

Puppet::Type.type(:vs_bridge).provide(:ovs) do
  commands :vsctl => 'ovs-vsctl'
  commands :ip    => 'ip'

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
  
  def self.list_obj
    theAnswer = []
    bridgelist = vsctl('show').split("\n")
    prevIndent = 0
    bridge = nil
    for line in bridgelist
      indent = 0
      while line[indent, indent_space] == "    " do
        indent += indent_space
      end
      line = line[indent..-1]
      indent /= indent_space
      case indent
        when 1
          if bridge != nil then
            theAnswer += [ bridge ]
          end
          port = nil
          interface = nil
          bridge = nil
          if line.start_with? "Bridge " then
            name = line[7..-1].lstrip.rstrip
            if name.start_with? "\"" then
              name = name[1..-2]
            end
            bridge = {
              :name  => name,
              :ensure => :present,
              :vlans => [],
              :external_ids =>  get_external_ids(name),
            }
          end
          
        when 2
          interface = nil
          port = nil
          if bridge != nil then
            if line.start_with? "Port " then
              name = line[5..-1].lstrip.rstrip
              if name.start_with? "\"" then
                name = name[1..-2]
              end
              port = {
                :name => name, 
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
            if line.start_with? "Interface " then
              name = line[10..-1].lstrip.rstrip
              if name.start_with? "\"" then
                name = name[1..-2]
              end
              interface = {
                :name => name, 
              }
            end
          end
        when 4
          if bridge != nil and port != nil and interface != nil then
            if line.lstrip.rstrip == 'type: internal' and port[:tag] != nil then
              bridge[:vlans] += [ port[:tag] ]
            end
          end
      end
      prevIndent = indent
    end
    if bridge != nil then
      theAnswer += [ bridge ]
    end
    
    theAnswer
  end
  
  def flush
    pp @property_flush
    pp @resource.to_hash
    if @property_flush[:ensure] == :absent then
      vsctl("del-br", @resource[:name])
      return
    end
    if @property_flush[:ensure] == :present then
      vsctl("add-br", @resource[:name])
    end
    if @resource.to_hash[:vlans] != nil then
      @resource.to_hash[:vlans].each { |vlan|
        if @property_flush[:vlans] != nil and @property_flush[:vlans].include? "#{@resource[:name]}.#{vlan}" then
          @property_flush[:vlans].delete(vlan)
        else
          vsctl("add-br", "#{@resource[:name]}.#{vlan}", @resource[:name], vlan)
        end
      }
    end
    if @property_flush[:vlans] != nil then
      @property_flush[:vlans].each { |vlan|
        vsctl("del-br", "#{@resource[:name]}.#{vlan}")
      }
    end
    
    flush_external_ids
  end

  def _split(string, splitter=',')
    return Hash[string.split(splitter).map{|i| i.split('=')}]
  end

  def self.get_external_ids(name)
    result = vsctl('br-get-external-id', name)
    return result.split("\n")
  end

  def flush_external_ids
    if @property_flush[:external_ids] == nil then
      old_ids = {}
    else 
      old_ids = Hash[@property_flush[:external_ids].map{|i| i.split('=')}]
    end
    if @resource.to_hash[:external_ids] == nil then
      new_ids = {}
    else
      if @resource.to_hash[:external_ids].is_a?(String) then # split if comma delimited list
        new_ids = _split(@resource.t_hash[:external_ids])
      else # just map if it's an array
        new_ids = Hash[@resource.to_hash[:external_ids].map{|i| i.split('=')}]
      end
    end
    
    new_ids.each_pair do |k,v|
      if v != old_ids[k] then  # update if value is not in old list or has changed
        vsctl('br-set-external-id', @resource[:name], k, v)
      end
      if old_ids.has_key?(k) then
        old_ids.delete(k) # remove from old_ids, so key does not get unset in next step
      end
    end
    old_ids.each_pair do |k,v| # unset any external ids not in the list
      vsctl('br-set-external-id', @resource[:name], k)
    end
  end
end
