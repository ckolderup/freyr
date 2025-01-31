require 'delegate'

module Freyr
  class ServiceGroup < Array
    extend Forwardable
    service_methods = Service.instance_methods - Class.instance_methods
    def_delegators :first, *service_methods
    
    def find_by_name(n)
      find {|s| s.name == n}
    end
    
    # Take care this can make a stack overflow
    def run
      return [] if empty?
      
      needs_to_run = ServiceGroup.new
      
      kill = false
      names = []
      
      each do |svc|
        
        unless svc.dependencies.empty?
          if n = svc.dependencies.find {|s| !Service.alive?(s)}
            if find_by_name(n)
              needs_to_run << svc
            elsif s = Service[n].first
              needs_to_run << s
              needs_to_run << svc
            else
              puts "Can't run #{svc.name} because dependency #{n} cannot be found"
              kill = true
            end
            
            next
          end
        end
        
        Freyr.logger.debug('starting service') {svc.name}
        pid = svc.start!
        names << svc.name if pid
      end
      
      names += needs_to_run.run unless kill
      names
    end
    
    def stop
      changed_names = collect {|s| s.name if s.alive?}.compact
      each do |svc|
        Freyr.logger.debug('stopping service') {svc.name}
        svc.stop!
      end
      
      changed_names
    end
    
    def restart
      names = collect {|s| s.name}
      
      each do |s|
        Freyr.logger.debug('restart service') {s.name}
        s.restart!
        names.delete(s.name)
      end
      
      names
    end
    
  end
end
