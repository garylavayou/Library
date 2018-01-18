classdef LoggingLevel < uint32    
    % All and Off are used to set the logging level, not a specific logging type.
    enumeration
        All(0),
        Trace(1),
        Debug(2),
        Warning(3),
        Info(4),
        Error(5),
        Fatal(6),
        Off(7)
    end
    
end

