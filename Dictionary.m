classdef Dictionary < matlab.mixin.Copyable
	%UNTITLED3 Summary of this class goes here
	%   Dictionary based on struct is not efficient, since the memeber access methods still
	%   require to copy the data storage.
	%
	% See also <containers.Map>
	properties
		data = struct;
	end
	
	properties (Dependent)
		Keys;
		Values;
	end
	
	
	%% Constructor
	%
	%		this = Dictionary()
	%		this = Dictionary(dict)
	%				Copy the content of |dict| into the new object. 
	%				Note that this is a shallow copy. If the object |dict| has fields of handle
	%				type, the caller need to deal with the deep copy issue.
	%		this = Dictionary(st)
	%				Use the struct |st| to initialize the new object.
	%		this = Dictionary('field', value, ...)
	%				
	methods 
		function this = Dictionary(varargin)
			if nargin == 0
				return;
			elseif nargin == 1 
				if isstruct(varargin{1})
					this.data = varargin{1};
				elseif isa(varargin{1}, 'Dictionary')
					this.data = varargin{1}.data;
				else
					error('error: unknown initializing data.');
				end
			elseif nargin >= 2
				this.data = struct(varargin{:});
				if ~isscalar(this.data)
					error('error: input cell data should be packed in a single cell.');
				end
			else
				error('error: cannot create dictionary with input arguments.');
			end
		end
	end
	
	methods
		function keys = get.Keys(this)
			keys = fieldnames(this.data);
		end
		
		function values = get.Values(this)
			keys = this.Keys;
			values = cell(size(keys));
			for i = 1:length(keys)
				values{i} = this.data.(keys{i});
			end
		end
		
		%%
		% Called by matlab editor to display information.
		% Matlab editor first call <isempty> to determine if the object is empty. If empty, it
		% calculates the dimensions of the object, and outputs
		%			dict: empty MxNx... Dictionary.
		% Otherwise, it also calls the <disp> methods to display the content information,
		% i.e.,
		%			dict: MxNx... Dictionary = 
		%								 Name: value
		%					AnotherName: value2
		function disp(this)
			if builtin('isempty', this) || ~isscalar(this)
			elseif isempty(this.Keys)
				fprintf('  <a href="matlab:helpPopup %s" style="font-weight:bold">%s</a> with no key-value pairs.\n', ...
					class(this), class(this));
			else
				disp(this.data);
			end
		end
		
		function display(this) %#ok<DISPLAY>
			fprintf('\n%s = \n\n  ', inputname(1));
			if builtin('isempty', this) 
				dims = join(string(num2str((size(this))')).strip(), 'x');
				fprintf('%s empty <a href="matlab:helpPopup %s" style="font-weight:bold">%s</a>.\n\n', ...
					dims, class(this), class(this));				
			elseif ~isscalar(this)
				dims = join(string(num2str((size(this))')).strip(), 'x');
				fprintf('%s <a href="matlab:helpPopup %s" style="font-weight:bold">%s</a>.\n\n', ...
					dims, class(this), class(this));				
			elseif ~isempty(this.Keys)
				fprintf('<a href="matlab:helpPopup %s" style="font-weight:bold">%s</a> with key-value pairs:\n\n', ...
					class(this), class(this));
			end
			disp(this);
		end
		
		function tf = isempty(this)
			if builtin('isempty', this)
				tf = true;
			elseif isscalar(this) && isempty(this.Keys)
				tf = true;
			else
				tf = false;
			end
		end
		
		% Test if empty fields exist.
		function tf = isValid(this, fields)
			if nargin <= 1
				fields = this.Keys;
			end
			for i = 1:length(fields)
				if ~isfield(this.data, fields{i})
					tf = false;
					return;
				end
				if isempty(this.data.(fields{i}))
					tf = false;
					return;
				end
			end
			tf = true;
		end
		
	end
	
	methods
		function varargout = subsref(this, s)
			if builtin('isempty', this)
				error('error: Dictionary object is not created.');
			end
			switch s(1).type
				case '.'
					if isprop(this, s(1).subs) || ismethod(this, s(1).subs)
						assertpermission('Dictionary', s(1).subs, 'get');
						try 
							varargout = {builtin('subsref', this, s)};
						catch me
							if isequal(me.identifier, 'MATLAB:maxlhs')
								varargout = {};
								builtin('subsref', this, s);
							else
								rethrow(me);
							end
						end
					elseif isfield(this.data, s(1).subs)
						if length(s) > 1
							%% If a field is a Dictionary, then it still calls to the user-defined method
							varargout = {subsref(this.data.(s(1).subs), s(2:end))};
						else
							varargout{1} = this.data.(s(1).subs);
						end
					else
						throw(MException('Library:Dictionary:nofield', ...
							'field ''%s'' not in Dictionary.', s(1).subs));
					end
				case '()'
					st = builtin('subsref', this, s(1));
					if length(s) > 1
						try 
							varargout = {subsref(st, s(2:end))};
						catch me
							if isequal(me.identifier, 'MATLAB:maxlhs')
								varargout = {};
								subsref(st, s(2:end));
							else
								rethrow(me);
							end
						end
					else
						varargout{1} = st;
					end
				otherwise
					try 
						varargout = {builtin('subsref', this, s)};
					catch me
						if isequal(me.identifier, 'MATLAB:maxlhs')
							varargout = {};
							builtin('subsref', this, s);
						else
							rethrow(me);
						end
					end
			end
		end
		
		function this = subsasgn(this, s, v)
			switch s(1).type
				case '.'
					if isprop(this, s(1).subs)
						assertpermission('Dictionary', s(1).subs, 'set');
						this = builtin('subsasgn', this, s, v);
					elseif ischar(s(1).subs)
						try
							if length(s) > 1
								if isequal(s(2).type, '.')
									if isfield(this, s(1).subs)
										st = this.data.(s(1).subs);
									else
										st = struct;
									end
									v = subsasgn(st, s(2:end), v); 
								else
									v = subsasgn(this.data.(s(1).subs), s(2:end), v);
								end
							end
							this.data.(s(1).subs) = v;
						catch e
							rethrow(e);
						end
					else
						error('un-known operation.');
					end
				case '()'
					if length(s) == 1
						if isempty(this)
							this = Dictionary();
						end
						this = builtin('subsasgn', this, s, v);
					else
						st = builtin('subsref', this, s(1));
						st = subsasgn(st, s(2:end), v);
						this = builtin('subsasgn', this, s(1), st);
					end
				otherwise
					this = builtin('subsasgn', this, s, v);
			end
		end
		
		function tf = isfield(this, field)
			tf = isfield(this.data, field);
		end
		
		function value = getfield(this, field)
      % cmd_path = fullfile(matlabroot, '\toolbox\matlab\datatypes');
      % old_path = cd(cmd_path);
			% value = builtin('getfield', this.data, field);
      value = getfield(this.data, field); %#ok<GFLD>  
      % cd(old_path);
		end
		
		function this = rmfield(this, field)
      this.data = rmfield(this.data, field);   % rmfield for structure
		end
		
		function this = rmstructfields(this, rm_fields)
			this.data = rmstructfields(this.data, rm_fields);
		end
		
		function names = fieldnames(this)
			names = fieldnames(this.data);
		end
		
		function this = erase(this)
			this.data = struct;
		end
	end
end


% classdef Dictionary < handle
% 	%UNTITLED2 Summary of this class goes here
% 	%   Detailed explanation goes here
% 	
% 	properties (Access = private)
% 		Keys;
% 		Values;
% 		default_value = 0;
% 	end
% 	
% 	properties (Dependent)
% 		Count;
% 	end
% 	
% 	methods
% 		function obj = Dictionary(keys, values, default_value)
% 			obj.Keys = cell(0);
% 			obj.Values = cell(0);
% 			if nargin >= 3
% 				obj.default_value = default_value;
% 			end
% 			if nargin >= 2
% 				if isnumeric(values)
% 					values = num2cell(values);
% 				end
% 			else
% 				values = cell(0);
% 			end
% 			if nargin >= 1
% 				for i = 1:length(keys)
% 					key = keys{i};
% 					if length(values) >= i
% 						value = values{i};
% 					else
% 						value = [];
% 					end
% 					this.Add(key, value);
% 				end
% 			end
% 			
% 		end
% 		
% 		function Add(this, key, value)
% 			if isstring(key)
% 				key = key.char;
% 			end
% 			if isempty(value)
% 				value = this.default_value;
% 			end
% 			b_match = false;
% 			for i = 1:this.Count
% 				if isequal(this.Keys{i}, key)
% 					b_match = true;
% 					this.Values{i} = value;
% 				end
% 			end
% 			if ~b_match
% 				this.Keys{end+1} = key;
% 				this.Values{this.Count} = value;
% 			end
% 		end
% 		function Set(this, key, value)
% 			this.Add(key,value);
% 		end
% 		
% 		function v = Get(this, key)
% 			if isstring(key)
% 				key = key.char;
% 			end
% 			v = [];
% 			for i = 1:this.Count
% 				if isequal(this.Keys{i}, key)
% 					v = this.Values{i};
% 					break;
% 				end
% 			end
% 		end
% 		
% 		function varargout = subsref(this, s)
% 			switch s(1).type
% 				case '.'
% 					member = s(1).subs;
% 					assertpermission('Dictionary', member, 'get');
% 					if nargout == 0
% 						builtin('subsref',this,s);
% 						varargout = cell(0);
% 					else
% 						varargout = {builtin('subsref',this,s)};
% 					end
% 				case '{}'
% 					key = s(1).subs;
% 					if length(key) > 1
% 						error('error: only accept one key.');
% 					elseif ~isstring(key{1}) && ~ischar(key{1})
% 						error('error: the key should be string or char array.');
% 					else
% 						varargout{1} = this.Get(key{1});
% 					end
% 				otherwise
% 					error('error: Invalid operation.');
% 			end
% 		end
% 		
% 		function this = subsasgn(this, s, v)
% 			switch s(1).type
% 				case '{}'
% 					key = s(1).subs;
% 					if length(key) > 1
% 						error('error: only accept one key.');
% 					elseif ~isstring(key{1}) && ~ischar(key{1})
% 						error('error: the key should be string or char array.');
% 					else
% 						this.Add(key{1}, v);
% 					end
% 				otherwise
% 					this = {builtin('subsasgn',this,s,v)};
% 			end
% 		end
% 		
% 		%%% See also <ListArray>.
% 		function n = numArgumentsFromSubscript(this,s,indexingContext) %#ok<INUSL>
% 			switch indexingContext
% 				case matlab.mixin.util.IndexingContext.Statement
% 					n = 0;
% 				case matlab.mixin.util.IndexingContext.Expression
% 					n = 1; 
% 				case matlab.mixin.util.IndexingContext.Assignment
% 					n = 1; 
% 			end
% 		end
% 		
% 		function Remove(this, key)
% 			for i = 1:this.Count
% 				if isequal(this.Keys{i}, key)
% 					this.Values(i) = [];
% 					this.Keys(i) = [];
% 					break;
% 				end
% 			end
% 		end
% 		
% 		function n = get.Count(this)
% 			n = length(this.Keys);
% 		end
% 	end
% end


