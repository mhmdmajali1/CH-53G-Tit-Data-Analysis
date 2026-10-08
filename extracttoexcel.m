% json_to_excel.m
%
% Converts a JSON file containing "tests" and "flights" arrays into a
% single, readable Excel file with one sheet per section.
%
% USAGE:
%   1. Edit the two lines below (input_file / output_file) if needed.
%   2. Run in Octave:  octave json_to_excel.m
%   3. Or from the Octave prompt:  json_to_excel("mydata.json", "mydata.xlsx")
%
% It works automatically with whatever fields your JSON entries have —
% you do not need to hardcode column names. Nested values (objects or
% arrays inside an entry) are converted to a readable text form so they
% still fit into a normal Excel cell.

function json_to_excel(input_file, output_file)

  if nargin < 1 || isempty(input_file)
    input_file = "sample.json";
  end
  if nargin < 2 || isempty(output_file)
    [~, name, ~] = fileparts(input_file);
    output_file = [name ".xlsx"];
  end

  pkg load io

  if exist(output_file, "file")
    delete(output_file);
  end

  raw = fileread(input_file);
  data = jsondecode(raw);

  fields = fieldnames(data);
  wrote_any_sheet = false;

  for i = 1:numel(fields)
    section_name = fields{i};
    section_data = data.(section_name);

    if isempty(section_data)
      continue;
    end

    sheet_cells = section_to_sheet(section_data);
    sheet_name = make_sheet_name(section_name);

    xlswrite(output_file, sheet_cells, sheet_name);
    wrote_any_sheet = true;
    printf("Wrote sheet '%s' with %d rows and %d columns\n", ...
           sheet_name, rows(sheet_cells) - 1, columns(sheet_cells));
  end

  if !wrote_any_sheet
    error("No non-empty sections found in %s — nothing to write.", input_file);
  end

  printf("\nDone. Saved to: %s\n", output_file);

end

% ------------------------------------------------------------------
% Turns a section (struct array, single struct, or cell array of
% structs) into a 2D cell array ready for xlswrite: row 1 = headers,
% remaining rows = one entry per row.
% ------------------------------------------------------------------
function sheet_cells = section_to_sheet(section_data)

  % Normalize to a cell array of structs, one per entry.
  if iscell(section_data)
    entries = section_data;
  elseif isstruct(section_data) && numel(section_data) > 1
    entries = num2cell(section_data);
  elseif isstruct(section_data)
    entries = {section_data};
  else
    % Section is not structured (e.g. plain list of strings/numbers)
    entries = num2cell(section_data(:));
    sheet_cells = [{"value"}; entries];
    return;
  end

  % Collect the union of all field names across entries, in first-seen order,
  % in case some entries have extra/missing fields.
  headers = {};
  for k = 1:numel(entries)
    fn = fieldnames(entries{k});
    for j = 1:numel(fn)
      if !any(strcmp(headers, fn{j}))
        headers{end+1} = fn{j};
      end
    end
  end

  n_rows = numel(entries);
  n_cols = numel(headers);
  sheet_cells = cell(n_rows + 1, n_cols);
  sheet_cells(1, :) = headers;

  for r = 1:n_rows
    entry = entries{r};
    for c = 1:n_cols
      col_name = headers{c};
      if isfield(entry, col_name)
        sheet_cells{r+1, c} = to_cell_value(entry.(col_name));
      else
        sheet_cells{r+1, c} = "";
      end
    end
  end

end

% ------------------------------------------------------------------
% Converts any decoded JSON value into something safe to put in one
% Excel cell (a string or a plain number).
% ------------------------------------------------------------------
function v = to_cell_value(val)

  if ischar(val)
    v = val;
  elseif isnumeric(val) && isscalar(val)
    v = val;
  elseif islogical(val) && isscalar(val)
    if val
      v = "true";
    else
      v = "false";
    end
  elseif isempty(val)
    v = "";
  else
    % Struct, array, cell, or anything nested -> readable JSON text
    try
      v = jsonencode(val);
    catch
      v = mat2str(val);
    end
  end

end

% ------------------------------------------------------------------
% Excel sheet names: max 31 chars, capitalized first letter, no
% forbidden characters ( : \ / ? * [ ] ).
% ------------------------------------------------------------------
function name = make_sheet_name(raw_name)

  name = regexprep(raw_name, '[:\\/\?\*\[\]]', "_");
  if numel(name) > 31
    name = name(1:31);
  end
  if numel(name) > 0
    name(1) = upper(name(1));
  end

end
