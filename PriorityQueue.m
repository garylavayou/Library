classdef PriorityQueue < matlab.mixin.Copyable
    %UNTITLED11 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = protected)
        inner_list;
        priority_field;
        sorttype = 'ascend';
		end
		
		properties (Dependent, Access = protected)
			storage;
			storage_class;
		end
    
    properties (Dependent)
        Length;
        Capacity;
        TypeName;
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
										if ~isstruct(priority)
											priority = struct('field', priority);
										end
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
            
            if ~ismember(priority.field, {this.storage_class.PropertyList.Name})
                error('error: [%] does not exist in %s.', priority.field, this.TypeName);
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
            c = meta.class.fromName(this.inner_list.TypeName);
				end
        
				function c = get.storage(this)
					c = this.inner_list{:};
				end
				
        %%%
        % idx: the added element's index in the queue
        % e: the last element of the queue.
        function [idxs, e] = PushBack(this, value)
            v = [value.(this.priority_field)];
            assert(~isempty(v), 'compare field is empty.');
            %             ev_t = this.inner_list(:).Time;
            %             ev_tp = this.inner_list(:).Type;
            if length(v) > 1
                [v,idx_sort] = sort(v, this.sorttype);
                value = value(idx_sort);
            else
                idx_sort = 1;
            end
            old_len = this.Length;
            this.inner_list.Add(value);
            if old_len == 0
                idxs = 1;
                if nargout == 2
                    e = this.inner_list{this.Length};
                end
                return;
            else
                idxs = zeros(length(v),1);
            end
            j = 1;
            for tmp_len = (old_len+1):this.Length
                b_swap = true;
                vt = v(tmp_len-old_len);
                for idx = tmp_len:-1:2
                    if strcmp(this.sorttype, 'descend')
                        if  vt < this.inner_list{idx-1}.(this.priority_field)
                            b_swap = false;
                        end
                    else  % 'ascend'
                        if  vt > this.inner_list{idx-1}.(this.priority_field)
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
                if ~b_swap && idx == tmp_len
                    % no need to exchange, the queue is sorted.
                    idxs(idx_sort(j:end)) = idx:this.Length;
                    break;
                end
                % |idx| will not be empty, since we have chek it at start
                if idx < tmp_len
                    temp = this.inner_list{tmp_len};
                    this.inner_list{(idx+1):tmp_len} = this.inner_list{idx:(tmp_len-1)};
                    this.inner_list{idx} = temp;
                end
                idxs(idx_sort(j)) = idx;
                j = j + 1;
            end
            if nargout == 2
                e = this.inner_list{this.Length};
            end
        end
        
        function [idxs, e] = PushFront(this, value)
            v = [value.(this.priority_field)];
            assert(~isempty(v), 'compare field is empty.');
            %             ev_t = this.inner_list(:).Time;
            %             ev_tp = this.inner_list(:).Type;
            if length(v) > 1
                [v,idx_sort] = sort(v, this.sorttype);
                value = value(idx_sort);
            else
                idx_sort = 1;
            end
            old_len = this.Length;
            this.inner_list.Insert(value, 1);
            if old_len == 0
                idxs = 1;
                if nargout == 2
                    e = this.inner_list{this.Length};
                end
                return;
            else
                idxs = zeros(length(v),1);
            end
            j = length(v);
            for tmp_len = length(v):-1:1
                b_swap = true;
                vt = v(tmp_len);
                for idx = tmp_len:(this.Length-1)
                    if strcmp(this.sorttype, 'descend')
                        if  vt > this.inner_list{idx+1}.(this.priority_field)
                            b_swap = false;
                        end
                    else
                        if  vt < this.inner_list{idx+1}.(this.priority_field)
                            b_swap = false;
                        end
                    end
                    if ~b_swap
                        break;
                    end
                end
                if b_swap  % no exchange, |idx| set to the last element, so the last step will not be executed.
                    idx = this.Length;
                end
                %% DEBUG - TODO
                % |idx| will not be empty, since we have chek it at start
                if ~b_swap && idx == tmp_len
                    idxs(idx_sort(1:j)) = 1:idx;
                    break;
                end
                if idx > tmp_len
                    temp = this.inner_list{tmp_len};
                    this.inner_list{tmp_len:(idx-1)} = this.inner_list{(tmp_len+1):idx};
                    this.inner_list{idx} = temp;
                end
                idxs(idx_sort(j)) = idx;
                j = j + 1;
            end
            if nargout == 2
                e = this.inner_list{this.Length};
            end
        end
        
        function e = PopFront(this)
            if this.Length == 0
                e = [];
            else
                e = this.inner_list.Remove(1);
            end
            
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
        
				%%
				% see also <ListArray>.<subsref>.
				% varargout{1} = {queue.inner_list{idx}.(member)};
        function varargout = subsref(queue, s)
					switch s(1).type
						case '.'
							assertpermission('PriorityQueue', s(1).subs, 'get');
							dims = size(queue);
							elements = cell(dims);
							for i = 1:numel(queue)
								elements(i) = {builtin('subsref',queue(i),s)};
							end
							b_concat = assertcat(elements, true);
							varargout{1} = tryconcat(elements, dims, b_concat);
						case '()'
							sub_queue = queue(s(1).subs{:});
							if length(s) == 1
								varargout{1} = sub_queue;
								return;
							elseif ~isequal(s(2).type, '.')
								error('error: only support obj(subs).name operation.');
							end
							assertpermission('PathList', s(2).subs, 'get');	% check the access permission							
							dims = size(sub_queue);
							elements = cell(dims);
							for i = 1:numel(sub_queue)
								elements(i) = {builtin('subsref', sub_queue(i), s(2:end))};
							end
							b_concat = assertcat(elements, true);
							varargout{1} = tryconcat(elements, dims, b_concat);
						case '{}'
							if ~isscalar(queue)
								error('error: ''{}'' operation only supported for scalar <PriorityQueue>.');
							end
							if length(s) == 1
								if length(s(1).subs) == 1 && ischar(s(1).subs)
									assertpermission(queue.TypeName, s(1).subs, 'get');
								elseif length(s(1).subs) == 2 && ischar(s(1).subs{2})
									assertpermission(queue.TypeName, s(1).subs{2}, 'get');
								end
							else
								assertpermission(queue.TypeName, s(2).subs, 'get');
							end
							varargout = {builtin('subsref', queue.inner_list, s)};							
						otherwise
							error('error: operation %s is not supported.', s(1).type);
					end
					
				end
        
				function queue = subsasgn(queue, s, v)
					switch s(1).type
						case '.'
							sub_queue = queue;
						case '()'  % v is cell array
							if isempty(queue) || length(s) == 1
								queue= builtin('subsasgn', queue, s, v);
								return;
							end
							sub_queue = queue(s(1).subs);
							s = s(2:end);
						case '{}'
							if ~isscalar(queue)
								error('error: ''{}'' operation only supported for scalar <PriorityQueue>.');
							end
							if length(s) == 1
								if length(s(1).subs) == 1 && ischar(s(1).subs)
									assertpermission(queue.TypeName, s(1).subs, 'set');
								elseif length(s(1).subs) == 2 && ischar(s(1).subs{2})
									assertpermission(queue.TypeName, s(1).subs{2}, 'set');
								end
							else
								assertpermission(queue.TypeName, s(2).subs, 'set');
							end
							queue.inner_list = builtin('subsasgn', queue.inner_list, s, v);		
							return;
						otherwise
							error('error: operation %s is not supported.', s(1).type);
					end
					
					assertpermission('PriorityQueue', s(1).subs, 'set');
					idx = 1:numel(sub_queue);
					if ischar(v)
						v = {v};
					end
					lenv = numel(v);
					if lenv~=1 && lenv~=length(idx)
						error('error: the number of required value is inconsistent with the supply.');
					end
					val = cell(size(idx));
					for i = length(idx)
						if isempty(v)
							val{i} = [];
						else
							if iscell(v) || isstring(v)
								val{i} = v{min(lenv, i)};
							else
								val{i} = v(min(lenv, i));
							end
						end
					end
					for i = 1:numel(idx)
						sub_queue(i) = builtin('subsasgn', sub_queue(i), s, val{i});  % queue is handle, the value change takes effect
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

