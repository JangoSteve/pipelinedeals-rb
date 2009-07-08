require 'rubygems'
require 'activeresource'
 
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