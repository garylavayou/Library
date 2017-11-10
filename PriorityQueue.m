classdef PriorityQueue < matlab.mixin.Copyable
    %UNTITLED11 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = protected)
        inner_list;
        priority_field;
        sorttype = 'ascend';
    end
    
    properties (Dependent)
        Length;
        Capacity;
        TypeName;
        storage_class;
    end
    
    
    methods
        %% Consturctor
        %   PriorityQueue(type_name, priority, default_capacity);
        %   PriorityQueue(queue);
        % |type_name|: data type specified for PriorityQueue instance.
        % |priority|: specifying the data field of elements used for comparing
        % (|priority.field|), and the sort order (|priority.sorttype|).
        function this = PriorityQueue(varargin)
            if isempty(varargin)
                error('error: must be initiialized with known type.');
            end
            if ischar(varargin{1})
                type_name = varargin{1};
                if length(varargin) >= 2
                    priority = varargin{2};
                else
                    error('error: PriorityQueue must be specified with priority field.');
                end
            else
                this = varargin{1}.copy;
                return;
            end
            if length(varargin) >= 3
                this.inner_list = ListArray(type_name, [], default_capacity);
            else
                this.inner_list = ListArray(type_name);
            end
            
            storage_class = meta.class.fromName(type_name);
            if ~ismember(priority.field, {storage_class.PropertyList.Name})
                error('error: [%] does not exist in %s.', ...
                    priority.field, storage_class.Name);
            end
            this.priority_field = priority.field;
            if isfield(priority, 'sorttype')
                if ~ismember(priority.sorttype, {'ascend', 'descend'})
                    error('error: invalid sort type');
                end
                this.sorttype = priority.sorttype;
            end
        end
        
        function delete(this)
            delete(this.inner_list);
        end
    end
    methods (Access = protected)
        function this = copyElement(list)
            % Make a shallow copy of all properties
            this = copyElement@matlab.mixin.Copyable(list);
            % Make a deep copy of the DeepCp object
            this.inner_list = list.inner_list.copy;
        end
    end

    methods
        function c = get.Capacity(this)
            c = this.inner_list.Capacity;
        end
        
        function l = get.Length(this)
            l = this.inner_list.Length;
        end
        
        function t = get.TypeName(this)
            t = this.inner_list.TypeName;
        end
        
        function c = get.storage_class(this)
            c = this.inner_list.storage_class;
        end
        
        %%%
        % idx: the added element's index in the queue
        % e: the last element of the queue.
        function [idx, e] = PushBack(this, value, insert_opt)
            if nargin < 3
                insert_opt = 'back';
            end
            v = value.(this.priority_field);
            assert(~isempty(v), 'compare field is empty.');
            this.inner_list.Add(value);
            %             ev_t = this.inner_list(:).Time;
            %             ev_tp = this.inner_list(:).Type;
            if this.Length <= 1
                idx = 1;
                if nargout == 2
                    e = this.inner_list(end);
                end
                return;
            end
            b_swap = true;
            if strcmp(insert_opt, 'back')
                for idx = this.Length:-1:2
                    if strcmp(this.sorttype, 'descend')
                        if  v < this.inner_list(idx-1).(this.priority_field)
                            b_swap = false;
                        end
                    else  % 'ascend'
                        if  v > this.inner_list(idx-1).(this.priority_field)
                            b_swap = false;
                        end
                    end
                    if ~b_swap
                        break;
                    end
                end
                if b_swap
                    idx = 1;
                end
            else
                for idx = 1:(this.Length-1)
                    if strcmp(this.sorttype, 'descend')
                        if  v > this.inner_list(idx).(this.priority_field)
                            b_swap = false;
                        end
                    else
                        if  v < this.inner_list(idx).(this.priority_field)
                            b_swap = false;
                        end
                    end
                    if ~b_swap
                        break;
                    end
                end
                %                 if b_swap
                %                     idx = this.Length;
                %                 end
            end
            %% DEBUG - TODO
            % no matter 'back' or 'front', the new item is located at the end of the inner
            % list.
            % |idx| will not be empty, since we have chek it at start
            if idx < this.Length        
                temp = this.inner_list(end);
                this.inner_list((idx+1):end) = this.inner_list(idx:(end-1));
                this.inner_list(idx) = temp;
            end
            if nargout == 2
                e = this.inner_list(end);
            end
        end
        
        function e = PopFront(this)
            if this.Length == 0
                e = [];
            else
                e = this.inner_list.Remove(1);
            end
            
        end
        
        function ind = end(this,~,~)
            ind = this.Length;
        end
        
        function n = numArgumentsFromSubscript(~,~,indexingContext)
            switch indexingContext
                case matlab.mixin.util.IndexingContext.Statement
                    n = 0; % nargout for indexed reference used as statement
                case matlab.mixin.util.IndexingContext.Expression
                    n = 1; % nargout for indexed reference used as function argument
                case matlab.mixin.util.IndexingContext.Assignment
                    n = 1; % nargin for indexed assignment
            end
        end
        
        function varargout = subsref(queue, s)
            switch s(1).type
                case '.'
                    member = s(1).subs;
                    if isprop(queue, member)
                        assertpermission('PriorityQueue', member, 'get');
                        varargout = {builtin('subsref',queue,s)};
                    elseif ismethod(queue, member)
                        assertpermission('PriorityQueue', member, 'get');
                        if nargout == 0
                            builtin('subsref',queue,s);
                            varargout = cell(0);
                        else
                            varargout = {builtin('subsref',queue,s)};
                        end
                    elseif ismember(member, {queue.storage_class.PropertyList(:).Name})
                        if queue.Length == 0
                            varargout{1} = [];
                        else
                            if length(s) == 1
                                idx = 1:queue.Length;
                            elseif length(s) == 2 && strcmp(s(2).type, '()')
                                idx = queue.innder_list.assertindex(s(2).subs{:});
                            else
                                op = '';
                                for i = 1:length(s)
                                    op = strcat(op, s(i).type);
                                end
                                error('error: unsupported operation %s%s for ListArray.', op);
                            end
                            if ischar(queue.inner_list(1).(member))
                                varargout{1} = {queue.inner_list(idx).(member)};
                            else
                                varargout{1} = [queue.inner_list(idx).(member)];
                            end
                        end
                    else
                        error('error: no property or method is matched.');
                    end
                case '()'
                    indices = s(1).subs;
                    if length(indices) == 1
                        idx = queue.inner_list.assertindex(indices{1});
                        elements = queue.inner_list(idx);
                    else
                        error('error: Multiple indices are not supported.');
                    end
                    if length(s) == 1
                        varargout{1} = elements;
                    elseif length(s) >= 2
                        if ismember(s(2).subs, {queue.storage_class.PropertyList(:).Name})
                            if isempty(elements)
                                varargout{1} = [];
                            else
                                subs = s(2).subs;
                                for i=3:length(s)
                                    subs = strcat(subs, '.', s(i).subs);
                                end
                                output = {elements.(subs)};
                                if ischar(output{1})
                                    varargout{1} = output;
                                else
                                    varargout{1} = [output{:}];
                                end
                            end
                        else
                            error('error: No proerty %s for %s.', ...
                                s(2).subs, queue.inner_list.storage_class.Name);
                        end
                    else
                        varargout = {builtin('subsref',queue,s)};
                    end
                otherwise
                    error('error: operation %s is not supported.', s(1).type);
            end
        end
        
        function queue = subsasgn(queue, s, v)
            switch s(1).type
                case '.'
                    queue = builtin('subsasgn',queue,s,v);
                case '()'  % v is cell array
                    if length(s) == 1
                        indices = s(1).subs;
                        if length(indices) == 1
                            if isempty(v)
                                error('error: remove elements form queue is not allowed');
                            else
                                queue.inner_list(indices{1}) = v;
                            end
                        else
                            builtin('subsasgn',queue,s,v);
                        end
                    else
                        builtin('subsasgn',queue,s,v);
                    end
                otherwise
                    error('error: operation %s is not supported.', s(1).type);
            end
        end
        
        function Clear(this)
            this.inner_list.Clear();
        end
        
        function idx = Find(this, varargin)
            idx = this.inner_list.Find(varargin{:});
        end
    end
    
end

