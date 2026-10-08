function out = getFieldOrEmpty(s, fieldName)
%GETFIELDOREMPTY Return s.(fieldName) if the field exists on struct s,
%   otherwise return []. Guards against "structure has no member ..."
%   errors when a field is entirely absent (not just empty) on some
%   elements of a struct array produced by jsondecode.
    if isfield(s, fieldName)
        out = s.(fieldName);
    else
        out = [];
    end
end
