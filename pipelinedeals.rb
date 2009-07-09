require 'rubygems'
require 'activeresource'

# This is debugging code to observe actual HTTP requests being made and response received
# taken from http://www.nfjsone.com/blog/david_bock/2008/10/debugging_activeresource_connections.html

class ActiveResource::Connection
  # Creates new Net::HTTP instance for communication with
  # remote service and resources.
  def http
    http = Net::HTTP.new(@site.host, @site.port)
    http.use_ssl = @site.is_a?(URI::HTTPS)
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl
    http.read_timeout = @timeout if @timeout
    #Here's the addition that allows you to see the output
    http.set_debug_output $stderr
    return http
  end
end

 
module PipelineDeals
   
  PROTOCOL='http'
  REQUEST_URL='sandbox.api.pipelinedeals.com'
  USER='sandbox'
  PASSWORD='sandbox'
  API_KEY='abd56073b33b0a25'
 
  class Base < ActiveResource::Base
     self.site="#{PROTOCOL}://#{REQUEST_URL}/#{API_KEY}/"
     self.user=USER
     self.password=PASSWORD
     
     # Possible find methods for activeresource:
     # .find         => calls find_single => calls element_path, then instantiate record
     # .find(:all)   => calls find_every  => calls instantiate_collection if options[:from] is Symbol
     #                                    => calls custom path, then instantiate_collection if options[:from] is String
     #                                    => calls collection_path, then instantiate_collection if options[:from] is not Symbol or String
     # .find(:first) => calls find_every.first
     # .find(:one)   => calls instantiate_record if options[:from] is Symbol
     #               => calls custom path, then instantiate_record if options[:from] is String
     #               => does nothing and returns nil if options[:from] is not Symbol or String (including if it's left blank)
     
     # needed to take out '.xml' from requests for .find
     # Overriding ActiveResource's code of element_path function
     def self.element_path(id, prefix_options = {}, query_options = nil)
       prefix_options, query_options = split_options(prefix_options) if query_options.nil?
       
       # path to the resource, which we want to access is evaluated in this statement: 
       # This is the way ActiveResource does it, but we don't want the .xml inserted into the url, so we take it out
       # "#{prefix(prefix_options)}#{collection_name}/#{id}.#{format.extension}#{query_string(query_options)}"
       "#{prefix(prefix_options)}#{collection_name}/#{id}#{query_string(query_options)}"
     end
     
     # needed to remove '.xml' from requests for .find(:all) and .find(:first)
     # Overriding ActiveResource's code of collection_path function
     # File active_resource/base.rb, line 313
     def self.collection_path(prefix_options = {}, query_options = nil)
       prefix_options, query_options = split_options(prefix_options) if query_options.nil?
       
       # took out '.#{format.extension}'
       # "#{prefix(prefix_options)}#{collection_name}.#{format.extension}#{query_string(query_options)}"
       "#{prefix(prefix_options)}#{collection_name}#{query_string(query_options)}"
     end
     
     # needed to account for when records are returned as a Hash instead of an Array
     # for requests like .find(:all)
     # Overriding ActiveResource's code of instantiate_collection
     # according to patch for ticket #8798 at the following URL:
     # http://dev.rubyonrails.org/attachment/ticket/8798/8798-patch.txt
     def self.instantiate_collection(collection, prefix_options = {})
       # use to be this one line:
       # collection.collect! { |record| instantiate_record(record, prefix_options) }
       
       # replaced line with this:
       if collection.is_a?(Hash)# && collection.size == 1
         value = collection.values.first
         if value.is_a?(Array)
           value.collect! { |record| instantiate_record(record, prefix_options) }
         else
           [ instantiate_record(value, prefix_options) ]
         end
       else
         collection.collect! { |record| instantiate_record(record, prefix_options) }
       end
     end
     

     
     # needed to patch create method to allow userId to be passed outside of the attributes hash for each object
     # taken from the ideas posted here: http://b.lesseverything.com/2008/10/30/custom-parameters-in-activeresource-create
     # File active_resource/base.rb, line 817
     def self.create(attributes={})
        user_id = attributes.delete(:userId) # deletes userId from hash and stores is as user_id
        user_id = "<userId>#{user_id}</userId>"
        element = self.new(attributes)
        new_xml = element.to_xml
        
        # strips out extraneous xml header info, adds request block and userId to post info
        new_xml = "<request>" + new_xml[new_xml.index("<#{self.element_name}>")..new_xml.size-1] + user_id + "</request>"

        connection.post(collection_path, new_xml, headers) do |response|
           self.id = id_from_response(response)
           load_attributes_from_response(response)
        end
     end
     
     # only added this because it was raising NoMethod Error by calling it above
     # File active_resource/base.rb, line 831
     def self.id_from_response(response)
       response['Location'][/\/([^\/]*?)(\.\w+)?$/, 1]
     end
     
  end
  
  class Admin < Base
     self.site+='admin/'
  end
  
  class Contact < Base
    # make sure to always include user_id with find params
    
    def tags
      Tag.find(:all, :params => {:contact_id => id, :user_id => user_id})
    end
    
    def notes
      Note.find(:all, :params => {:contact_id => id, :user_id => user_id})
    end
    
    def add_tag tag
      raise StandardError, "#{tag} is not a PipelineDeals::Tag" unless tag.kind_of?(PipelineDeals::Tag)
      tag.put(:add_to, :contact_id => id)
    end
    
    def remove_tag tag
      raise StandardError, "#{tag} is not a PipelineDeals::Tag" unless tag.kind_of?(PipelineDeals::Tag)
      tag.put(:remove_from, :contact_id => id)
    end
  end
  
  class Todo < Base
     self.element_name="event"
  end
  
  class LeadSource < Admin
  end
  
  class User < Admin
  end
  
  class Deal < Base
     def conversations
      Conversation.find(:all, :params => {:deal_id => id})
     end
  end
  
  class Note < Base
  end
  
  class Conversation < Base
  end
 
  class Tag < Base
  end
 
end