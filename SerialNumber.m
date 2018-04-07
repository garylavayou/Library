%% Serial Number
% After the serial number increases to the maximum value, the generator will rewind. By
% default, this serial number generator will not check the uniqueness of serial number.
% When assert is enabled and the number space is exhausted, an error will occur.
% As long as the space of serial number is large enough, no duplication will occur.
%
classdef SerialNumber < matlab.mixin.Copyable  
    
    properties (Access = private)
        identifier uint64 = uint64(0);
        seq_max uint64 = intmax('uint64');
        b_assert logical = true;
    end
    
    properties (Dependent)
        ID;
    end
    
    methods
        function this = SerialNumber(n, seq_max, enableassert)
            if nargin > 0 && n >= 1 && ~isempty(n)
                this.identifier = uint64(n-1);
            end
            if nargin >= 2 && ~isempty(seq_max)
                this.seq_max = seq_max;
            end
            if nargin >= 3
                this.b_assert = enableassert;
            end
        end
        
        function n = next(this, Nout)
            if nargin == 1 || Nout < 1
                Nout = 1;
            elseif Nout > this.seq_max
                Nout = this.seq_max;
            end
            gap = this.seq_max - this.identifier;
            if gap < Nout
                if this.b_assert
                    error('Math:OutOfRange', 'error: cannot allocate more numbers.');
                end
                n = [(this.identifier+1):this.seq_max, 1:(Nout-gap)]';
                this.identifier(1) = Nout-gap;
            else
                n = (this.identifier+(1:uint64(Nout)))';
                this.identifier = this.identifier+Nout;
            end
        end
        
        function set.ID(this, value)
            if isscalar(value) && value >= 0
                this.identifier = value;
            else
                error("%s: invalid value for sequence number.", calledby)
            end
        end
        
        function n = get.ID(this)
            n = this.identifier;
        end
    end
    % No member is handle class, thus no need to overload CopyElement to deep copy.
end

%%
% *ordered sequece number*
% newly drwan number must be the largest one.
% tail is the last one used, head is the first one used. When |tail==head| there is only
% one elements in the sequence. |tail| may be smaller than |head|, when the generator is
% rewinded.
% head = 1, tail = 1;
% b_empty = true;
% function number = draw(head,tail,SEQ_MAX)
% if head <= tail
%     if tail == SEQ_MAX
%         if head == 1
%             % search between [head, tail] to find a available number.
%             % if order must be maintained, this operation is not allowed.
%             return;
%         else
%             % rewind
%             tail = 1;
%         end
%     else
%         tail = tail + 1;
%     end
% elseif head > tail
%     if head == tail + 1
%         % search between [head, SEQ_MAX] & [1, tail-1];
%         % if order must be maintained, this operation is not allowed.
%         return;
%     else
%         tail = tail + 1;
%     end
% else
%     if b_emmpty        % initial state.
%         b_empty = false;
%     else
%         if tail == SEQ_MAX
%             % rewind
%             tail = 1;
%         else
%             tail = tail + 1;
%         end
%     end
% end
% number = tail;
% pool(end+1) = number;
% end
% 
% function release(i, head, tail, SEQ_MAX)
% idx = find(pool==i)
% state(idx) = [];
% if i == head
%     if head == tail
%         b_empty = true;
%     elseif head == SEQ_MAX
%         head = 1;
%     else
%         head = head + 1;
%     end
% elseif i==tail
%     if tail == 1
%         tail = SEQ_MAX
%     else
%         tail = tail - 1;
%     end
% end
% end

%% un-ordered sequence
% find any available number
function number = draw(pool,n,SEQ_MAX)
j = 1;
t = 1;
number = zeros(n,1);
for i = 1:SEQ_MAX
    if i ~= pool(j) 
        number(t) = i;
        pool = [pool(1:j-1) i pool(j:end)];
        t = t + 1;
        if t == n
            break;
        end
    end    
end
if t ~= n
    error('available numbers are not enough');
end
end
function release(pool, i)
idx = pool==i;
pool(idx) = [];
end