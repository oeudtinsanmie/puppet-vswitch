require 'puppet'

Puppet::Type.type(:vs_bridge).provide(:ovs) do
  commands :vsctl => 'ovs-vsctl'
  commands :ip    => 'ip'
  
  def self.INDENT
    4
  end
  
  def initialize(value={})
      super(value)
      @property_flush = {}
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
    bridgelist = vsctl('show').split('\n')
    prevIndent = 0
    for line in bridgelist
      indent = 0
      while line[indent] == ' ' do
        indent += INDENT
      end
      line = line[indent, -1]
      indent /= INDENT
      
      case indent
        when 1
          if bridge then
            theAnswer += [ bridge ]
          end
          port = nil
          interface = nil
          bridge = nil
          if line.start_with? 'Bridge ' then
            name = line.delete 'Bridge '.lstrip.rstrip
            if name.start_with '\"' then
              name = name[1,-2]
            end
            bridge = {
              :name  => name,
              :ensure => :present,
              :vlans => [], 
            }
          end
          
        when 2
          interface = nil
          port = nil
          if bridge then 
            if line.start_with? 'Port ' then
              name = line.delete 'Port '.lstrip.rstrip
              if name.start_with '\"' then
                name = name[1,-2]
              end
              port = {
                :name => name, 
              }
              
            end
          end
        when 3
          interface = nil
          if bridge and port then
            if line.start_with? 'Interface ' then
              name = line.delete 'Interface '.lstrip.rstrip
              if name.start_with '\"' then
                name = name[1,-2]
              end
              interface = {
                :name => name, 
              }
            end
          end
        when 4
          if bridge and port and interface then
            if line.lstrp.rstrp == 'type: internal' then
              bridge[:vlans] += [ port[:name] ]
            end
          end
      end
      prevIndent = indent
    end
    
    theAnswer
  end
  
  def flush
  end

#  def exists?
#    vsctl("br-exists", @resource[:name])
#  rescue Puppet::ExecutionFailure
#    return false
#  end
#
#  def create
#    vsctl('add-br', @resource[:name])
#    ip('link', 'set', @resource[:name], 'up')
#    external_ids = @resource[:external_ids] if @resource[:external_ids]
#  end
#
#  def destroy
#    ip('link', 'set', @resource[:name], 'down')
#    vsctl('del-br', @resource[:name])
#  end

  def _split(string, splitter=',')
    return Hash[string.split(splitter).map{|i| i.split('=')}]
  end

  def external_ids
    result = vsctl('br-get-external-id', @resource[:name])
    return result.split("\n").join(',')
  end

  def external_ids=(value)
    old_ids = _split(external_ids)
    new_ids = _split(value)

    new_ids.each_pair do |k,v|
      unless old_ids.has_key?(k)
        vsctl('br-set-external-id', @resource[:name], k, v)
      end
    end
  end
end
