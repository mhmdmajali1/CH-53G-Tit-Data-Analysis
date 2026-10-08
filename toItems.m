function items = toItems(x)
    % Returns a cell array of individual elements, regardless of whether x
    % is a cell array, a struct array, a scalar struct, or empty.
    % Unlike [x{:}], this NEVER requires matching fields, since it doesn't
    % concatenate anything -- just wraps each element for safe iteration.
    if isempty(x)
        items = {};
    elseif iscell(x)
        items = x;
    else
        n = numel(x);
        items = cell(n, 1);
        for idx = 1:n
            items{idx} = x(idx);
        end
    end
end
