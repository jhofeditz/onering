require 'mongo_mapper'

module App
  module Model
    module Errors
      class ValidationError < Exception; end
    end

    module Utils

    # serialize to a Hash
      def to_h
        serializable_hash.reject{|k,v|
          ['_type'].include?(k)
        }
      end

    # populate the document from a Hash
      def from_h(hash, merge=true)
        if merge
          newhash = to_h
          newhash = newhash.deeper_merge!(hash, {:merge_hash_arrays => true})
        else
          newhash = hash
        end

        newhash.each do |k,v|
          send("#{k}=", v) rescue nil
        end

        self
      end

    # populate the document from a JSON string
      def from_json(json, merge=true)
        json = JSON.parse(json) if json.is_a?(String)
        json = [json] if json.is_a?(Hash)

        json.each do |j|
          from_h(j, merge)
        end

        self
      end

    # save, but throw an error if not valid
      def safe_save
        save or raise Errors::ValidationError, errors.collect{|k,v| v }.join("; ")
      end

    # provide a difference between two documents (useful for audit history)
      def -(other)
        diff = (serializable_hash - other.serializable_hash)
      end


      alias_method :to_hash, :to_h
    end

    class Base
      include MongoMapper::Document
      include Utils

      class<<self
        def find_or_create(ids, init={})
          rv = find(ids)

          if not rv
            [*ids].each do |id|
              i = new({'id' => id})

              i.safe_save
            end

            rv = find(ids)
          end

          rv
        end
      end
    end

    class Embedded
      include MongoMapper::EmbeddedDocument
      include Utils
    end

    module Taggable
      def tag(value)
        [*value].each do |v|
          add_to_set({:tags => v})
        end
        safe_save
        self
      end
    end
  end
end