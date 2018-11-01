%% ListArray
% Wrapper of object array, with only one dimension, i.e. a list or vector.
% Dynamically increase storage, but the storage will not imediately be returned when
% elements are removed.
% See also <RawList>: use cell array as inner storage; <List>: strict type control
%% TODO
% provide some access function for WapperClasses, such as, <PriortyQueue>
classdef ListArray < matlab.mixin.Copyable
    
    properties (SetAccess = immutable, GetAccess = private)
        DEFAULT_CAPACITY = 1000;
    end
%     properties (Constant)
%         NUMERIC_TYPE = {'single', 'double', 'int8', 'int16', 'int32', 'int64',...
%             'uint8', 'uint16', 'uint32', 'uint64'};
%     end
    
    properties (Access=protected)
        st_length = 0;
				storage;
		end
    
		properties (GetAccess = protected, SetAccess = immutable)
			% |storage_class| is initialized in the constructor, should not be changed after
			% initialization.
			storage_class
		end
		
    properties (Dependent = true)
        Capacity;
        Length;
        TypeName;
    end
    
    methods
        %% Consturctor
        %   ListArray(type_name, value, default_capacity);
        %   ListArray(value, default_capacity);
        %   ListArray(listarray); 
        % |type_name|: data type specified for ListArray instance.
        % |value|: given as object array or ListArray. When |type_name| is given, |value|
        %        must be object array.
        function this = ListArray(varargin)
            if isempty(varargin)
                warning('ListArray is initialized with specifed type (default double).');
            end
            if ischar(varargin{1})
                type_name = varargin{1};
                if length(varargin) >= 2
                    value = varargin{2};
                else 
                    value = [];
                end
                if length(varargin) >= 3
                    this.DEFAULT_CAPACITY = varargin{3};
                end
                this.storage_class = meta.class.fromName(type_name);
            else
                % first argument is value, no type name present
                value = varargin{1};
                if isa(value, 'ListArray')
                    this = value.copy;
                    return;
                end
                if isempty(value)
                    error('error: Input arguments not enough.');
                end
                this.storage_class = metaclass(value);
                if length(varargin) >= 2
                    this.DEFAULT_CAPACITY = varargin{2};
                end                    
            end
            this.storage = creatempty(this.TypeName);
             
            if ~isempty(value)
                this.Add(value);
            end
        end
        
        function delete(this)
            for i = 1:this.st_length
                if ishandle(this.storage(i))
                    delete(this.storage(i));
                end
            end
        end
    end
    methods (Access = protected)
        function this = copyElement(list)
            % Make a shallow copy of all properties
            this = copyElement@matlab.mixin.Copyable(list);
            % Make a deep copy for handle memeber
            if ismember('matlab.mixin.Copyable', superclasses(list.storage))
                for i = 1:this.st_length
                    this.storage(i) = list.storage(i).copy;
                end
            end
        end
        
        function asserttype(this, value)
            ListArray.ASSERTYPE(class(value), this.TypeName);
        end
    end    
    methods
        function c = get.Capacity(this)
            c = length(this.storage);
        end
        
        function l = get.Length(this)
            l = this.st_length;
        end
                
        function t = get.TypeName(this)
            t = this.storage_class.Name;
        end
        
				%         function ind = end(this,~,~)
				%             ind = this.st_length;
				%         end
        
        function n = numArgumentsFromSubscript(this,s,indexingContext) %#ok<INUSL>
            switch indexingContext
                case matlab.mixin.util.IndexingContext.Statement
                    %%% 
                    % nargout for indexed reference used as statement
                    % when calling member functions with no output arguments in |subsref|,
                    % this evaluation will be invoked. Otherwise, the number of output
                    % arguments is determined by the actual output arguments.
                    %
                    % If the object support indexing by '{}', since we treat '{}' the same
                    % as '()', so we only need to have one output arguments. 
                    %    if strcmp(s(1).type, '{}')
                    %        n = 1;
                    %    else
                    %        n = 0;
                    %    end
                    % On the other hand, if we treat '{}' uniquely, we can have multiple
                    % output, as indicated by
                    %    if strcmp(s(1).type, '{}')
                    %        n = numel(s(1).subs);   %%ISSUE
                    %    else
                    %        n = 0;
                    %    end
                    n = 0;
                case matlab.mixin.util.IndexingContext.Expression
                    n = 1; % nargout for indexed reference used as function argument
                case matlab.mixin.util.IndexingContext.Assignment
                    n = 1; % nargin for indexed assignment
            end
        end
        
        %%% Indexing the property of list elements
        % # List.Prop(idx)
        % # List(idx).Prop: is prefered.
        % 
        % |subsref| and |subsasgn| will be invoked when object (array) of this class is
        % indexed by '.', '()' and '{}'. Matlab will pass the object (array) to |subsref|
        % and |subsasgn|. Acessing member methods and properties from the interior of the
        % class by '.', will not invoke these two functions. 
        %
        % |subsref| and |subsasgn| are not member functions inherited from superclass,
        % since the first argument noy only can be the class's instance, but also can be
        % an object array of this class.
        function varargout = subsref(list, s)
					switch s(1).type
						case '.'
							%% Property or Method
							% Format:
							%			v = list.propName;
							%			v = list.methodName;
							%			v = list.methodName(args);
							%					'propName' and 'methodName' are the property and method of the
							%					<ListArray>.
							%					If the list is a vector, the return value must be homogeneous
							%					and concatenatable. Otherwise, the "{}" operator should be
							%					used instead.
							% NOTE: list.('propName') will automatically be converted to list.propName.
							assertpermission('ListArray', s(1).subs, 'get');  % check the access permission
							dims = size(list);
							elements = cell(dims);
							for i = 1:numel(list)
								% Retrive value for each single <ListArray> object, as the property get
								% method or class method does not support the operation for <ListArray>
								% array.
								elements(i) = {builtin('subsref',list(i),s)};
							end
							b_concat = assertcat(elements, true);
						case '()'
							%% Indexing the Array of ListArray
							% Format:
							%			b = list(subs);
							%					return the sub-array of the <ListArray> array.
							%			b = list(subs).propName;
							%			b = list(subs).methodName;
							%					The return value must be homogeneous and concatenatable.
							%					Otherwise, the "{}" operator should be used instead.
							idx = list.assertindex(s(1).subs, '()');		
							%% TODO, support multiple index for ()
							%		subs = {list.assertindex(s(1).subs, '()')};		
							%		l = list(subs{:});
							sub_list = list(idx);
							if length(s) == 1
								varargout{1} = sub_list;
								return;
							elseif ~isequal(s(2).type, '.')
								error('error: only support obj(subs).name operation.');
							end
							% only numeric subscription is supported here for builtin subsref
							assertpermission('ListArray', s(2).subs, 'get')
							dims = size(sub_list);
							elements = cell(dims);
							for i = 1:numel(sub_list)
								elements(i) = {builtin('subsref', sub_list(i), s(2:end))};
							end
							b_concat = assertcat(elements, true);
						case '{}'
							%% Indexing the content of the list array
							% Format:
							%			v = list{subs};
							%			v = list{'propName'}
							%					return property of all the elements, like the Obj.propName.
							%			v = list{subs, 'PropName'};
							%			v = list{subs}.propName;
							%			v = list{subs}.methodName(args);
							%					Return value is a vector if the content of each elements is
							%					numeric scalar; otherwise the return value is a cell array.
							%					list can be a vector of of List Array object.
							%
							%	list should be a scalar ListArray object. If a list object is
							%	non-scalar, the content should be visited via
							%			for i = 1:length(list)
							%				l = list(i);
							%				v = l{subs, 'propName'};
							%			end
							%
							% NOTE: the char string index in {} is enclosed in cell.
							if ~isscalar(list)
								error('error: ''{}'' operation only supported for scalar <ListArray>.');
							end
							if length(s) == 1
								indices = s(1).subs;
								if length(indices) == 1
									idx = list.assertindex(indices, '{}');
									if ischar(idx)
										s = substruct('.', idx);
										idx = 1:list.Length;
									else
										varargout = {reshape(list.storage(idx),size(idx))};
										return;
									end
								elseif length(indices) == 2
									[idx, ~] = list.assertindex(indices, '{}');
									s = substruct('.', indices{2});
								else
									error('error: Too more indices supplied for obj{index, ''propName''}.');
								end
							elseif isequal(s(2).type, '.')
									[idx, ~] = list.assertindex([s(1).subs,s(2).subs], '{}');
									s = s(2:end);
							else
								error('error: operation %s is not supported.', [s.type]);
							end
							assertpermission(list.TypeName, s(1).subs, 'get')
							dims = [numel(idx),1];
							elements = cell(dims);
							for i = 1:numel(idx)
								elements(i) = {builtin('subsref', list.storage(idx(i)), s)};
							end
							b_concat = assertcat(elements);
						otherwise
							error('error: operation %s is not supported.', [s.type]);
					end
					
					varargout{1} = tryconcat(elements, dims, b_concat);
        end
        
        function list = subsasgn(list, s, v)
					s0 = s(1);
					switch s(1).type
						case '.'
							%% Set ListArray Property
							% Format:
							%			list.propName = v;
							sub_list = list;
						case '()'
							%% Modify ListArray and Its Property
							% Format:
							%			list(subs) = v;
							%					return the sub-array of the <ListArray> array.
							%			list(subs).propName = v;
							if isempty(list) || length(s) == 1
								list = builtin('subsasgn', list, s, v);
								return;
							end
							sub_list = list(s(1).subs);   % builtin('subsref', list, s(1));
							s = s(2:end);
						case '{}'
							%% Modify the content of the list array
							% Format:
							%			list{subs} = v;
							%					v is a vector of the storage class.
							%			list{'propName'} = v;
							%					v is a vector or cell array of the propName's type.
							%			list{subs, 'PropName'} = v;
							%			list{subs}.PropName = v;
							%
							% list is a scalar.
							% Access permission should be guaranteed.
							if ~isscalar(list)
								error('error: ''{}'' assign operation only supported for scalar <ListArray>.');
							end
							if length(s) == 1
								indices = s(1).subs;
								if length(indices) == 1
									idx = list.assertindex(indices, '{}');
									if ischar(idx)
										idx = 1:list.Length;
									else
										if isempty(v)
											list.Remove(idx);
										else
											list.storage(idx) = v(1:length(idx));
										end
										return;
									end
								elseif length(indices) == 2
									[idx, ~] = list.assertindex(indices, '{}');
									s = substruct('.', indices{2});
								else
									error('error: Too more indices supplied for obj{index, ''propName''}.');
								end
							elseif isequal(s(2).type, '.')  % certain invalid calling forms will be triggered later.
									[idx, ~] = list.assertindex([s(1).subs,s(2).subs], '{}');
									s = s(2:end);
							else
								error('error: operation %s is not supported.', [s.type]);
							end
						otherwise
							error('error: operation %s is not supported.', [s.type]);
					end
					
					if isscalar(idx)
						v = {v};
					elseif ischar(v) 
						v = {v};
					end
					lenv = length(v);
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
					
					if contains(s0.type, {'.', '()'})
						assertpermission('ListArray', s(1).subs, 'set');
						idx = 1:numel(sub_list);
						for i = 1:numel(idx)
							builtin('subsasgn', sub_list(i), s, val{i});  % list is handle, the value change takes effect
						end
					else
						% If a method name is passed in, an error will be thorwn out.
						assertpermission(list.TypeName, s(1).subs, 'set')
						for i = 1:length(idx)
							list.storage(idx(i)) = builtin('subsasgn', list.storage(idx(i)), s, val{i}); 
							%% Access permission
							% ListArray has no access permission to the storage's private/protected
							% member, even if the caller have permission. To solve this problem, use the
							% builtin <subsasgn> function to bypass the access control.
							%
							%			list.storage(idx(i)).(member) = val{i};
						end
					end
				end
				
    end
    
    methods
        %%
        % Default data pass: directly store the argument value to the container.
        % If |option='copy'|, then handle classes with copy method will create a copyed
        % version of the input argument.
        function value = Add(this, value, option)
            if nargin < 3 || ~strcmpi(option, 'copy')
                option = 'noncopy';
            end
            % The value assign will examine the type compatibility.
            value = ListArray.ASSERTCOPY(value, option);
            n_add = numel(value);
            this.storage(this.st_length+(1:n_add)) = value(:);
            this.st_length = this.st_length + n_add;
        end
        
        %%%
        % insert the value at the specified location.
        function Insert(this, value, index, option)    
            if nargin < 4 || ~strcmpi(option, 'copy')
                option = 'noncopy';
            end
            value = ListArray.ASSERTCOPY(value, option);
            n_add = numel(value);
            this.storage((index+n_add):(end+n_add)) = this.storage(index:end);
            this.storage(index+(0:(n_add-1))) = value; 
            this.st_length = this.st_length + n_add;
        end
        
%         function Merge(this, obj)
%             if ~strcmp(this.TypeName, obj.TypeName)
%             end
%         end
        
				%% Remove
				%		rmobj = Remove(this, index)
				%		rmobj = Remove(this, obj)
				%				Remove from list.
				%		Remove(this, obj)
				%				Remove from list and release the the resource of the element.
        function rmobj = Remove(this, argin)
            if isnumeric(this.storage)
                index = argin;
            else
                if isa(argin, this.storage_class.Name)
                    index = this.Find(argin);
                else
                    index = argin;
                end
            end
            this.assertindex(index);
            %%%
            % the objects are deleted, the handles of these objects are no longer valid.
            if nargout == 1
                rmobj = this.storage(index);
            else
                if ismethod(this.storage, 'delete')
                    for i = index
                        this.storage(i).delete;
                    end
                end
            end
            remain_index = setdiff(1:this.st_length, index);
            n_remain = length(remain_index);
            this.storage(1:n_remain) = this.storage(remain_index);
            % the storage is not released right away.
            % this.storage((n_remain+1):this.st_length) = [];
            this.st_length = n_remain;
            if this.Capacity - this.st_length >= this.DEFAULT_CAPACITY
                cap = ceil(this.st_length/this.DEFAULT_CAPACITY)*this.DEFAULT_CAPACITY;
                this.storage((cap+1):this.Capacity) = [];
            end
        end
        
        function Clear(this)
            this.st_length = 0;
            if this.Capacity - this.st_length >= this.DEFAULT_CAPACITY
                cap = ceil(this.st_length/this.DEFAULT_CAPACITY)*this.DEFAULT_CAPACITY;
                this.storage((cap+1):this.Capacity) = [];
            end
				end
        
				%%
				%   Find(this, field, value)
				%				find the first occurence.
				%		Find(this, field, value, 'all')
				%				find all the occurence.
        function idx = Find(this, varargin)
            if isempty(varargin)
                error('error: missing arguments.');
            end
            if isa(varargin{1}, this.storage_class.Name)
                if length(varargin)>=2 && strcmpi(varargin{2}, 'all')
                    b_all = true;
                    idx = false(this.Length,1);
                else
                    b_all = false;
                    idx = [];
                end
                elem = varargin{1};
                for i = 1:this.st_length
                    if this.storage(i) == elem || isequal(this.storage(i), elem)
                        if b_all
                            idx(i) = true;
                        else
                            idx = i;
                            break;
                        end
                    end
                end
            elseif length(varargin)>=2 && ischar(varargin{1})
                field = varargin{1};
                value = varargin{2};
                if length(varargin)>=3 && strcmpi(varargin{3}, 'all')
                    b_all = true;
                    idx = false(this.Length,1);
                else
                    b_all = false;
                    idx = [];
                end
                for i = 1:this.st_length
                    if this.storage(i).(field) == value
                        if b_all
                            idx(i) = true;
                        else
                            idx = i;
                            break;
                        end
                    end
                end
            else
                error('error: invalid arguments.');
            end
            if b_all
                idx = find(idx);
            end
        end
        
%         function values = get(this, prop)
%             if this.st_length > 0
%                 if ischar(prop)
%                     prop = {prop};
%                 end
%                 n_out = length(prop);
%                 values = cell(n_out, 1);
%                 for k = 1:n_out
%                     values{k} = this.storage(1).(prop{k}).empty;
%                     for i = 1:this.st_length
%                         values{k}(i) = this.storage(i).(prop{k});
%                     end
%                 end
%                 if length(values) == 1
%                     values = values{1};
%                 end
%             else
%                 values = [];
%             end
%         end
    end
    
    methods(Static, Access = protected)
        function value = ASSERTCOPY(value, option)
            if strcmpi(option, 'copy')
                if ismember('matlab.mixin.Copyable', superclass(value))
                    value = value.copy;
                elseif ishandle(value)
                    %%
                    % Some handle objects does not support to creat a copy.
                    % Then we will still use the original input objects
                    warning('not copy a new version to the list (copy method is not implemented).');
                end
            end
        end
        
        %%%
        % Test if types are compatible.
        % |t1| and |t2| must be the same type, or t2 is a superclass of t1
        function ASSERTYPE(ta, tb)
            if ismember(ta, ListArray.NUMERIC_TYPE) && ismember(tb, ListArray.NUMERIC_TYPE)
                return;
            elseif ~strcmp(ta, tb) && ~ismember(tb, superclasses(ta))
                error('error: Type inconsistent');
            end
        end
        %%%
        % Test if value has compatible type.
        function ASSERTVALUE(va, vb)
            if ~strcmp(class(va), class(vb)) && ~ismember(class(vb), superclasses(va))
                error('error: Type inconsistent');
            end
        end
        
    end
    
    methods(Access=protected)
			% verify the subscripts for the operator.
        function varargout = assertindex(this, indices, op)
					if nargin < 3
						op = '{}';
					end
					if ~iscell(indices)
						indices = {indices};
					end
					
					if isequal(op, '{}')
						if length(indices) > 2
							error('error: only need two subscript for ''{}'' operator.');
							end
					elseif isequal(op, '.')
						if length(indices) > 1
							error('error: only need one subscript for ''.'' operator.');
						end
						%% TODO: () can support multiple subscripts.
					end
					
					varargout = cell(1,length(indices));
					for i = 1:length(indices)
						index = indices{i};
						if ischar(index)
							if isequal(index, ':')
								if isequal(op, '{}')
									varargout{i} = 1:this.st_length;
								else
									varargout{i} = 1:numel(this);
								end
								% override end method, so 'end' will not present here.
								%                 elseif isequal(indices, 'end')
								%                     idx = this.st_length;
							else
								if isequal(op, '{}') && ...
										(contains(index, {this.storage_class.PropertyList.Name}) || ...
										contains(index, {this.storage_class.MethodList.Name}))
									% Member name of storage class
									varargout{i} = index;
								elseif isequal(op, '.') && ...
										(isprop(this(1), index) || ismethod(this(1), index))
									varargout{i} = index;
								else
									error('error: invalid subscript <%s> for ''%s'' operator', index, op);
								end
							end
						else
							if isequal(op, '.')
								error('error: the subscript must be char type for ''.'' operator.');
							end
							if islogical(index)
								if (isequal(op, '()') && length(index) ~= numel(this)) ||...
										(isequal(op, '{}') && length(index) ~= numel(this.st_length))
									error('error: inconsistent diemensions between subscript and array.');
								end
								index = find(index);
							end
							if isequal(op, '()') && max(index) > numel(this) ||...
								isequal(op, '{}') && max(index) > this.Length
								error('error: Index out of bound.');
							end
							if min(index) <= 0
								error('error: negative index.');
							end
							varargout{i} = index;             % indices can be empty.
						end
					end
						
					if nargin >=3
						if isequal(op, '{}')  && length(indices) == 2
							if ~isnumeric(varargout{1})
								error('error: the first index should be numeric for obj{index, ''propName''}.');
							end
							if ~ischar(varargout{2})
								error('error: the second index should be char string for obj{index, ''propName''}.');
							end
						end
					end
				
				end
				
    end
end

