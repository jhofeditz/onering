# Copyright 2012 Outbrain, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'model'

class User < App::Model::Elasticsearch
  index_name "users"

  field :name,         :string
  field :email,        :string
  field :client_keys,  :object,  :default => {}
  field :tokens,       :object,  :array => true
  field :options,      :object,  :default => {}
  field :logged_in_at, :date
  field :created_at,   :date,    :default => Time.now
  field :updated_at,   :date,    :default => Time.now

  def groups
    Group.urlquery("users/#{self.id}").collect{|i| i.id } rescue []
  end

  def capabilities
  # find all capabilites where this user or any of its groups are named
    capabilities = Capability.search({
      :filter => {
        :or => [{
          :term => {
            :users => self.id
          }
        },{
          :terms => {
            :groups => self.groups,
            :execution => :and
          }
        }]
      }
    }).collect{|c|
      (c.capabilities ? c.capabilities : c.id)
    }.flatten

  # select only groups whose set of capabilities is fully included in our existing set
    groups = Capability.search({
      :filter => {
        :exists => {
          :field => :capabilities
        }
      }
    }).select{|i|
      (i.capabilities & capabilities).length == i.capabilities.length
    }

  # remove all individual capabilities that have already been included in one or more capability groups
  # replace them with the capability group id
    groups.each do |g|
      capabilities -= g.capabilities
      capabilities << g.id
    end

    return capabilities
  end

  # def to_hash
  #   rv = super
  #   rv[:groups] = groups() unless groups().empty?
  #   rv[:capabilities] = capabilities() unless capabilities().empty?
  #   rv
  # end

  def authenticate!(options={})
    not App::Config.get('global.authentication.prevent')
  end

  def has_capability?(key, args=nil)
    send("capability_#{key}", args)
  # rescue
  #   false
  end

  def token(name)
    return self.tokens[name] if self.tokens.include?(name)

    def generate()
      begin
        require 'securerandom'
        return SecureRandom.hex(32)[0...32]
      rescue LoadError
        pool = [(0..9),('a'..'f')].map{|i| i.to_a}.flatten
        return (0..32).map{ pool[rand(pool.length)] }.join
      end
    end

    i = 0

    while true do
      token = generate()

      if i < 3
        unique = User.urlquery("tokens.key/#{token}").to_a.empty?

        if unique
          if self.tokens.select{|i| i['name'] == name }.empty?
            self.tokens << {
              :name => name,
              :key  => token
            }
            self.save()
            return token
          else
            return self.tokens.select{|i| i['name'] == name }.first['key']
          end
        end

        i += 1
      else
        raise "Cannot generate token, too many duplicates"
      end
    end

    return nil
  end

  class<<self
    def capability(name, &block)
      send :define_method, "capability_#{name}" do |*args|
        if block_given?
          yield name, self, (args.flatten rescue [])
        else
          Capability.user_can?(self.id, name)
        end
      end

      true
    end

    Dir[File.join(ENV['PROJECT_ROOT'],'plugins','*','capabilities','*.rb')].each do |c|
      c = c.sub(File.join(ENV['PROJECT_ROOT'],'plugins',''), '')
      require c.sub(/\.rb$/,'')
    end
  end
end
