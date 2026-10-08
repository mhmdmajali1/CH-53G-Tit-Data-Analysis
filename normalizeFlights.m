function flights = normalizeFlights(flights)
    % jsondecode sometimes returns a cell array of structs (instead of a
    % struct array) for Flights, and the structs inside can have
    % different fields. This normalizes them all to the same field set
    % before concatenating, AND guarantees the expected fields always
    % exist even if jsondecode omitted them entirely.

    requiredFields = {'Started', 'Ended', 'ConfigurationUsed', 'BalanceData', 'TrackData'};

    if isempty(flights)
        flights = struct('Started', {}, 'Ended', {}, ...
                          'ConfigurationUsed', {}, 'BalanceData', {});
        return
    end

    if iscell(flights)
        % Collect the union of all field names across every struct in the cell
        allFields = {};
        for idx = 1:numel(flights)
            allFields = [allFields, fieldnames(flights{idx})'];
        end
        allFields = unique([allFields, requiredFields]);

        for idx = 1:numel(flights)
            s = flights{idx};
            for f = 1:numel(allFields)
                fname = allFields{f};
                if ~isfield(s, fname)
                    s.(fname) = [];
                end
            end
            flights{idx} = orderfields(s);
        end

        flights = [flights{:}];
    else
        % Already a struct array, but might be missing required fields entirely
        for f = 1:numel(requiredFields)
            fname = requiredFields{f};
            if ~isfield(flights, fname)
                [flights.(fname)] = deal([]);
            end
        end
    end
end
