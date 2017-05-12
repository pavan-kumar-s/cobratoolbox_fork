function [parsed_updated]=correctMetName(parsed,cmpM_results,listR)
% Correct the inconsistent species name in the test model (identified by
% the `cmpM` function) according to a reference list of species names.
%
% USAGE:
%
%    [parsed_updated]=correctMetName(parsed, cmpM_results, listR)
%
% INPUTS:
%
%    parsed:            A parsed CD model structure generated by `parseCD` function.
%    cmpM_results:      the output of the `cmpM` function. A list of species names
%                       that are present in the reference model (A COBRA model
%                       structure, but not in the test model (the parsed model
%                       structure of a CD XML file).
%    listR:             A new list of species names that will be used to substitute
%                       the incorrect names (as listed in `listN`)
%
% OUTPUT:
%    parsed_updated:    The corrected CD model structure
%
% EXAMPLE:
%
%    ref_corrected=correctMetName(ref, cmp_recon2map_M.listOfNotFound(:,6), listForCorrection(:,2))
%
% .. Author: - Longfei Mao Oct/2014




col_name=2; % The second column contains a list of identified incorrect metabolites

parsed_updated=parsed;
r_info=parsed.r_info;


r_listN=cmpM_results.listOfNotFound(:,8) % the column 8 contains a list of the row numbers of the species


r_listR=listR;


for n=1:length(r_listR)
    r_info.species(r_listN{n},col_name)=r_listR(n);
end
parsed_updated.r_info=r_info;
