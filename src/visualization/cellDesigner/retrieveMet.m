function [identifier]=retrieveMet(parsed,lkup)
% Retrieve all the identifiers for a metabolite in the parsed CD model
% structure; there could be multiple identifiers for a metabolite.
%
% USAGE:
%
%    [identifier]=retrieveMet(parsed, lkup)
%
% INPUTS:
%    parsed:         A parsed model structure generated by `parseCD` function.
%    lkup:           A species name
%
% OUTPUT:
%    identifier:    The identifiers of a metabolite used the parsed CD model structure
%
% .. Author: - Longfei Mao Oct/2014

identifier=[];
identifier.name=[];

if nargin<2
    lkup='sa7395';
end

if nargin<1
    parsed=parseRecon2_species;
end
listOfS=parsed.r_info.species;
num=0;
for a=1:length(listOfS)
    if strcmp(listOfS(a,1),lkup)||strcmp(listOfS(a,2),lkup)||strcmp(listOfS(a,3),lkup)   % columns 1 to 3 stores "alien name", column 2 stores "species", column 3 stores "names"'
        num=num+1;
        identifier(num).keywords=lkup;
        identifier(num).speciesAlliens=listOfS{a,1} % speciesAlliens
        if ~isempty(listOfS{a,2})
            identifier(num).species=listOfS(a,2);
        end
        if ~isempty(listOfS{a,3})
            identifier(num).name=listOfS(a,3);
        end
    end
end
