require 'puppet'

Puppet::Type.newtype(:vs_bridge) do
  desc 'A Switch - For example "br-int" in OpenStack'

  ensurable

  newparam(:name, :namevar => true) do
    desc 'The bridge to configure'

    validate do |value|
      if !value.is_a?(String)
        raise ArgumentError, "Invalid name #{value}. Requires a String, not a #{value.class}"
      end
    end
  end
  
  newproperty(:vlans, :array_matching => :all) do
    desc 'One or more vlan child bridges created with this bridge as the parent'
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

  newproperty(:external_ids, :array_matching => :all) do
    desc 'Array of External IDs for the bridge: "key1=value2,key2=value2"'

    def insync?(is)    
      if is.is_a?(Array) and @should.is_a?(Array)
        is.sort == @should.sort
      elsif is.is_a?(Array) and @should.is_a?(String)
        is.sort == @should.split(",").sort
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
          if !val.is_a?(String)
            raise ArgumentError, "Invalid external_ids #{val}. Requires a String, not a #{val.class}"
          end
          if val !~ /^(?>[a-zA-Z]\S*=\S*){1}$/
            raise ArgumentError, "Invalid external_ids #{val}. Must an array of key1=value2,key2=value2"
          end
        }
      else 
        if !value.is_a?(String)
          raise ArgumentError, "Invalid external_ids #{value}. Requires a String, not a #{value.class}"
        end
        if value !~ /^(?>[a-zA-Z]\S*=\S*){1}(?>[,][a-zA-Z]\S*=\S*)*$/
          raise ArgumentError, "Invalid external_ids #{value}. Must a list of key1=value2,key2=value2"
        end
      end
    end
  end
end
