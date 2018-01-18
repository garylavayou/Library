%% Logger
% Information that has higher level than the logger's Level will be logged.
%
% Logger should not replace the 'error' and 'warning' function, which could trigger
% exceptions, while Logger only record information and should not inluence the program
% execution.
classdef Logger < handle
    
    properties
        Level LoggingLevel = LoggingLevel.Error;
    end
    
    properties
        output_cache char;
        cache_capacity uint64 = 64*1024;
        file = -1;
    end
    
    methods
        function this = Logger(level, buffer_length)
            if nargin >= 1
                this.Level = level;
            end
            if nargin >= 2 && ~isempty(buffer_length)
                this.cache_capacity = buffer_length;
            end
        end
        
        function delete(this)
            if this.file >= 0
                fclose(this.file);
                this.file = -1;
            end
        end
        
        function Open(this, filename)
            if ~isempty(this.file)
                close(this.file)
            end
            this.file = fopen(filename, 'wt', 'n', 'UTF-8');
        end
        
        function Save(this)
            if isempty(this.file)
                error('%s: unable to save, no log file open.', calledby(0));
            else
                fprintf(this.file, '%s', this.output_cache);
                this.output_cache = '';
            end
        end
        
        function output = Info(this, message)
            if this.Level <= LoggingLevel.Info
                output = this.print(message, LoggingLevel.Info);
            end
        end
        
        function output = Error(this, message)
            if this.Level <= LoggingLevel.Error
                output = this.print(message, LoggingLevel.Error);
            end
        end
        
        function output = Warn(this, message)
            if this.Level <= LoggingLevel.Warning
                output = this.print(message, LoggingLevel.Warning);
            end
        end
        
        function output = Fatal(this, message)
            if this.Level <= LoggingLevel.Fatal
                output = this.print(message, LoggingLevel.Fatal);
            end
        end
        
        function output = Debug(this, message)
            if this.Level <= LoggingLevel.Debug
                output = this.print(message, LoggingLevel.Debug);
            end
        end
        
        function output = Trace(this, message)
            if this.Level <= LoggingLevel.Trace
                output = this.print(message, LoggingLevel.Trace);
            end
        end
        % We have two logging level that are not for logging type, so we do not provide an
        % interface that accept the level argument.
        %         function output = Log(this, message, level)
        %             if this.Level <= level
        %                 message = horzcat(sprintf('%s: ',level.char), message);
        %                 output = this.print(message, level);
        %             end
        %         end
    end
    
    methods (Access=protected)
        function output = print(this, message, level)
            output = horzcat(level.char, ': [', calledby(2), ' ', datestr(now), '] ', ...
                message, newline);
            if nargin <= 2
                disp(output);
            else
                switch level
                    case LoggingLevel.Info
                        cprintf('Text', '%s', output);
                    case LoggingLevel.Trace
                        cprintf('Comments', '%s', output);
                    case LoggingLevel.Debug
                        cprintf('SystemCommands', '%s', output);
                    case LoggingLevel.Warning
                        cprintf('Strings', '%s', output);
                    case LoggingLevel.Error
                        cprintf('Errors', '%s', output);
                    case LoggingLevel.Fatal
                        cprintf('Magenta', '%s', output);
                end
            end
            if ~isempty(this.file)
                this.output_cache = strcat(this.output_cache, output);
                if length(this.output_cache) > this.cache_capacity
                    fprintf(this.file, '%s', this.output_cache(1:this.cache_capacity));
                    this.output_cache = this.output_cache((this.cache_capacity+1):end);
                end
            end
        end
    end
end

