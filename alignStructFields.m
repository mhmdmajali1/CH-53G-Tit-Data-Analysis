function [a, b] = alignStructFields(a, b)
    % Ensures struct arrays a and b have the exact same fields,
    % in the exact same order, so they can be concatenated.
    allFields = unique([fieldnames(a); fieldnames(b)]);

    for f = 1:numel(allFields)
        fname = allFields{f};
        if ~isfield(a, fname)
            [a.(fname)] = deal([]);
        end
        if ~isfield(b, fname)
            [b.(fname)] = deal([]);
        end
    end

    a = orderfields(a, allFields);
    b = orderfields(b, allFields);
end
