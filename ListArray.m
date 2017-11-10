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
    
    properties (GetAccess={?ListArray, ?PriorityQueue})
        % |storage_class| is initialized in the constructor, should not be changed after
        % initialization  
        storage_class;
        st_length = 0;
        storage;
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
                warning('ListArray is initiialized with specifed type (default double).');
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
        
        function ind = end(this,~,~)
            ind = this.st_length;
        end
        
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
                    member = s(1).subs;
                    %disp(nargout);
                    if isprop(list, member)
                        % check the access permission
                        assertpermission('ListArray', member, 'get');
                        % further access is normal for properties.
                        if length(s) == 1
                            varargout = {builtin('subsref',list,s)};
                        else
                            temp = list.(member);
                            varargout = {builtin('subsref',temp, s(2:end))};
                        end
                    elseif ismember(member, {list.storage_class.PropertyList(:).Name})
                        % memeber is a data property 
                        if list.st_length == 0
                            varargout{1} = [];
                        else
                            if length(s) == 1
                                idx = 1:list.st_length;
%                                 varargout{1} = this.storage(1).(member).empty;
%                                 for i = 1:this.st_length
%                                     varargout{1}(i) = this.storage(i).(member);
%                                 end
                            elseif length(s) == 2 && strcmp(s(2).type, '()')
                                % temp = [this.storage.(member)];
                                % builtin('subsref', temp, s(2:end));
                                idx = list.assertindex(s(2).subs{:});
                            else
                                op = '';
                                for i = 1:length(s)
                                    op = strcat(op, s(i).type);
                                end
                                error('error: unsupported operation %s%s for ListArray.', op);
                            end
                            if ischar(list.storage(1).(member))
                                varargout{1} = {list.storage(idx).(member)};
                            else
                                varargout{1} = [list.storage(idx).(member)];
                            end
                        end
                    else
                        % Due to that we cannot recognize a non-public method, we handle
                        % all methods with other possible cases together.
                        assertpermission('ListArray', member, 'get');
                        if nargout == 0
                            builtin('subsref',list,s);
                            varargout = cell(0);
                        else
                            varargout = {builtin('subsref',list,s)};
                        end
%                         try
%                             varargout = {builtin('subsref',this,s)};
%                         catch ME
%                             switch ME.identifier
%                                 case 'MATLAB:maxlhs'
%                                     varargout = cell(0);
%                                     builtin('subsref',this,s);
%                                 otherwise
%                                     ME.rethrow;
%                             end
%                         end
                    end
                case '()'
                    indices = s(1).subs;
                    if length(indices) == 1
                        idx = list.assertindex(indices{1});
                        elements = list.storage(idx);
                    else
                        error('error: Multiple indices are not supported.');
                    end
                    if length(s) == 1
                        varargout{1} = elements;
                    elseif length(s) >= 2
                        if ismember(s(2).subs, {list.storage_class.PropertyList(:).Name})
                            subs = s(2).subs;
                            for i=3:length(s)
                                subs = strcat(subs, '.', s(i).subs);
                            end
                            output = {elements.(subs)};
                            
                            % cannot use subref for elements, which only return one
                            % value for the first element.
                            %    output = builtin('subsref',elements,s(2:end));
                            %    output = {subsref(elements,s(2:end))};
                            if isempty(output)
                                varargout{1} = output;
                            elseif ischar(output{1})
                                varargout{1} = output;
                            else
                                varargout{1} = [output{:}];
                            end
                        else % methods
                            nout = numel(elements);
                            varargout{nout} = [];
                            for i = 1:nout
                                output = {subsref(elements,s(2:end))};
                                if isempty(output)
                                    varargout{1} = output;
                                elseif ischar(output{1})
                                    varargout{i} = output;
                                else
                                    varargout{i} = [output{:}];
                                end
                            end
                        end
                    else
                        error('error: Invalid operation.');
                    end
                    %                     else
                    %                         varargout = {builtin('subsref',this,s)};
                    %                     end
                case '{}'
                    % TODO, to support Obj{'propName'} to return property of all the
                    % elements, like the Obj.propName.
                    indices = s(1).subs;
                    if length(indices) == 1
                        idx = list.assertindex(indices{1});
                        elements = list.storage(idx);
                    else
                        error('error: Multiple indices are not supported.');
                    end
                    if length(s) == 1
                        varargout{1} = cell(length(elements),1);
                        for i = 1:length(elements)
                            varargout{1}{i} = elements(i);
                        end
                    else
                        error('error: operation %s is not supported.', s(2).type);
                    end
                otherwise
                    error('error: operation %s is not supported.', s(1).type);
            end
        end
        
        function list = subsasgn(list, s, v)
            switch s(1).type
                case '.'
                    assertpermission('ListArray', s(1).subs, 'set');
                    list = builtin('subsasgn',list,s,v);
                case '()'  % v is cell array
                    % Presume that at least one subscription should be provided.
                    indices = s(1).subs;
                    if length(s) == 1
                        if length(indices) == 1
                            idx = list.assertindex(indices{1});
                            if isempty(v)
                                list.Remove(idx);
                            else
                                list.storage(idx) = v(1:length(idx));
                            end
                        else
                            builtin('subsasgn',list,s,v);
                        end
                    elseif length(s) == 2 &&  isequal(s(2).type, '.')
                        % If a method name is passed in, an error will be thorwn out.
                        assertpermission(list.storage_class.Name, s(2).subs, 'set')
                        idx = list.assertindex(indices{1});
                        for i = 1:length(idx)
                            %% ISSUE
                            % ListArray has no access permission to the storage's private/protected
                            % member, even if the caller have permission. To solve this problem, the
                            % caller should first retrive the elements in the ListArray, then
                            % directly access the elements' member.
                            list.storage(idx(i)).(s(2).subs) = v(i);
                        end
                    else
                        builtin('subsasgn',list,s,v);
                    end
                otherwise
                    error('error: operation %s is not supported.', s(1).type);
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
        function Insert(this, value, index)    
            value = ListArray.ASSERTCOPY(value);
            n_add = numel(value);
            this.storage((index+n_add):(end+n_add)) = this.storage(index:end);
            this.storage(index+(0:(n_add-1))) = value; 
            this.st_length = this.st_length + n_add;
        end
        
%         function Merge(this, obj)
%             if ~strcmp(this.TypeName, obj.TypeName)
%             end
%         end
        
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
        
        function idx = Find(this, varargin)
            idx = [];
            if length(varargin)==1 && isa(varargin{1}, this.storage_class.Name)
                elem = varargin{1};
                for i = 1:this.st_length
                    if this.storage(i) == elem || isequal(this.storage(i), elem)
                        idx = i;
                        break;
                    end
                end
            elseif length(varargin)==2 && ischar(varargin{1})
                field = varargin{1};
                value = varargin{2};
                for i = 1:this.st_length
                    if this.storage(i).(field) == value
                        idx = i;
                        break;
                    end
                end
            else
                error('error: invalid invoking form.');
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
    
    methods(Access={?ListArray, ?PriorityQueue})
        function idx = assertindex(this, indices)
            % indices can be empty.
            if ischar(indices) 
                if isequal(indices, ':')
                    idx = 1:this.st_length;
                    % override end method, so 'end' will not present here.
                    %                 elseif isequal(indices, 'end')
                    %                     idx = this.st_length;
                else
                    error('error: invalid index')
                end
            else
                if islogical(indices)
                    indices = find(indices);
                end
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

