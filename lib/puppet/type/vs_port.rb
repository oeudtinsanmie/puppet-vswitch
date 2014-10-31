require 'puppet'

Puppet::Type.newtype(:vs_port) do
  desc 'A Virtual Switch Port'

  ensurable

  newparam(:name) do
    desc 'The id for this port'

    validate do |value|
      if !value.is_a?(String)
        raise ArgumentError, "Invalid interface #{value}. Requires a String, not a #{value.class}"
      end
    end
  end
  
  newproperty(:interfaces, :array_matching => :all) do
    desc 'The interface(s) to attach to the bridge'
    def insync?(is)
      # The current value may be nil and we don't
      # want to call sort on it so make sure we have arrays 
      # (@ref https://ask.puppetlabs.com/question/2910/puppet-types-with-array-property/)
      if is.is_a?(Array) and @should.is_a?(Array)
        is.sort == @should.sort
      elsif @should.is_a?(Array) and @should.length == 1
        is == @should[0]
      else
        is == @should
      end
    end
  
    validate do |value|
      if (value == nil) then 
        return
      end
      if value.is_a?(Array)
        value.each { |val|
          if !val.is_a?(String) and !val.is_a?(Symbol)
            raise ArgumentError, "Invalid interface #{val}. Requires a String, not a #{val.class}"
          end
        }
      elsif !value.is_a?(String) and !value.is_a?(Symbol)
        raise ArgumentError, "Invalid interface #{value}. Requires a String, not a #{value.class}"
      end
    end
    
    defaultto([:portname])
  end
  
  newproperty(:tag) do
    desc 'The vlan with which to tag untagged packets from this port'
    validate do |value|
      unless value.is_a?(Integer) and value >=0
        raise ArgumentError, "vlan ids should be non-negative integers"
      end
    end
  end
  
  newproperty(:trunks, :array_matching => :all) do
    desc 'One or more vlan trunks for this port'
    def insync?(is)
      # The current value may be nil and we don't
      # want to call sort on it so make sure we have arrays 
      # (@ref https://ask.puppetlabs.com/question/2910/puppet-types-with-array-property/)
      if is.is_a?(Array) and @should.is_a?(Array)
        is.sort == @should.sort
      elsif @should.is_a?(Array) and @should.length == 1
        is == @should[0]
      else
        is == @should
      end
    end
  
    def should_to_s(newvalue)
      newvalue.inspect
    end
  
    def is_to_s(currentvalue)
      currentvalue.inspect
    end
  
    validate do |value|
      if (value == nil) then 
        return
      end
      if value.is_a?(Array)
        value.each { |val|
          unless val.is_a?(Integer) and val >=0
            raise ArgumentError, "vlan ids should be non-negative integers"
          end
        }
      else
        unless value.is_a?(Integer) and value >=0
          raise ArgumentError, "vlan ids should be non-negative integers"
        end
      end
    end
    
  end
  
  newproperty(:lacp) do
    desc 'LACP status for this port, if it has multiple interfaces attached'

  end
  
  newproperty(:bridge) do
    desc 'The bridge to attach to'

    validate do |value|
      if !value.is_a?(String)
        raise ArgumentError, "Invalid bridge #{value}. Requires a String, not a #{value.class}'"
      end
    end
  end

  autorequire(:vs_bridge) do
    self[:bridge] if self[:bridge]
  end
end
