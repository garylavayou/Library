%% FilterLogger 
% Information that has the same level as the logger's Level will be logged.
classdef FilterLogger < Logger
    
    methods
        function this = FilterLogger(level, buffer_length)
            if nargin<2
                buffer_length = [];
            end
            this@Logger(level, buffer_length);
        end
        
        function output = Info(this, message)
            if this.Level == LoggingLevel.Info
                output = this.print(message, LoggingLevel.Info);
            end
        end
        
        function output = Error(this, message)
            if this.Level == LoggingLevel.Error
                output = this.print(message, LoggingLevel.Error);
            end
        end
        
        function output = Warn(this, message)
            if this.Level == LoggingLevel.Warning
                output = this.print(message, LoggingLevel.Warning);
            end
        end
        
        function output = Fatal(this, message)
            if this.Level == LoggingLevel.Fatal
                output = this.print(message, LoggingLevel.Fatal);
            end
        end
        
        function output = Debug(this, message)
            if this.Level == LoggingLevel.Debug
                output = this.print(message, LoggingLevel.Debug);
            end
        end
        
        function output = Trace(this, message)
            if this.Level == LoggingLevel.Trace
                output = this.print(message, LoggingLevel.Trace);
            end
        end
    end
end

