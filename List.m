classdef List < matlab.mixin.Copyable
%%
% NOTE: List store the value-based objects.
% Child Class might ristrict the type of objects.
    properties (SetAccess = immutable)
        DEFAULT_CAPACITY = 1000;
    end   
    
    properties (Dependent = true)
        Capacity;
        Length;
    end
    
    properties (Access = private)
        storage;
        st_length;
    end
    
    methods
        function this = List(value, default_capacity)
            if nargin == 0
                this.storage = cell(this.DEFAULT_CAPACITY,1);
                this.st_length = 0;
            else
                if isa(value, 'List')
                    this = value.copy;
                else
                    this.st_length = numel(value);
                    if isnumeric(value)
                        this.storage(1:this.st_length) = num2cell(value(:));
                    elseif iscell(value)
                        this.storage(1:this.st_length) = value(:);
                    end
                end
                
                if nargin == 2
                    this.DEFAULT_CAPACITY = default_capacity;
                end
                count = ceil(this.Capacity/this.DEFAULT_CAPACITY)*this.DEFAULT_CAPACITY;
                if count > this.Capacity
                    this.storage((this.Capacity+1):count) = cell(count-this.Capacity,1);
                end
            end
        end
        
        function c = get.Capacity(this)
            c = length(this.storage);
        end
        
        function l = get.Length(this)
            l = this.st_length;
        end
        
        %% Overload end method for object indexing
        function ind = end(this,~,~)
            ind = this.st_length;
        end
        %% Issues about subsref and subsasgn
        % # access permission: subsref and subsasgn can access all properties;
        % # number of output arguments of a method;
        function varargout = subsref(this, s)
            switch s(1).type
                case '.'
                    try
                        varargout = {builtin('subsref',this,s)};
                    catch ME
                        switch ME.identifier
                            case 'MATLAB:maxlhs'
                                varargout = cell(0);
                                builtin('subsref',this,s);
                            otherwise
                                ME.rethrow;
                        end
                    end
                case '()'
                    if length(s) == 1
                        indices = s(1).subs;
                        if length(indices) == 1
                            idx = this.assertindex(indices{1});
                            varargout{1} = this.storage(idx);
                        else
                            varargout = {builtin('subsref',this,s)};
                        end
                    else
                        varargout = {builtin('subsref',this,s)};
                    end
                case '{}'
                    if length(s) == 1
                        indices = s(1).subs;
                        if length(indices) == 1
                            idx = this.assertindex(indices{1});
                            n_out = length(idx);
                            varargout = cell(1,n_out);
                            for i = 1:n_out
                                varargout{i} = this.storage{idx(i)};
                            end
                        end
                    else
                        varargout = {builtin('subsref',this,s)};
                    end
                otherwise
                    error('error: operation %s is not supported.', s(1).type);
            end
        end
        
        %%
        % the assignment function can only access existing elements.
        % To add new elements to the list, use Add() method.
        %
        function this = subsasgn(this, s, v)
            % ? how to input variable inargument assignment.
            switch s(1).type
                case '.'
                    this = builtin('subsasgn',this,s,v);
                case '()'  % v is cell array
                    if length(s) == 1
                        indices = s(1).subs;
                        if length(indices) == 1
                            idx = this.assertindex(indices{1});
                            if isempty(v)
                                this.Remove(idx);
                            elseif iscell(v)
                                if length(v) == 1
                                    vi = 1;
                                else
                                    vi = 1:length(v);
                                end
                                % this.storage(i) = [];
                                this.storage(idx) = v(vi);
                            else
                                this.storage{idx} = v(:);
                            end
                        else
                            builtin('subsasgn',this,s,v);
                        end
                    else
                        builtin('subsasgn',this,s,v);
                    end
                case '{}'   % v is class array
                    if length(s) == 1
                        indices = s(1).subs;
                        if length(indices) == 1
                            idx = this.assertindex(indices);
                            if length(v) == 1
                                for i = 1:length(idx)
                                    this.storage{idx(i)} = v;
                                end
                            else
                                for i = 1:length(idx)
                                    this.storage{idx(i)} = v(i);
                                end
                            end
                        else
                            builtin('subsasgn',this,s,v);
                        end
                    else
                        builtin('subsasgn',this,s,v);
                    end
                otherwise
                    error('error: operation %s is not supported.', s(1).type);
            end
        end
    end
    
    methods
        function Add(this, value)
            %% TODO
            % # value is an array, cell.
            this.st_length = this.st_length + 1;
            if this.st_length > this.Capacity
                this.storage(this.Capacity+(1:this.DEFAULT_CAPACITY)) = ...
                    cell(this.DEFAULT_CAPACITY,1);
            end
            this.storage{this.st_length} = value;
        end
        
        function Remove(this, index)
            this.assertindex(index);
            remain_index = setdiff(1:this.st_length, index);
            n_remain = length(remain_index);
            this.storage(1:n_remain) = this.storage(remain_index);
            this.storage((n_remain+1):this.st_length) = {[]};
            this.st_length = n_remain;
            if this.Capacity - this.st_length >= this.DEFAULT_CAPACITY
                cap = ceil(this.st_length/this.DEFAULT_CAPACITY)*this.DEFAULT_CAPACITY;
                this.storage((cap+1):this.Capacity) = [];
            end
        end
        
        function Clear(this)
            this.storage = cell(this.DEFAULT_CAPACITY,1);
            this.st_length = 0;
        end
        
    end
    
    methods (Access = protected)
        function this = copyElement(list)
            % Make a shallow copy of all properties
            this = copyElement@matlab.mixin.Copyable(list);
            % Make a deep copy of the DeepCp object
            for i = 1:this.st_length
                if ishandle(list.storage{i})
                    this.storage{i} = list.storage{i}.copy;
                end
            end
        end
    end
    
    methods (Access = private)
        function idx = assertindex(this, indices)
            if isequal(indices, ':')
                idx = 1:this.st_length;
            else
                if max(indices) > this.Length
                    error('error: Index out of bound.');
                end
                if min(indices) <= 0
                    error('error: negative index.');
                end
                idx = indices;
            end
        end
    end
end

