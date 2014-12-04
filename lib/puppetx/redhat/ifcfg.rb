module IFCFG
  class OVS
    attr_reader :ifcfg

    def self.exists?(name)
      File.exist?(BASE + name)
    end

    def self.remove(name)
      Puppet.debug "Removing #{BASE + name}"
      File.delete(BASE + name)
    rescue Errno::ENOENT
    end

    def initialize(name, seed=nil)
      @name  = name
      @ifcfg = {}
      set(seed)
      set_key('DEVICE', @name)
      set_key('DEVICETYPE', 'ovs')
      replace_key('BOOTPROTO', 'OVSBOOTPROTO') if self.class == IFCFG::Bridge
    end

    def del_key(key)
      @ifcfg.delete(key)
    end

    def key?(key)
      @ifcfg.has_key?(key)
    end

    def key(key)
      @ifcfg.has_key?(key)
    end

    def replace_key(key, new_key)
      value = @ifcfg[key]
      @ifcfg.delete(key)
      set_key(new_key, value)
    end

    def set(list)
      if list != nil && list.class == Hash
        list.each { |key, value| set_key(key, value) }
      end
    end

    def set_key(key, value)
      @ifcfg.merge!({key => value })
    end
    
    def append_key(key, value)
      if self.key? key then
        oldval = @ifcfg[key]
        unless oldval.is_a?(Array) 
          oldval = [ oldval ]
        end
      else
        oldval = []
      end
      unless value.is_a?(Array) 
        value = [ value ]
      end
      set_key(key, oldval + value) 
    end

    def to_s
      str = ''
      @ifcfg.each { |x, y|
        if y.is_a?(Array) then
          str << "#{x}=\"#{y.join(' ')}\"\n"
        else
          str << "#{x}=#{y}\n"
        end
      }
      str
    end

    def save(filename)
      Puppet.debug "Writing to file #{filename}"
      File.open(filename, 'w') { |file| file << self.to_s }
    end
  end

  class Bridge < OVS
    def initialize(name, template=nil)
      super(name, template)
      set_key('TYPE', 'OVSBridge')
      del_key('HWADDR')
    end
  end

  class Port < OVS
    def initialize(name, bridge)
      super(name)
      set_key('TYPE', 'OVSPort')
      set_key('OVS_BRIDGE', bridge)
      set_key('ONBOOT', 'yes')
      set_key('BOOTPROTO', 'none')
    end
  end
  
  class Bond < OVS
    def initialize(name, bridge)
      super(name)
      Puppet.debug "My bridge is #{bridge}"
      set_key('TYPE', 'OVSBond')
      set_key('OVS_BRIDGE', bridge)
      set_key('ONBOOT', 'yes')
      set_key('BOOTPROTO', 'none')
    end
  end
end
