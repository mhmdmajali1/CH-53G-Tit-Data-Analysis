function bd = normalizeBalanceData(bd)
    % jsondecode sometimes returns a cell array instead of a struct array
    % for BalanceData. This forces it into a consistent struct array.
    if iscell(bd)
        if isempty(bd)
            bd = struct('TestCondition', {}, 'Part', {}, 'Axis', {}, ...
                         'Amplitude', {}, 'Phase', {});
        else
            bd = [bd{:}];   % concatenate cell contents into a struct array
        end
    end
end
