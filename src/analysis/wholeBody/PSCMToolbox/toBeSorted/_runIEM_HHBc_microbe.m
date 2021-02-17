% test multiple BMR's
if set==1
    pathdef;
    addpath(genpath('../../HH_final'))
    addpath(genpath('/home/ines.thiele/P/GitHub/codeBaseHarveyAnalysis'))
    addpath(genpath('/home/ines.thiele/P/GitHub/_cobraHARVEYGenerationONLY'))
    addpath(genpath('/opt/tomlab'))
end

if strcmp(gender,'male')
    % load  Harvey1_0
    load  Harvey_1_01c
    model = male;
    modelO = model;
elseif strcmp(gender,'female')
    % load  Harvetta1_0
    load Harvetta_1_01c
    model = female;
    modelO = model;
elseif strcmp(gender,'Recon3D')
    load Recon3D_Harvey_Used_in_Script_120502
    model = modelConsistent;
    model.rxns = regexprep(model.rxns,'\(e\)','[e]');
    model.rxns = strcat('_',model.rxns);
    model.rxns = regexprep(model.rxns,'_EX_','EX_');
    % add new compartment to Recon
    [model] = createModelNewCompartment(model,'e','u','urine');
    model.rxns = regexprep(model.rxns,'\[e\]_\[u\]','_tr_\[u\]');
    % add exchange reactions for the new [u] metabolites
    U = model.mets(find(~cellfun(@isempty,strfind(model.mets,'[u]'))));
    for i = 1 : length(U)
        model = addExchangeRxn(model,U(i),0,1000);
    end
    
    % create diet reactions
    model.rxns = regexprep(model.rxns,'\[e\]','[d]');
    model.mets = regexprep(model.mets,'\[e\]','[d]');
    EX = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'EX_'))));
    D = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'[d]'))));
    EX_D = intersect(EX,D);
    model.rxns(find(ismember(model.rxns,EX_D))) = strcat('Diet_', model.rxns(find(ismember(model.rxns,EX_D))));
    % apply diet constraints
    model = setDietConstraints(model);
    % only force lower constraints of diet as no fecal outlet
    EX_D = model.rxns(strmatch('Diet_',model.rxns));
    model.ub(find(ismember(model.rxns,EX_D))) = 0;
    model.lb(find(ismember(model.rxns,'Diet_EX_o2[d]'))) = -1000;
    
    model.A = model.S;
    model.rxns(find(ismember(model.rxns,'_biomass_maintenance'))) = {'Whole_body_objective_rxn'};
    model.lb(find(ismember(model.rxns,'Whole_body_objective_rxn'))) = 1;
    model.ub(find(ismember(model.rxns,'Whole_body_objective_rxn'))) = 1;
    modelO = model;
end
cnt = 1;
minRxnsFluxHealthy = 1;%0.9;

%% integrate microbes into HH
% load microbe model
if microbiome == 1
    files = {'SRS011239'};
    if set == 1
        S= load(strcat('/home/ines.thiele/atlas_lcsb_spg/Microbiome/HMP/Run_Almut_17_03_31_with10_new_strains/Results_Setup2/microbiota_model_samp_',files{1},'.mat'));
    else
        S= load(strcat('Y:\Microbiome\HMP\Run_Almut_17_03_31_with10_new_strains\Results_Setup2\microbiota_model_samp_',files{1},'.mat'));
    end
    microbiota_model = S.microbiota_model;
    microbiota_model.rxns = strcat('Micro_',microbiota_model.rxns);
    modelHM = combineHarveyMicrotiota(model,microbiota_model,400);
    
    %tic;[solutionHM_Max,LPProblem]=solveCobraLPCPLEX(microbe_model,1,0,0,[],0,'tomlab_cplex');toc
    
    modelHM = changeRxnBounds(modelHM,'Whole_body_objective_rxn',1,'b');
    modelHMO = modelHM;
    % now set all strains to 0 but 1
    %Bacteroides_thetaiotaomicron_VPI_5482_biomass[c]
    % modelHM.S = modelHM.A;
    % modelHM.S(:,strmatch('communityBiomass',modelHM.rxns))=0;
    % modelHM.S(strmatch('Bacteroides_thetaiotaomicron_VPI_5482_biomass[c]',modelHM.mets),strmatch('communityBiomass',modelHM.rxns))=-1;
    
    % modelHM.S(strmatch('microbiota_LI_biomass[luM]',modelHM.mets),strmatch('communityBiomass',modelHM.rxns))=1;
    % modelHM.A = modelHM.S;
    
    modelHM.lb(find(ismember(modelHM.rxns,'Excretion_EX_microbiota_LI_biomass[fe]')))=0.1; %
    modelHM.ub(find(ismember(modelHM.rxns,'Excretion_EX_microbiota_LI_biomass[fe]')))=1; %
    
    model = modelHM;
end

%% set unified reaction constraints -- they are duplicated again in individual scripts


R = {'_ARGSL';'_GACMTRc';'_FUM';'_FUMm';'_HMR_7698';'_UAG4E';'_UDPG4E';'_GALT'; '_G6PDH2c';'_G6PDH2r';'_G6PDH2rer';...
    '_GLUTCOADHm';'_r0541'; '_ACOAD8m';'_RE2410C';'_RE2410N'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end

%excluded reactions
R2 = {'_FUMt';'_FUMAC';'_FUMS';'BBB'};
RxnsAll4 = '';
for i = 1: length(R2)
    RxnsAll3 = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R2{i}))));
    RxnsAll4 =[RxnsAll4;RxnsAll3];
end
RxnsAll4 = unique(RxnsAll4);
IEMRxns = setdiff(RxnsAll2,RxnsAll4);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_'))))
IEMRxns = setdiff(IEMRxns,RxnMic);
% set ARGSL to be irreversible
model.lb(find(ismember(model.rxns,IEMRxns))) = 0;


R2 = {'_r0784';'_r0463'};
RxnsAll2 = '';
for i = 1: length(R2)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R2{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
X = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_'))))
X = setdiff(X,RxnMic);
model.lb(find(ismember(model.rxns,X))) = 0;
model.ub(find(ismember(model.rxns,X))) = 0;

modelO = model;
%% gene ID: 3034 -Histidinemia HIS
model = modelO;
R = '_HISD';
RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R))));
% exclude _HISDC reactions
RxnsAll2 = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'_HISDC'))));
IEMRxns = setdiff(RxnsAll,RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_'))));
IEMRxns = setdiff(IEMRxns,RxnMic);
if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'hista[bc]');
    model = addDemandReaction(model, 'his_L[bc]');
    model.A = model.S;
    BiomarkerRxns ={'EX_hista[u]'	'Increased (blood/urine)'
        'DM_hista[bc]'	'Increased (blood/urine)'
        'EX_im4ac[u]'	'Increased (urine)'
        'EX_his_L[u]'	'Increased (blood/urine)'
        'DM_his_L[bc]'	'Increased (blood/urine)'
        % 'EX_mhista[u]'	'Increased (urine)' % is not produce in Recon, only consumed, hence not likely to be Increased except the consuming reaction is affected
        };
else
    BiomarkerRxns ={'EX_hista[u]'	'Increased (blood/urine)'
        'EX_im4ac[u]'	'Increased (urine)'
        'EX_his_L[u]'	'Increased (blood/urine)'
        % 'EX_mhista[u]'	'Increased (urine)' % is not produce in Recon, only consumed, hence not likely to be Increased except the consuming reaction is affected
        };
end
[IEMSol_HIS] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% %% gene ID: 2628 % AGAT def
model = modelO;

R = '_GLYAMDTRc';
IEMRxns = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R))));
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);
% set GACMTRc reaction, which converts gudac into creat to irreversible
X = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'_GACMTRc'))));
model.lb(find(ismember(model.rxns,X))) = 0;


BiomarkerRxns = {'EX_creat[u]' 'Decreased (urine)'
    'EX_gudac[u]' 'Decreased (urine)' %
    };

[IEMSol_AGAT] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% %% gene ID: 383 % Arginase def ARG
if 1
    model = modelO;
    
    R = '_ARGN';
    IEMRxns = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R))));
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    % set GACMTRc reaction, which converts gudac into creat to irreversible
    X = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'_GACMTRc'))));
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
X = setdiff(X,RxnMic);
    model.lb(find(ismember(model.rxns,X))) = 0;
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'arg_L[bc]');
        model = addDemandReaction(model, 'creat[bc]');
        model = addDemandReaction(model, 'gudac[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'EX_argsuc[u]' 'Increased (urine)'
            'EX_orot[u]' 'Increased (urine)'
            'EX_ura[u]' 'Increased  (urine)'
            'DM_creat[bc]' 'Increased (blood)'
            'DM_arg_L[bc]' 'Increased (blood)'
            'DM_gudac[bc]' 'Increased (blood)'
            };
    else
        BiomarkerRxns = {
            'EX_argsuc[u]' 'Increased (urine)'
            'EX_orot[u]' 'Increased (urine)'
            'EX_ura[u]' 'Increased  (urine)'
            'EX_creat[u]' 'Increased (blood)'
            'EX_arg_L[u]' 'Increased (blood)'
            'EX_gudac[u]' 'Increased (blood)'
            };
    end
    [IEMSol_ARG] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% %% gene ID: 435
if 0
    model = modelO;
    
    R = '_ARGSL';
    IEMRxns = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R))));
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    % set ARGSL to be irreversible
    model.lb(find(ismember(model.rxns,IEMRxns))) = 0;
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'gln_L[bc]');
        model = addDemandReaction(model, 'citr_L[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'EX_argsuc[u]'	'Increased (urine)'
            'EX_gly[u]'	'Increased (urine)'
            'EX_orot[u]'	'Increased (urine)'
            'EX_lys_L[u]'	'Increased (urine)'
            'EX_ura[u]'	'Increased (urine)'
            'DM_gln_L[bc]'	'Increased (blood)'
            'DM_citr_L[bc]'	'Increased (blood)'
            };
    else
        BiomarkerRxns = {
            'EX_argsuc[u]'	'Increased (urine)'
            'EX_gly[u]'	'Increased (urine)'
            'EX_orot[u]'	'Increased (urine)'
            'EX_lys_L[u]'	'Increased (urine)'
            'EX_ura[u]'	'Increased (urine)'
            'EX_gln_L[u]'	'Increased (blood)'
            'EX_citr_L[u]'	'Increased (blood)'
            };
    end
    [IEMSol_ASA] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end

%% %% gene ID: 1373 % CPS1 'Carbamoyl phosphate synthetase I deficiency'
model = modelO;

R = {'_CBPSam';'_r0034'};
RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{1}))));
RxnsAll2 = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{2}))));
IEMRxns = union(RxnsAll,RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);
if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'gln_L[bc]');
    model = addDemandReaction(model, 'citr_L[bc]');
    model.A = model.S;
    BiomarkerRxns = {'EX_lys_L[u]' 'Increased (urine)'
        'EX_gly[u]' 'Increased (urine)'
        'EX_ura[u]' 'Increased (urine)'
        'EX_5oxpro[u]' 'Increased (urine)'
        'DM_citr_L[bc]' 'Decreased (blood)'
        'DM_gln_L[bc]' 'Increased (blood)'
        };
else
    
    BiomarkerRxns = {'EX_lys_L[u]' 'Increased (urine)'
        'EX_gly[u]' 'Increased (urine)'
        'EX_ura[u]' 'Increased (urine)'
        'EX_5oxpro[u]' 'Increased (urine)'
        'EX_citr_L[u]' 'Decreased (blood)'
        'EX_gln_L[u]' 'Increased (blood)'
        };
end
[IEMSol_CPS1] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% gene ID: 549 % 3MGA 3-Methylglutaconic Aciduria Type I
model = modelO;

R = {'_MGCHrm'};
IEMRxns = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{1}))));
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);
BiomarkerRxns = {'EX_3ivcrn[u]' 'Increased (urine)'
    % 'EX_3mglutac[u]' 'Increased (urine)'
    % 'EX_3mglutr[u]' 'Increased (urine)' % cannot be produced in healthy
    % stae
    };
[IEMSol_3MGA] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% gene ID: 31 % ACAD
if 0
    R = {'_ACAD'};
    IEMRxns = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{1}))));
        RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);
    BiomarkerRxns = {
        };
    [IEMSol_ACAD] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% 95 AMA1 Aminoacylase 1 Deficiency
model = modelO;

R = {'_ACODA';'_RE2640C'};
RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{1}))));
RxnsAll2 = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{2}))));
IEMRxns = union(RxnsAll,RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);

BiomarkerRxns = {%'EX_CE1554[u]'	'Increased (urine)' % not in HH
    %   'EX_C02712[u]'	'Increased (urine)'
    'EX_acglu[u]'	'Increased (urine)'
    'EX_acgly[u]'	'Increased (urine)'
    %  'EX_acile_L[u]'	'Decreased (urine)'% cannot be produced in urine
    %    'EX_acleu_L[u]'	'Increased (urine)'
    % 'EX_acser[u]'	'Increased (urine)' % not in HH
    %   'EX_acthr_L[u]'	'Increased (urine)'
    };
[IEMSol_AMA1] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% 1644 Aromatic L-amino acid decarboxylase deficiency
model = modelO;

R = {'_3HLYTCL';'_3HXKYNDCL';'_5HLTDL';'_5HXKYNDCL';'_LTDCL';'_PHYCBOXL';'_TYRCBOX'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);
if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, '34dhphe[bc]');
    model = addDemandReaction(model, '5htrp[bc]');
    model = addDemandReaction(model, 'adrnl[bc]');
    model = addDemandReaction(model, 'CE2176[bc]');
    model = addDemandReaction(model, 'nrpphr[bc]');
    model.A = model.S;
    BiomarkerRxns = {'EX_34dhphe[u]'	'Increased (urine/blood)'
        'DM_34dhphe[bc]'	'Increased (urine/blood)'
        'EX_5htrp[u]'	'Increased (urine/blood)'
        'DM_5htrp[bc]'	'Increased (urine/blood)'
        'DM_adrnl[bc]'	'Decreased (blood)'
        'EX_dopa[u]'	'Increased (urine)'
        'EX_CE2176[u]'	'Increased (urine/blood)'
        'DM_CE2176[bc]'	'Increased (urine/blood)'
        'DM_nrpphr[bc]'	'Decreased (blood)'
        'EX_3moxtyr[u]'	'Increased (urine)'
        };
else
    
    BiomarkerRxns = {'EX_34dhphe[u]'	'Increased (urine/blood)'
        'EX_5htrp[u]'	'Increased (urine/blood)'
        'EX_adrnl[u]'	'Decreased (blood)'
        'EX_dopa[u]'	'Increased (urine)'
        'EX_CE2176[u]'	'Increased (urine/blood)'
        'EX_nrpphr[u]'	'Decreased (blood)'
        'EX_3moxtyr[u]'	'Increased (urine)'
        };
end

[IEMSol_AADC] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% 1588 FGYN Familial Gynecomastia
% may be only showing in pregnant women
if 0
    model = modelO;
    
    R = {'_3HLYTCL';'_3HXKYNDCL';'_5HLTDL';'5HXKYNDCL';'_LTDCL';'_PHYCBOXL';'_TYRCBOX'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'estradiol[bc]');
        model = addDemandReaction(model, 'tststerone[bc]');
        model.A = model.S;
        BiomarkerRxns = {'DM_estradiol[bc]'	'Decreased (blood)'
            'DM_tststerone[bc]'	'Increased (blood)' %reported in
            };
    else
        BiomarkerRxns = {'EX_estradiol[u]'	'Decreased (blood)'
            'EX_tststerone[u]'	'Increased (blood)' %reported in
            };
    end
    [IEMSol_FGYN] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
    
end
%% 6567 'Aromatase deficiency'

% both transporters are reversible so it is not likely to work except I set
% the organs specifically
if 0
    model = modelO;
    
    R = {'_THYOXt2';'_TRIODTHYt2'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'thyox_L[bc]');
        model.A = model.S;
        BiomarkerRxns = {'DM_thyox_L[bc]'	'Decreased (blood)'
            };
    else
        BiomarkerRxns = {'EX_thyox_L[u]'	'Decreased (blood)'
            };
    end
    
    [IEMSol_AHDS] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end

%% '56922' '3-methylcrotonyl coA carboxylase deficiency'
model = modelO;

R = {'_MCCCrm';'_RE2453M';'_RE2454M'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);

BiomarkerRxns = {'EX_3ivcrn[u]'	'Increased (urine)'
    %   'EX_acac[u]'	'Increased (urine)' % ketone bodies were not mentioned
    %   here: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC1182108/
    %  'EX_acetone[u]'	'Increased (urine)'
    % 'EX_bhb[u]'	'Increased (urine)'
    'EX_CE2026[u]'	'Increased (urine)' % 3-methylcrotonylglycine
    'EX_3hivac[u]'	'Increased (urine)'
    };
[IEMSol_3MCC] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% ''1589'' CYP21D	'21-hydroxylase deficiency'
if 1
    % I skip this IEM as biomarkers are not clear. Additional diseases
    % (e.g., testicular adrenal rest tumor) may be present and thus be
    % reflected in some of the reported biomarker but the additional
    % diseases are not captured by the models.
    model = modelO;
    
    R = {'_P45021A1r';'_P45021A2r';'_RE2155R';'_21HPRGNLONE';'_HMR_1940';'_HMR_1948';'_HMR_1988';'_HMR_1990';'_HMR_1992';'_HMR_2007'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'aldstrn[bc]');
        model = addDemandReaction(model, 'crtsl[bc]');
        model = addDemandReaction(model, 'prgstrn[bc]');
        model = addDemandReaction(model, '17ahprgnlone[bc]');
        model = addDemandReaction(model, '17ahprgstrn[bc]');
        model = addDemandReaction(model, 'M00603[bc]');
        model = addDemandReaction(model, 'andrstndn[bc]');
        model = addDemandReaction(model, 'andrstrn[bc]');
        model = addDemandReaction(model, 'dhea[bc]');
        model = addDemandReaction(model, 'C05284[bc]');
        model = addDemandReaction(model, 'CE2211[bc]');
        model.A = model.S;
        BiomarkerRxns = {'DM_aldstrn[bc]'	'Increased (blood)'%17-Ketotestosterone
            'DM_crtsl[bc]'	'Decreased (blood)' %cortisol
            'DM_prgstrn[bc]'	'Increased (blood)'  %Progesterone
            %  'DM_17ahprgnlone[bc]'	'Increased (blood)'% 17a-Hydroxypregnenolone, not in WBM urine
            %   'DM_17ahprgstrn[bc]'	'Increased (blood)'% 17-Hydroxyprogesterone, not in WBM urine
            %  'DM_M00603[bc]'	'21-Deoxycortisol, Increased (blood)'% not in WBM urine
            'DM_andrstndn[bc]'	'Increased (blood)' %17-Ketotestosterone
            'DM_andrstrn[bc]' 'Increased (blood)' % Androsterone,in male
            'DM_dhea[bc]'	'Increased (blood)' %Dehydroepiandrosterone unchanged in this study: PMID: 28472487
            % 'DM_C05284[bc]' 'Increased (blood)' % 11b-Hydroxyandrost-4-ene-3,17-dione, in male
            %  'DM_CE2211[bc]' 'Increased (blood)' % Allopregnanolone, in male, not in HH
            };
    else
        BiomarkerRxns = {'EX_aldstrn[u]'	'Increased (blood)'%17-Ketotestosterone
            'EX_crtsl[u]'	'Decreased (blood)' %cortisol
            'EX_prgstrn[u]'	'Increased (blood)'  %Progesterone
            % 'EX_17ahprgnlone[u]'	'Increased (blood)'% 17a-Hydroxypregnenolone, not in WBM urine
            % 'EX_17ahprgstrn[u]'	'Increased (blood)'% 17-Hydroxyprogesterone, not in WBM urine
            % 'EX_M00603[u]'	'21-Deoxycortisol, Increased (blood)'% not in WBM urine
            'EX_andrstndn[u]'	'Increased (blood)' %17-Ketotestosterone
            'EX_andrstrn[u]' 'Increased (blood)' % Androsterone,in male
            'EX_dhea[u]'	'Increased (blood)' %Dehydroepiandrosterone unchanged in this study: PMID: 28472487
            %  'EX_C05284[u]' 'Increased (blood)' % 11b-Hydroxyandrost-4-ene-3,17-dione, in male
            %  'EX_CE2211[u]' 'Increased (blood)' % Allopregnanolone, in male, not in HH
            };
    end
    [IEMSol_CYP21D] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '53630.1' Autosomal Dominant Hypercarotenemia And Vitamin A Deficiency
model = modelO;

R = {'_BCDO'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'caro[bc]');
    model.A = model.S;
    BiomarkerRxns = {'DM_caro[bc]'	'Increased (blood)'
        };
else
    BiomarkerRxns = {'EX_caro[u]'	'Increased (blood)'
        };
end
[IEMSol_HYCARO] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '686.1' BTD Biotinidase Deficiency
if 1
    model = modelO;
    
    % the carboxylation of many of these biomarker compounds is
    % biotin-dependent. Hence we cannot predict them correctly as the model
    % does not cover this dependency appropriately.
    % I added the other reactions of the biotin dependent carboxylase
    % however than the ko is lethal
    
    % https://www.nature.com/articles/gim201784: Biochemically, untreated individuals may exhibit
    % metabolic ketoacidosis, lactic acidosis, and/or hyperammonemia.(PMID: 3930841)
    % Other metabolic abnormalities are more variable and may include elevated excretion
    % of 3-hydroxyisovaleric, lactic, and 3-hydroxypropionic acids and 3-methylcrotonylglycine
    % by urine organic acid analysis, as well as mildly elevated 3-hydroxyisovalerylcarnitine
    %(C5-OH) by plasma acylcarnitine analysis.(PMID: 6441143) These metabolic abnormalities are variable,
    % and affected children, whether symptomatic or asymptomatic, do not always
    %exhibit ketoacidosis or organic aciduria.(PMID: 3930841)
    
    R = {'_BTND1';'_BTND1n';'_BTNDe';'_BTNDm';...
        '_ACCOACm';'_ACCOAC';'_PCm';'_MCCCrm';'_RE2453M';'_RE2454M';'_PPCOACm'
        };
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    % % MCCCr may have to be set to irrev
    % X = '_MCCCrm';
    %  X2 = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,X))));
    % model.lb(find(ismember(model.rxns,X2))) = 0;
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'acac[bc]');
        model = addDemandReaction(model, 'acetone[bc]');
        model = addDemandReaction(model, 'bhb[bc]');
        model = addDemandReaction(model, '3ivcrn[bc]');
        model.A = model.S;
        BiomarkerRxns = {'DM_3ivcrn[bc]'	'Normal to Increased (blood)' %https://www.nature.com/articles/gim201784
            'DM_acac[bc]'	'Normal to Increased (blood)'
            'DM_acetone[bc]'	'Normal to Increased (blood)'
            'DM_bhb[bc]'	'Normal to Increased (blood)'
            
            'EX_lac_L[u]'	'Normal to Increased (urine)'
            'EX_nh4[u]'	'Normal to Increased (urine)'
            'EX_3hpp[u]'	'Normal to Increased (urine)'
            'EX_CE2026[u]'	'Normal to Increased (urine)'
            'EX_2mcit[u]'	'Normal to Increased (urine)'
            };
    else
        BiomarkerRxns = {'EX_3ivcrn[u]'	'Normal to Increased (urine)'
            'EX_acac[u]'	'Normal to Increased (blood)'
            'EX_acetone[u]'	'Normal to Increased (blood)'
            'EX_bhb[u]'	'Normal to Increased (blood)'
            'EX_lac_L[u]'	'Normal to Increased (urine)'
            'EX_nh4[u]'	'Normal to Increased (urine)'
            'EX_3hpp[u]'	'Normal to Increased (urine)'
            'EX_CE2026[u]'	'Normal to Increased (urine)'
            'EX_2mcit[u]'	'Normal to Increased (urine)'
            };
    end
    
    [IEMSol_BTD] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy,[],0.25);
    
end
%% '5264.1' CRFD Classic Refsum Disease
if 1
    model = modelO;
    % does not work -- no flux through objective
    R = {'_PHYHx';'_RE3066X'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'phyt[bc]');
        model = addDemandReaction(model, 'prist[bc]');
        model.A = model.S;
        BiomarkerRxns = {'DM_phyt[bc]'   'Increased (blood)'
            'DM_prist[bc]'   'Decreased (blood)'
            };
    else
        
        BiomarkerRxns = {'EX_phyt[u]'   'Increased (blood)'
            'EX_prist[u]'   'Decreased (blood)'
            };
    end
    [IEMSol_CRFD] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end

%% '1538.1' STAR Congenital Lipoid Adrenal Hyperplasia (Clah)/ Star Deficiency
model = modelO;

R = {'_P45011A1m';'_HMR_1928';'_HMR_1929';'_HMR_1932';'_HMR_1934';'_HMR_1935'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'crtsl[bc]');
    model = addDemandReaction(model, 'crtstrn[bc]');
    model = addDemandReaction(model, '17ahprgstrn[bc]');
    model = addDemandReaction(model, 'andrstndn[bc]');
    model = addDemandReaction(model, 'dhea[bc]');
    model = addDemandReaction(model, '11docrtstrn[bc]');
    model.A = model.S;
    BiomarkerRxns = {'DM_crtsl[bc]'	'Decreased (blood)'
        'DM_crtstrn[bc]'	'Decreased (blood)'
        %     'DM_17ahprgstrn[bc]'	'Decreased (blood)'
        'DM_andrstndn[bc]'	'Decreased (blood)'
        'DM_dhea[bc]'	'Decreased (blood)'
        'DM_11docrtstrn[bc]'	'Decreased (blood)'
        };
else
    
    BiomarkerRxns = {'EX_crtsl[u]'	'Decreased (blood)'
        'EX_crtstrn[u]'	'Decreased (blood)'
        % 'EX_17ahprgstrn[u]'	'Decreased (blood)'
        'EX_andrstndn[u]'	'Decreased (blood)'
        'EX_dhea[u]'	'Decreased (blood)'
        'EX_11docrtstrn[u]'	'Decreased (blood)'
        };
end

[IEMSol_STAR] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '1585.1' CMO1 Corticosterone Methyloxidase Type I Deficiency
model = modelO;

R = {'_P45011B21m'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'aldstrn[bc]');
    model = addDemandReaction(model, 'M00429[bc]');
    model.A = model.S;
    BiomarkerRxns = {'DM_aldstrn[bc]'	'Decreased (Not detectable, blood)'
        %  'EX_k[u]'   'Increased (blood)'
        %  'EX_na1[u]'   'Decreased (blood)'
        % 'DM_M00429[bc]'   'Decreased (blood)' % 0 flux both
        };
else
    BiomarkerRxns = {'EX_aldstrn[u]'	'Decreased (Not detectable, blood)'
        %  'EX_k[u]'   'Increased (blood)'
        %  'EX_na1[u]'   'Decreased (blood)'
        %  'EX_M00429[u]'   'Decreased (blood)'
        };
end
[IEMSol_CMO1] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);


%% '6519.1' CYST Cystinuria
if 0
    model = modelO;
    
    R = {'_CYSTSERex';'_SERLYSNaex';'_CYSTALArBATtc';'_CYSTLEUrBATtc';'_ORNALArBATtc';'_ORNLEUrBATtc'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    BiomarkerRxns = {'EX_arg_L[u]'	'Increased'
        'EX_cys_L[u]'	'Increased'
        %'EX_Lcystin[u]'	'Increased'
        'EX_lys_L[u]'	'Increased'
        'EX_orn[u]'	'Increased'
        };
    [IEMSol_CYST] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '1716.1' DGK Deoxyguanosine Kinase Deficiency
if 1
    model = modelO;
    
    R = {'_r0456'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'lac_L[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'DM_lac_L[bc]'	'Increased (blood)'
            };
    else
        
        BiomarkerRxns = {
            'EX_lac_L[u]'	'Increased (blood)'
            };
    end
    [IEMSol_DGK] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '1807.1'DPYR Dihydropyrimidinuria
model = modelO;

R = {'_DHPM2'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);

BiomarkerRxns = {
    'EX_thym[u]'	'Increased (urine)'
    'EX_ura[u]'	'Increased (urine)'
    'EX_56dura[u]'	'Increased (urine)'
    'EX_56dthm[u]'	'Increased (urine)'
    };
[IEMSol_DPYR] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '1806.1'DPD Dihyropyrimidine Dehydrogenase Deficiency
if 0
    model = modelO;
    % the reactions are not necessary for producing these metabolites at all so
    % no impact is expected
    
    R = {'_DURAD';'_DURAD2'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    % make the reactions irreversible towards the backward direction as it is
    % the rate limiting step in pyrimidine catabolism
    model.ub(find(ismember(model.rxns,IEMRxns))) = 0;
    
    BiomarkerRxns = {
        'EX_thym[u]'	'Increased (urine)'
        'EX_ura[u]'	'Increased (urine)'
        };
    [IEMSol_DPD] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy,1 );
end
%% '3931.1'FED Fish-Eye Disease/ Lcat Deficiency
if 1
    % I exclude this IEM due to unclear modeling constraints and biomarkers
    model = modelO;
    
    R = {'_HMR_0634';'_LCAT1e';'_LCAT10e';'_LCAT11e';'_LCAT12e';'_LCAT13e';'_LCAT14e';'_LCAT15e';'_LCAT16e';'_LCAT17e';'_LCAT18e';'_LCAT19e';...
        '_LCAT2e';'_LCAT20e';'_LCAT21e';'_LCAT22e';'_LCAT23e';'_LCAT24e';'_LCAT25e';'_LCAT26e';'_LCAT27e';'_LCAT28e';'_LCAT29e';...
        '_LCAT3e';'_LCAT30e';'_LCAT31e';'_LCAT32e';'_LCAT33e';'_LCAT34e';'_LCAT35e';'_LCAT36e';'_LCAT37e';'_LCAT38e';'_LCAT39e';...
        '_LCAT4e';'_LCAT40e';'_LCAT41e';'_LCAT42e';'_LCAT43e';'_LCAT44e';'_LCAT45e';'_LCAT46e';'_LCAT47e';'_LCAT48e';'_LCAT49e';...
        '_LCAT5e';'_LCAT50e';'_LCAT51e';'_LCAT52e';'_LCAT53e';'_LCAT54e';'_LCAT55e';'_LCAT56e';'_LCAT57e';'_LCAT58e';'_LCAT59e'
        };
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'chsterol[bc]');
        model = addDemandReaction(model, 'tag_hs[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'DM_chsterol[bc]'	'Decreased (blood)' %PMID: 8675648: "showed a highly significant reduction of HDL-cholesterol"
            'DM_tag_hs[bc]'	'Increased (blood)' % PMID: 3141686: "They had fasting hypertriglyceridaemia." We are not modeling fasting condition
            };
    else
        BiomarkerRxns = {
            'EX_chsterol[u]'	'Decreased (blood)' %PMID: 8675648: "showed a highly significant reduction of HDL-cholesterol"
            'EX_tag_hs[u]'	'Increased (blood)' % PMID: 3141686: "They had fasting hypertriglyceridaemia." We are not modeling fasting condition
            };
    end
    [IEMSol_FED] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '3795.1'EF Fructosuria(Essential Fructosuria)
model = modelO;

R = {'_HMR_8761';'_HMR_9800';'_KHK';'_KHK2';'_KHK3'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);

BiomarkerRxns = {
    'EX_fru[u]'	'Increased (urine)'
    };
[IEMSol_EF] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '2271.1'FH Fumarase Deficiency
if 0
    model = modelO;
    
    R = {'_FUM';'_FUMm'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    
    RxnsAll2 = unique(RxnsAll2);
    % exclude reactions
    R2 = {'_FUMt';'_FUMAC';'_FUMS';'BBB'};
    RxnsAll4 = '';
    for i = 1: length(R2)
        RxnsAll3 = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R2{i}))));
        RxnsAll4 =[RxnsAll4;RxnsAll3];
    end
    RxnsAll4 = unique(RxnsAll4);
    IEMRxns = setdiff(RxnsAll2,RxnsAll4);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    model.lb(find(ismember(model.rxns,IEMRxns))) = 0;
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'lac_L[bc]');
        model = addDemandReaction(model, 'nh4[bc]');
        model = addDemandReaction(model, 'fum[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'EX_akg[u]'	'Increased (urine)'
            'EX_cit[u]'	'Increased (urine)'
            'DM_lac_L[bc]'	'Increased (blood)'
            'DM_nh4[bc]'	'Increased (blood)'
            'EX_fum[u]'	'Increased (blood/urine)'
            'DM_fum[bc]'	'Increased (blood/urine)'
            };
    else
        BiomarkerRxns = {
            'EX_akg[u]'	'Increased (urine)'
            'EX_cit[u]'	'Increased (urine)'
            'EX_lac_L[u]'	'Increased (blood)'
            'EX_nh4[u]'	'Increased (blood)'
            'EX_fum[u]'	'Increased (blood/urine)'
            };
    end
    [IEMSol_FH] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '2582.1'GALT3 Galactosemia Type II
if 0
    model = modelO;
    
    R = {'_HMR_7698';'_UAG4E';'_UDPG4E'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    model.lb(find(ismember(model.rxns,IEMRxns))) = 0;
    % set some other reactions to irreversible
    % X = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'_UGLT'))));
    % model.lb(find(ismember(model.rxns,X))) = 0;
    X = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'_GALT'))));
        RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
X = setdiff(X,RxnMic);
    model.lb(find(ismember(model.rxns,X))) = 0;
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'gal[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'DM_gal[bc]'	'Increased (blood)'
            };
    else
        
        BiomarkerRxns = {
            'EX_gal[u]'	'Increased (blood)'
            };
    end
    [IEMSol_GALT3] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '2539.1'G6PD Glucose-6-Phosphate Dehydrogenase Deficiency
if 0
    model = modelO;
    
    R = {'_G6PDH2c';'_G6PDH2r';'_G6PDH2rer'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    model.lb(find(ismember(model.rxns,IEMRxns))) = 0;
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'bilirub[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'DM_bilirub[bc]'	'Increased (blood)'
            };
    else
        
        BiomarkerRxns = {
            'EX_bilirub[u]'	'Increased (blood)'
            };
    end
    [IEMSol_G6PD] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end

%% '6523.1' GGM Glucose-Galactose Malabsorption
if 0 % flux is unlimited through the reactions
    model = modelO;
    
    R = {'_GALSGLT1le';'_GALt2_2'; '_GLCSGLT1le'; '_GLCt2_2'; '_HMR_8877'; '_HMR_8884'; '_UREAt5'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'gal[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'DM_gal[bc]'	'Increased (blood)'
            'EX_glc_D[u]'	'Increased (urine/feces)'
            'Excretion_EX_glc_D[fe]'	'Increased (urine/feces)'
            };
    else
        
        BiomarkerRxns = {
            'EX_gal[u]'	'Increased (blood)'
            'EX_glc_D[u]'	'Increased (urine/feces)'
            };
    end
    [IEMSol_GGM] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end

%% '6513.1' GLUT1 Glut1 Deficiency Syndrome
if 0 %  it is also a transporter
    model = modelO;
    
    R = {'_GLCtg'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    if ~strcmp(gender,'Recon3D')
        BiomarkerRxns = {
            'BBB_GLC_D[CSF]exp'	'Decreased (CSF)'
            'BBB_LAC_L[CSF]exp'	'Decreased (CSF)'
            };
    else
        BiomarkerRxns = {
            'EX_glc_D[u]'	'Decreased (CSF)'
            'EX_lac_L[u]'	'Decreased (CSF)'
            };
    end
    [IEMSol_GLUT1] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '10841.1' FIGLU Glutamate Formiminotransferase Deficiency
model = modelO;

R = {'_FORTHFC';'_GluForTx';'_HMR_9726'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);
%minRxnsFluxHealthy = 1;

BiomarkerRxns = {
    %  'EX_thf[u]'	'Increased (blood)' %it mentions folic acid -- but which form?
    'EX_forglu[u]'  'Increased (urine)'
    };
[IEMSol_FIGLU] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '2639.1' GA1 Glutaric Acidemia Type I.
model = modelO;

R = {'_GLUTCOADHm';'_r0541'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);
model.lb(find(ismember(model.rxns,IEMRxns))) = 0;
if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'c5dc[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        %  'EX_3bcrn[u]'	'Increased (urine)' % I am skeptical about this compound as it is a downstream metabolite of the missing reaction and hence is not likely to accumulate if this enzyme is missing (but if at all it would be depleted)
        'EX_c5dc[u]'	'Increased (blood/urine)'
        'DM_c5dc[bc]'	'Increased (blood/urine)'
        };
else
    BiomarkerRxns = {
        %  'EX_3bcrn[u]'	'Increased (urine)' % I am skeptical about this compound as it is a downstream metabolite of the missing reaction and hence is not likely to accumulate if this enzyme is missing (but if at all it would be depleted)
        'EX_c5dc[u]'	'Increased (blood/urine)'
        };
end
[IEMSol_GA1] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '2108.1' GA2 Glutaric Acidemia Type II
model = modelO;

R = {'_ETF';'_FADH2ETC'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'c10crn[bc]');
    model = addDemandReaction(model, 'c4crn[bc]');
    model = addDemandReaction(model, 'ddeccrn[bc]');
    model = addDemandReaction(model, 'ttdcrn[bc]');
    model = addDemandReaction(model, 'pmtcrn[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'DM_c10crn[bc]'	'Increased (blood)'
        'DM_c4crn[bc]'	'Increased (blood)'
        'DM_ddeccrn[bc]'	'Increased (blood)'
        'DM_ttdcrn[bc]'	'Increased (blood)'
        'DM_pmtcrn[bc]'	'Increased (blood)'
        'EX_4hpro_LT[u]'	'Increased (urine)'
        'EX_pro_L[u]'	'Increased (urine)'
        % 'EX_M00653[u]'	'Increased (urine)'
        'EX_3hivac[u]'	'Increased (urine)'
        'EX_CE4970[u]'	'Increased (urine)'
        %    'EX_4hdxbutn[u]'	'Increased (urine)'
        'EX_CE4969[u]'	'Increased (urine)'
        'EX_CE4968[u]'	'Increased (urine)'
        'EX_ethmalac[u]'	'Increased (urine)'
        'EX_adpac[u]'	'Increased (urine)'
        %'EX_5ohhexa[u]'	'Increased (urine)'
        'EX_subeac[u]'	'Increased (urine)'
        'EX_sebacid[u]'	'Increased (urine)'
        'EX_pro_L[u]'	'Increased (urine)'
        }
else
    BiomarkerRxns = {
        'EX_c10crn[u]'	'Increased (blood)'
        'EX_c4crn[u]'	'Increased (blood)'
        'EX_ddeccrn[u]'	'Increased (blood)'
        'EX_ttdcrn[u]'	'Increased (blood)'
        'EX_pmtcrn[u]'	'Increased (blood)'
        'EX_4hpro_LT[u]'	'Increased (urine)'
        'EX_pro_L[u]'	'Increased (urine)'
        % 'EX_M00653[u]'	'Increased (urine)'
        'EX_3hivac[u]'	'Increased (urine)'
        'EX_CE4970[u]'	'Increased (urine)'
        %    'EX_4hdxbutn[u]'	'Increased (urine)'
        'EX_CE4969[u]'	'Increased (urine)'
        'EX_CE4968[u]'	'Increased (urine)'
        'EX_ethmalac[u]'	'Increased (urine)'
        'EX_adpac[u]'	'Increased (urine)'
        %'EX_5ohhexa[u]'	'Increased (urine)'
        'EX_subeac[u]'	'Increased (urine)'
        'EX_sebacid[u]'	'Increased (urine)'
        'EX_pro_L[u]'	'Increased (urine)'
        }
end
[IEMSol_GA2] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '2937.1' OXOP Glutathione Synthetase Deficiency And 5-Oxoprolinuria
model = modelO;

R = {'_GTHS'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, '5oxpro[bc]');
    model = addDemandReaction(model, 'leuktrE4[bc]');
    model = addDemandReaction(model, 'leuktrC4[bc]');
    model = addDemandReaction(model, 'leuktrD4[bc]');
    model = addDemandReaction(model, 'pro_L[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'EX_5oxpro[u]'	'Increased (urine)'
        'EX_leuktrE4[u]'	'Increased (urine/blood)'
        'EX_leuktrC4[u]'	'Increased (urine/blood)'
        %  'EX_leuktrD4[u]'	'Increased (urine/blood)' % zero in both cases
        'DM_5oxpro[bc]'	'Decreased (blood)'
        'DM_leuktrE4[bc]'	'Increased (urine/blood)'
        'DM_leuktrC4[bc]'	'Increased (urine/blood)'
        'DM_leuktrD4[bc]'	'Increased (urine/blood)'
        'DM_pro_L[bc]'	'Increased (blood)'
        };
else
    
    BiomarkerRxns = {
        'EX_5oxpro[u]'	'Increased (urine)/ Decreased (blood)'
        'EX_leuktrE4[u]'	'Increased (urine/blood)'
        'EX_leuktrC4[u]'	'Increased (urine/blood)'
        'EX_leuktrD4[u]'	'Increased (urine/blood)'
        'EX_pro_L[u]'	'Increased (blood)'
        };
end
[IEMSol_OXOP] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '275.1' NKH Glycine Encephalopathy/ Nonketotic Hyperglycinemia / Nkh
model = modelO;
if 0
    
    R = {'_GCC2am';'_GCC2bim';'_GCC2cm';'_GCCam';'_GCCbim';'_GCCcm';'_r0295';'_r0522'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'gly[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'EX_gly[u]'	'Increased (urine/blood)'
            'DM_gly[bc]'	'Increased (urine/blood)'
            };
    else
        BiomarkerRxns = {
            'EX_gly[u]'	'Increased (urine/blood)'
            };
    end
    
    [IEMSol_NKH] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '178.1'GSD3 Glycogen Storage Disease IIIa/Glycogen Storage Disease IIIb/Cori Disease
if 0
    model = modelO;
    
    R = {'_GLDBRAN';'_r1391';'_r1392'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'chsterol[bc]');
        model = addDemandReaction(model, 'glc_D[bc]');
        model = addDemandReaction(model, 'tag_hs[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'EX_acac[u]'	'Increased (urine)'
            'EX_bhb[u]'	'Increased (urine)'
            'EX_acetone[u]'	'Increased (urine)'
            'DM_chsterol[bc]'	'Increased (blood)'
            'DM_glc_D[bc]'	'Decreased (blood)'
            'DM_tag_hs[bc]'	'Increased (blood)'
            };
    else
        BiomarkerRxns = {
            'EX_acac[u]'	'Increased (urine)'
            'EX_bhb[u]'	'Increased (urine)'
            'EX_chsterol[u]'	'Increased (blood)'
            'EX_acetone[u]'	'Increased (urine)'
            'EX_glc_D[u]'	'Decreased (blood)'
            'EX_tag_hs[u]'	'Increased (blood)'
            };
    end
    [IEMSol_GSD3] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '178.1'GSD6 Glycogen Storage Disease Type 6/Hers Disease
% associated reaction does not carry any flux in healthy condition
if 1
    model = modelO;
    
    R = {'_r1393'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'chsterol[bc]');
        model = addDemandReaction(model, 'glc_D[bc]');
        model = addDemandReaction(model, 'lac_L[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'EX_acac[u]'	'Increased (urine)'
            'EX_acetone[u]'	'Increased (urine)'
            'EX_bhb[u]'	'Increased (urine)'
            'DM_chsterol[bc]'	'Increased (blood)'
            'DM_glc_D[bc]'	'Increased (blood)'
            'DM_lac_L[bc]'	'Increased (blood)'
            };
    else
        BiomarkerRxns = {
            'EX_acac[u]'	'Increased (urine)'
            'EX_acetone[u]'	'Increased (urine)'
            'EX_bhb[u]'	'Increased (urine)'
            'EX_chsterol[u]'	'Increased (blood)'
            'EX_glc_D[u]'	'Increased (blood)'
            'EX_lac_L[u]'	'Increased (blood)'
            };
    end
    [IEMSol_GSD6] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end

%% '2720.1'MPS4B Gm1-Gangliosidosis And Mucopolysaccharidosis Type IV Type B
% healthy model cannot secrete ksi
if 0
    model = modelO;
    
    R = {'_BGAL1e';'_BGAL1l';'_BGAL2l BGAL3l BGAL4l GALASE10ly GALASE11ly GALASE12ly';'_r0737';'_LACZly';'_GALASE13ly';'_GALASE14ly';'_GALASE15ly';'_GALASE16ly';'_GALASE17ly';'_GALASE18ly';'_GALASE19ly';'_GALASE1ly';'_GALASE20ly';'_GALASE2ly';'_GALASE3ly';'_GALASE4ly';'_GALASE5ly';'_GALASE6ly';'_GALASE7ly';'_GALASE8ly';'_GALASE9ly';'_GLB1';'_r1411';'_S6TASE10ly';'_S6TASE22ly';'_S6TASE25ly';'_r0380';'_S6TASE4ly';'_S6TASE5ly';'_S6TASE6ly';'_S6TASE7ly';'_S6TASE8ly';'_S6TASE9ly';'_SIAASE2ly';'_SIAASE3ly';'_SIAASE4ly';'_SIAASEly';'_NEU11l'
        };
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    BiomarkerRxns = {
        'EX_ksi[u]'	'Increased (urine)'
        };
    [IEMSol_MPS4B] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '2593.1'GMT Guanidinoacetate Methyltransferase Deficiency
model = modelO;

R = {'_GACMTRc'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'creat[bc]');
    model = addDemandReaction(model, 'crtn[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'EX_creat[u]'	'Decreased (urine/blood)'
        'DM_creat[bc]'	'Decreased (urine/blood)'
        'DM_crtn[bc]'	'Increased (blood)'
        'EX_urate[u]'	'Increased (urine)'
        'EX_gudac[u]'	'Increased (urine)'
        };
else
    BiomarkerRxns = {
        'EX_creat[u]'	'Decreased (urine/blood)'
        'EX_crtn[u]'	'Increased (blood)'
        'EX_urate[u]'	'Increased (urine)'
        'EX_gudac[u]'	'Increased (urine)'
        };
end
[IEMSol_GMT] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
%% '4942.1'GACR Gyrate Atrophy Of The Choroid And Retina
model = modelO;

R = {'_ORNTArm'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'gln_L[bc]');
    model = addDemandReaction(model, 'lys_L[bc]');
    model = addDemandReaction(model, 'orn[bc]');
    model = addDemandReaction(model, 'orn[csf]');
    model.A = model.S;
    BiomarkerRxns = {
        'EX_arg_L[u]'	'Increased (urine)'
        'DM_gln_L[bc]'	'Decreased (blood)'
        'EX_glu_L[u]'	'Decreased (blood)'
        'EX_lys_L[u]'	'Decreased (urine/blood)'
        'DM_lys_L[bc]'	'Decreased (urine/blood)'
        'EX_orn[u]'	'Increased (urine/blood/CSF)'
        'DM_orn[bc]'	'Increased (urine/blood/CSF)'
        'DM_orn[csf]'	'Increased (CSF)'
        };
else
    BiomarkerRxns = {
        'EX_arg_L[u]'	'Increased'
        'EX_gln_L[u]'	'Decreased (blood)'
        'EX_glu_L[u]'	'Decreased (blood)'
        'EX_lys_L[u]'	'Decreased (urine/blood)'
        'EX_orn[u]'	'Increased (urine/blood/CSF)'
        % 'BBB_ORN[CSF]exp'	'Increased (CSF)'
        };
end
[IEMSol_GACR] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '229.1'HFI Hereditary Fructose Intolerance
% associated reaction does not carry any flux in healthy condition
if 1
    model = modelO;
    
    R = {'_FBA5'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'fru[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'EX_fru[u]'	'Increased (urine/blood)'
            'DM_fru[bc]'	'Increased (urine/blood)'
            };
    else
        BiomarkerRxns = {
            'EX_fru[u]'	'Increased (urine/blood)'
            };
    end
    [IEMSol_HFI] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '3155.1'HMG Hmg-Coa Lyase Deficiency
model = modelO;

R = {'_HMGLx'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);
if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'c6dc[bc]');
    model = addDemandReaction(model, 'CE5068[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'DM_c6dc[bc]'	'Increased (blood)'
        % 'EX_CE5068[u]'	'Increased (urine/blood)'%
        % 'DM_CE5068[bc]'	'Increased (urine/blood)'%
        'EX_adpac[u]'	'Increased (urine)'
        };
else
    BiomarkerRxns = {
        'EX_c6dc[u]'	'Increased (blood)'
        %  'EX_CE5068[u]'	'Increased (urine/blood)'
        'EX_adpac[u]'	'Increased (urine)'
        };
end
[IEMSol_HMG] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '3158.1'HMGCS2 Hmg-CoA Synthase-2 Deficiency
% PMID: 16601895 hypoglycemia happens during fasting
%  The combination of normal acylcarnitines in dried blood spots and the absence of urinary ketone bodies has been stated to indicate the diagnosis
% PMID: 16601895: reported two more cases with changed acylcarnitine
% profiles
% I will not simulate this IEM due to unclear biomarker profile
if 0
    model = modelO;
    % close [x] version
    
    
    R = {'_HMGCOASim'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    X = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'_r0463'))));
    model.lb(find(ismember(model.rxns,X))) = 0;
    model.ub(find(ismember(model.rxns,X))) = 0;
    %HMGCOASi
    
    BiomarkerRxns = {
        % 'EX_glc_D[u]'	'Decreased (blood)'% only in fasting conditiosn
        'EX_acetone[u]'	'Decreased (urine)'
        'EX_bhb[u]'	'Decreased (urine)'
        'EX_acac[u]'	'Decreased (urine)'
        'EX_acrn[u]'	'Normal (blood)'
        };
    [IEMSol_HMGCS2] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '875.1 HCYS Homocystinuria
% https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5203861/: Patients with CBS deficiency have low to low normal cystathionine (reference range typically between 0.05-0.08 and 0.35-0.5 ?mol/L) and high to high normal methionine concentrations (reference range typically between 12-15 and 40-45 ?mol/L) with a grossly abnormal ratio of these two metabolites.
% https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5203861/: The major confounder that may mask the biochemical hallmarks of CBS deficiency is the intake of pyridoxine. Decreases in the tHcy concentration occur after pharmacological doses of pyridoxine in a substantial proportion of CBS deficient patients (Mudd et al 1985; Wilcken and Wilcken 1997; Magner et al 2011). In pyridoxine-responsive patients with some specific mutations (e.g. p.P49L), physiological doses of pyridoxine as low as 2 mg per day in an adult may decrease the tHcy concentrations into the reference range (Stabler et al 2013). Since pyridoxine is contained in many vitamin supplements as well as in fortified foods and drinks, it is important to avoid intake of any pyridoxine supplements for at least 2 weeks before sampling plasma for tHcy measurement, although occasionally a wash-out period of up to 1-2 months may be needed (Orendac et al 2003; Stabler et al 2013).
%

model = modelO;

R = {'_CYSTS';'_SELCYSTS'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);
if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'met_L[bc]');
    model = addDemandReaction(model, 'orn[bc]');
    model = addDemandReaction(model, 'Lhcystin[bc]');
    model = addDemandReaction(model, 'hcys_L[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'DM_met_L[bc]'	'Normal to Increased (blood)'%
        'DM_orn[bc]'	'Increased (blood)' % %not mentioned in 27778219
        'EX_Lhcystin[u]'	'Normal to Increased (urine/blood)' % % difficult to detect - only in higher concentrations
        'DM_Lhcystin[bc]'	'Normal to Increased (urine/blood)' % % difficult to detect - only in higher concentrations
        'EX_hcys_L[u]'	'Increased (urine/blood)' % % only total hcys (not necessarily free hcys) is Increased
        'DM_hcys_L[bc]'	'Increased (urine/blood)' % % only total hcys (not necessarily free hcys) is Increased
        'EX_cyst_L[u]'	'Decreased (urine)' %PMID: 27778219
        };
else
    BiomarkerRxns = {
        'EX_met_L[u]'	'Normal to Increased (blood)'%
        'EX_orn[u]'	'Increased (blood)' % %not mentioned in 27778219
        'EX_Lhcystin[u]'	'Normal to Increased (urine/blood)' % % difficult to detect - only in higher concentrations
        'EX_hcys_L[u]'	'Increased (urine/blood)' % % only total hcys (not necessarily free hcys) is Increased
        'EX_cyst_L[u]'	'Decreased (urine)' %PMID: 27778219
        };
end
[IEMSol_HCYS] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
%% '10157.1 HLYS1 Hyperlysinemia I, Familial
model = modelO;

R = {'_SACCD3m';'_SACCD4m';'_r0525'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);
if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'lys_L[bc]');
    model = addDemandReaction(model, 'Lpipecol[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'EX_lys_L[u]'	'Increased (urine/blood)'
        'DM_lys_L[bc]'	'Increased (urine/blood)'
        'DM_Lpipecol[bc]'	'Increased (blood)'
        % 'EX_saccrp_L[u]'	'Increased (urine)' % %healthy model cannot produce
        };
else
    BiomarkerRxns = {
        'EX_lys_L[u]'	'Increased (urine/blood)'
        'EX_Lpipecol[u]'	'Increased (blood)'
        %   'EX_saccrp_L[u]'	'Increased (urine)' % %healthy model cannot produce
        };
end
[IEMSol_HLYS1] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '10157.1 HLYS2 Hyperlysinemia II Or Saccharopinuria
model = modelO;

R = {'_SACCD3m';'_SACCD4m';'_r0525'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);
if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'lys_L[bc]');
    model = addDemandReaction(model, 'citr_L[bc]');
    model = addDemandReaction(model, 'saccrp_L[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'EX_citr_L[u]'	'Increased (urine/blood)'
        'EX_lys_L[u]'	'Increased (urine/blood)'
        'DM_citr_L[bc]'	'Increased (urine/blood)'
        'DM_lys_L[bc]'	'Increased (urine/blood)'
        %  'DM_saccrp_L[bc]'	'Increased (urine/blood)'% %healthy model cannot produce in urine
        };
else
    
    BiomarkerRxns = {
        'EX_citr_L[u]'	'Increased (urine/blood)'
        'EX_lys_L[u]'	'Increased (urine/blood)'
        %    'EX_saccrp_L[u]'	'Increased (urine/blood)' %healthy model cannot produce
        };
end
[IEMSol_HLYS2] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);


%% '5625.1 HYPRO1 Hyperprolinemia Type I
model = modelO;

R = {'_r1453';'_PROD2m';'_PRO1xm'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'pro_L[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'EX_4hpro_LT[u]'	'Increased (urine)'
        'EX_gly[u]'	'Increased (urine)'
        'EX_pro_L[u]'	'Increased (urine/blood)'
        'DM_pro_L[bc]'	'Increased (urine/blood)'
        };
else
    BiomarkerRxns = {
        'EX_4hpro_LT[u]'	'Increased (urine)'
        'EX_gly[u]'	'Increased (urine)'
        'EX_pro_L[u]'	'Increased (urine/blood)'
        };
end

[IEMSol_HYPRO1] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '8659.1 HPII Hyperprolinemia Type Ii
model = modelO;

R = {'_P5CDm';'_PHCDm';'_r0686';'_4HGLSDm';'_r0074'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'pro_L[bc]');
    model = addDemandReaction(model, 'orn[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'EX_4hpro_LT[u]'	'Increased (urine)'
        'EX_gly[u]'	'Increased (urine)'
        'EX_orn[u]'	'Increased (urine/blood)'
        'EX_pro_L[u]'	'Increased (urine/blood)'
        'DM_orn[bc]'	'Increased (urine/blood)'
        'DM_pro_L[bc]'	'Increased (urine/blood)'
        };
else
    BiomarkerRxns = {
        'EX_4hpro_LT[u]'	'Increased'
        'EX_gly[u]'	'Increased (urine)'
        'EX_orn[u]'	'Increased (urine/blood)'
        'EX_pro_L[u]'	'Increased (urine/blood)'
        };
end
[IEMSol_HPII] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '249.1 HPOS Hypophosphatasia
% I excluded this IEM
if 0
    model = modelO;
    
    R = {'_r0707';'_r0587';'_r0242';'_ALKP'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    BiomarkerRxns = {
        'EX_pe_hs[u]'	'Increased (urine)'
        };
    [IEMSol_HPOS] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '3712.1 IVA Isovaleric Acidemia
model = modelO;

R = {'_ACOAD8m'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);
model.lb(find(ismember(model.rxns,IEMRxns))) = 0;

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'ivcrn[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'EX_3bcrn[u]'	'Increased (urine)'%
        'EX_3ivcrn[u]'	'Increased (urine)'
        'DM_ivcrn[bc]'	'Increased (blood)'
        };
else
    
    BiomarkerRxns = {
        'EX_3bcrn[u]'	'Increased (urine)'
        'EX_3ivcrn[u]'	'Increased (urine)'
        'EX_ivcrn[u]'	'Increased (blood)'
        };
end
[IEMSol_IVA] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '3251.1 LNS Lesch-Nyhan Syndrome
model = modelO;

R = {'_GUAPRT';'_HXPRT'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'fol[bc]');
    model = addDemandReaction(model, 'urate[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'DM_fol[bc]'	'Decreased (blood)'
        'EX_urate[u]'	'Increased (urine/blood)'
        'DM_urate[bc]'	'Increased (urine/blood)'
        };
else
    BiomarkerRxns = {
        'EX_fol[u]'	'Decreased (blood)'
        'EX_urate[u]'	'Increased (urine/blood)'
        
        };
end
[IEMSol_LNS] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '4056.1 LTC4S Leukotriene C4 Synthase Deficiency (Ltc4 Synthase Deficiency)
model = modelO;

R = {'_HMR_1081';'_LTC4Sr'}; % there is another reaction in [r] that has a more complex GPR
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'leuktrE4[bc]');
    model = addDemandReaction(model, 'leuktrC4[bc]');
    model = addDemandReaction(model, 'leuktrD4[bc]');
    model = addDemandReaction(model, 'leuktrE4[csf]');
    model = addDemandReaction(model, 'leuktrC4[csf]');
    model = addDemandReaction(model, 'leuktrD4[csf]');
    model.A = model.S;
    BiomarkerRxns = {
        'EX_leuktrE4[u]'	'Decreased (urine/blood/CSF)'
        'EX_leuktrC4[u]'	'Decreased (urine/blood/CSF)'
        % 'EX_leuktrD4[u]'	'Decreased (urine/blood/CSF)' % 0 in both cases
        'DM_leuktrE4[bc]'	'Decreased (urine/blood/CSF)'
        'DM_leuktrC4[bc]'	'Decreased (urine/blood/CSF)'
        'DM_leuktrD4[bc]'	'Decreased (urine/blood/CSF)'
        'DM_leuktrE4[csf]'	'Decreased (urine/blood/CSF)'
        %  'DM_leuktrC4[csf]'	'Decreased (urine/blood/CSF)'
        % 'DM_leuktrD4[csf]'	'Decreased (urine/blood/CSF)'
        % 'BBB_LEUKTRC4[CSF]exp'	'Decreased (CSF)' %healthy model cannot secrete
        % 'BBB_LEUKTRD4[CSF]exp'	'Decreased (CSF)'
        % 'BBB_LEUKTRE4[CSF]exp'	'Decreased (CSF)'
        };
else
    BiomarkerRxns = {
        'EX_leuktrE4[u]'	'Decreased (urine/blood/CSF)'
        'EX_leuktrC4[u]'	'Decreased (urine/blood/CSF)'
        'EX_leuktrD4[u]'	'Decreased (urine/blood/CSF)'
        % 'BBB_LEUKTRC4[CSF]exp'	'Decreased (CSF)' %healthy model cannot secrete
        %   'BBB_LEUKTRD4[CSF]exp'	'Decreased (CSF)'
        %   'BBB_LEUKTRE4[CSF]exp'	'Decreased (CSF)'
        };
end

[IEMSol_LTC4S] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '9056.1 LPI Lysinuric Protein Intolerance
% both reactions are transporter not likely to have an effect. I cannot see
% how having a defect in this gene would result in crn Increase
% changes in metabolites have been found after protein load which we are
% not simulating here
if 0
    model = modelO;
    
    R = {'_PTRCARGte';'_SERLYSNaex'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    BiomarkerRxns = {
        'EX_lys_L[u]'	'Increased (urine)'
        'EX_orn[u]'	'Increased (urine)'
        'EX_orot[u]'	'Increased (urine)'
        'EX_crn[u]'	'Decreased (blood)'
        };
    [IEMSol_LPI] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '593.1 MSUD Maple Syrup Urine Disease
model = modelO;

R = {'_r0670';'_OIVD1m';'_OIVD2m';'_OIVD3m';'_r0385';'_r0386';'_r1154'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'ile_L[bc]');
    model = addDemandReaction(model, 'leu_L[bc]');
    model = addDemandReaction(model, 'val_L[bc]');
    model = addDemandReaction(model, '3mop[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'EX_ile_L[u]'	'Increased (urine/blood)'
        'EX_3mop[u]'	'Increased (urine/blood)'
        'DM_ile_L[bc]'	'Increased (urine/blood)'
        'DM_leu_L[bc]'	'Increased (blood)'
        'DM_val_L[bc]'	'Increased (blood)'
        'DM_3mop[bc]'	'Increased (urine/blood)'
        %   'EX_2hxic[u]'	'Increased (urine)'
        };
else
    BiomarkerRxns = {
        'EX_ile_L[u]'	'Increased (urine/blood)'
        'EX_leu_L[u]'	'Increased (blood)'
        'EX_val_L[u]'	'Increased (blood)'
        'EX_3mop[u]'	'Increased (urine/blood)'
        %   'EX_2hxic[u]'	'Increased (urine)'
        };
end
[IEMSol_MSUD] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '166785.1 MMA Methylmalonic Acidemia (Mma)
if 0
    model = modelO;
    
    R = {'_CBLATm'};%;'_CBL2tm' % lethal in HH
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'c4dc[bc]');
        model = addDemandReaction(model, 'crn[bc]');
        model = addDemandReaction(model, 'HC00900[bc]');
        model = addDemandReaction(model, '3hpp[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'EX_3aib[u]'	'Increased (urine)'
            'DM_c4dc[bc]'	'Increased (blood)'
            'DM_crn[bc]'	'Decreased (blood)'
            'DM_HC00900[bc]'	'Increased (blood)'
            'DM_3hpp[bc]'	'Increased (blood)'
            };
    else
        BiomarkerRxns = {
            'EX_3aib[u]'	'Increased (urine)'
            'EX_c4dc[u]'	'Increased (blood)'
            'EX_crn[u]'	'Decreased (blood)'
            'EX_HC00900[u]'	'Increased (blood)'
            'EX_3hpp[u]'	'Increased (blood)'
            };
    end
    [IEMSol_MMA] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '4594.1 MMA Methylmalonic Acidemia (Mma)
if 1
    model = modelO;
    
    R = {'_MMMm'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'c4dc[bc]');
        model = addDemandReaction(model, 'crn[bc]');
        model = addDemandReaction(model, 'HC00900[bc]');
        model = addDemandReaction(model, '3hpp[bc]');
        model = addDemandReaction(model, 'pcrn[bc]');
        model = addDemandReaction(model, '3hdececrn[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'EX_3aib[u]'	'Increased (urine)' %
            'DM_c4dc[bc]'	'Increased (blood)' %
            'DM_crn[bc]'	'Decreased (blood)' %
            'DM_HC00900[bc]'	'Increased (blood)' %
            'DM_3hpp[bc]'	'Increased (blood)' %
            'DM_pcrn[bc]'	'Increased (blood)'
            'DM_3hdececrn[bc]'	'Increased (blood)'
            };
    else
        BiomarkerRxns = {
            'EX_3aib[u]'	'Increased (urine)' %
            'EX_c4dc[u]'	'Increased (blood)' %
            'EX_crn[u]'	'Decreased (blood)' %
            'EX_HC00900[u]'	'Increased (blood)' %
            'EX_3hpp[u]'	'Increased (blood)' %
            'EX_pcrn[u]'	'Increased (blood)'
            'EX_3hdececrn[u]'	'Increased (blood)'
            };
    end
    [IEMSol_MMA2] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '162417.1 NAGS N-Acetylglutamate Synthase Deficiency
model = modelO;

R = {'_RE2030M';'_RE2031M';'_RE2032M';'_RE2156M';'_RE2223M';'_ACGSm'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);
if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'ala_L[bc]');
    model = addDemandReaction(model, 'citr_L[bc]');
    model = addDemandReaction(model, 'gln_L[bc]');
    model = addDemandReaction(model, 'nh4[bc]');
    model = addDemandReaction(model, 'orn[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'DM_ala_L[bc]'	'Increased (blood)'
        'DM_citr_L[bc]'	'Decreased (blood)'
        'DM_gln_L[bc]'	'Increased (blood)'
        'DM_nh4[bc]'	'Increased (blood)'
        'DM_orn[bc]'	'Increased (blood)'
        'EX_orot[u]'	'Decreased (urine)'
        };
else
    BiomarkerRxns = {
        'EX_ala_L[u]'	'Increased (blood)'
        'EX_citr_L[u]'	'Decreased (blood)'
        'EX_gln_L[u]'	'Increased (blood)'
        'EX_nh4[u]'	'Increased (blood)'
        'EX_orn[u]'	'Increased (blood)'
        'EX_orot[u]'	'Decreased (urine)'
        };
end
[IEMSol_NAGS] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
%% '5009.1 OTC Ornithine Transcarbamylase Deficiency
model = modelO;

R = {'_OCBTm'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);
if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'ura[bc]');
    model = addDemandReaction(model, 'citr_L[bc]');
    model = addDemandReaction(model, 'gln_L[bc]');
    model = addDemandReaction(model, 'nh4[bc]');
    model = addDemandReaction(model, 'orn[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'EX_5oxpro[u]'	'Increased (transient, urine)'
        'EX_gly[u]'	'Increased (urine)'
        'EX_lys_L[u]'	'Increased (urine)'
        'EX_orot[u]'	'Increased (urine)'
        'DM_citr_L[bc]'	'Decreased (blood)'
        'DM_gln_L[bc]'	'Increased (blood)'
        'DM_ura[bc]'	'Increased (urine)'
        'DM_nh4[bc]'	'Increased (blood)'
        'DM_orn[bc]'	'Increased (blood)'
        };
else
    BiomarkerRxns = {
        'EX_5oxpro[u]'	'Increased (transient, urine)'
        'EX_citr_L[u]'	'Decreased (blood)'
        'EX_gln_L[u]'	'Increased (blood)'
        'EX_gly[u]'	'Increased (urine)'
        'EX_lys_L[u]'	'Increased (urine)'
        'EX_orot[u]'	'Increased (urine)'
        'EX_ura[u]'	'Increased (urine)'
        'EX_nh4[u]'	'Increased (blood)'
        'EX_orn[u]'	'Increased (blood)'
        };
end
[IEMSol_OTC] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '7372.1 OROA Orotic Aciduria
model = modelO;

R = {'_ORPT';'_OMPDC'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'orot[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'EX_orot[u]'	'Increased (urine/blood)'
        'DM_orot[bc]'	'Increased (urine/blood)'
        };
else
    BiomarkerRxns = {
        'EX_orot[u]'	'Increased (urine/blood)'
        };
end
[IEMSol_OROA] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '7372.1 PKU Phenylketonuria
model = modelO;

R = {'_PHETHPTOX2';'_r0399'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'phe_L[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'DM_phe_L[bc]'	'Increased (blood)'
        'EX_2hyoxplac[u]'	'Increased (urine)'
        %  'EX_plac[u]'	'Increased (urine)'%
        'EX_phpyr[u]'	'Increased (urine)'
        };
else
    
    BiomarkerRxns = {
        'EX_phe_L[u]'	'Increased (blood)'
        'EX_2hyoxplac[u]'	'Increased (urine)'
        %  'EX_plac[u]'	'Increased (urine)'%
        'EX_phpyr[u]'	'Increased (urine)'
        };
end
[IEMSol_PKU] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '5091.1 PC Pyruvate Carboxylase Deficiency
if 0
    model = modelO;
    
    R = {'_PCm'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'acac[bc]');
        model = addDemandReaction(model, 'ala_L[bc]');
        model = addDemandReaction(model, 'bhb[bc]');
        model = addDemandReaction(model, 'citr_L[bc]');
        model = addDemandReaction(model, 'lys_L[bc]');
        model = addDemandReaction(model, 'pro_L[bc]');
        model = addDemandReaction(model, 'lac_L[bc]');
        model = addDemandReaction(model, 'nh4[bc]');
        model = addDemandReaction(model, 'glc_D[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'DM_acac[bc]'	'Increased (urine/blood)'
            'DM_ala_L[bc]'	'Increased (blood)'
            'DM_bhb[bc]'	'Increased (urine/blood)'
            'DM_citr_L[bc]'	'Increased (blood)'
            'DM_lys_L[bc]'	'Increased (blood)'
            'DM_pro_L[bc]'	'Increased (blood)'
            'DM_lac_L[bc]'	'Increased (blood)' % after 12hrs of fasting,
            'DM_nh4[bc]'	'Increased (blood)' % after 12hrs of fasting,
            'DM_glc_D[bc]'	'Decreased (blood)' % after 12hrs of fasting,
            'EX_fum[u]'	'Increased (urine)'
            'EX_succ[u]'	'Increased (urine)'
            'EX_acetone[u]'	'Increased (urine)'
            'EX_akg[u]'	'Increased (urine)'
            'EX_acac[u]'	'Increased (urine/blood)'
            'EX_bhb[u]'	'Increased (urine/blood)'
            };
    else
        
        BiomarkerRxns = {
            'EX_acac[u]'	'Increased (urine/blood)'
            'EX_acetone[u]'	'Increased (urine)'
            'EX_akg[u]'	'Increased (urine)'
            'EX_ala_L[u]'	'Increased (blood)'
            'EX_bhb[u]'	'Increased (urine/blood)'
            'EX_citr_L[u]'	'Increased (blood)'
            'EX_lys_L[u]'	'Increased (blood)'
            'EX_pro_L[u]'	'Increased (blood)'
            'EX_succ[u]'	'Increased (urine)'
            'EX_lac_L[u]'	'Increased (blood)' % after 12hrs of fasting,
            'EX_nh4[u]'	'Increased (blood)' % after 12hrs of fasting,
            'EX_glc_D[u]'	'Decreased (blood)' % after 12hrs of fasting,
            'EX_fum[u]'	'Increased (urine)'
            };
    end
    [IEMSol_PC] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '189.1 PHOX1 Primary Hyperoxaluria-Type 1
if 0
    model = modelO;
    
    R = {'_AGTix';'_SPTix';'_r0160'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    BiomarkerRxns = {
        'EX_oxa[u]'	'Increased (urine)'
        'EX_glyclt[u]'	'Increased (urine)'
        'EX_glx[u]'	'Increased (urine)'
        };
    [IEMSol_PHOX1] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '5095.1 PA Propionic Acidemia
if 0
    model = modelO;
    
    R = {'_PPCOACm'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'crn[bc]');
        model = addDemandReaction(model, 'gln_L[bc]');
        model = addDemandReaction(model, 'gly[bc]');
        model = addDemandReaction(model, 'ppa[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'DM_crn[bc]'	'Increased (blood)'
            'DM_gln_L[bc]'	'Increased (blood)'
            'DM_gly[bc]'	'Increased (blood)'
            'DM_ppa[bc]'	'Increased (blood)'
            'EX_3hpp[u]'	'Increased (urine)'
            };
    else
        
        BiomarkerRxns = {
            'EX_crn[u]'	'Increased (blood)'
            'EX_gln_L[u]'	'Increased (blood)'
            'EX_gly[u]'	'Increased (blood)'
            'EX_ppa[u]'	'Increased (blood)'
            'EX_3hpp[u]'	'Increased (urine)'
            };
    end
    [IEMSol_PA] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '4598.1 MVA Mevalonic Aciduria
if 0 % infeasible
    model = modelO;
    
    R = {'_MEVK1x';'_MEVK1c'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'chsterol[bc]');
        model = addDemandReaction(model, 'mev_R[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'DM_chsterol[bc]'	'Decreased (blood)'
            'DM_mev_R[bc]'	'Increased (urine/blood)'
            'EX_mev_R[u]'	'Increased (urine/blood)'
            'EX_mvlac[u]'	'Increased (urine)'
            };
    else
        BiomarkerRxns = {
            'EX_chsterol[u]'	'Decreased (blood)'
            'EX_mev_R[u]'	'Increased (urine/blood)'
            'EX_mvlac[u]'	'Increased (urine)'
            };
    end
    [IEMSol_MVA] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end

%% '1890.1 MNGIE Mitochondrial Neurogastrointestinal Encephalopathy (Mngie) Disease
model = modelO;

R = {'_TMDPP'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'duri[bc]');
    model = addDemandReaction(model, 'thymd[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'DM_duri[bc]'	'Increased (blood)'
        'DM_thymd[bc]'	'Increased (blood)'
        };
else
    
    BiomarkerRxns = {
        'EX_duri[u]'	'Increased (blood)'
        'EX_thymd[u]'	'Increased (blood)'
        };
end
[IEMSol_MNGIE] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '1890.1 MPS4A Mucopolysaccharidosis Type IV Type A/Morquio Syndrome
% biomarker cannot be produced in either case in urine
if 0
    model = modelO;
    
    R = {'_S6TASE10ly';'_S6TASE22ly';'_S6TASE25ly';'_S6TASE4ly';'_S6TASE5ly';'_S6TASE6ly';'_S6TASE7ly';'_S6TASE8ly';'_S6TASE9ly';'_SIAASE2ly';'_SIAASE3ly';'_SIAASE4ly';'_SIAASEly'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    BiomarkerRxns = {
        'EX_ksi[u]'	'Increased (urine)'
        };
    [IEMSol_MPS4A] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end

%% '55163.1 PLPE Pyridoxal 5'-Phosphate-Dependent Epilepsy
if 0
    model = modelO;
    
    R = {'_PDX5PO';'_PYAM5POr';'_r0388';'_r0389'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'gly[bc]');
        model = addDemandReaction(model, 'thr_L[bc]');
        model = addDemandReaction(model, 'gly[csf]');
        model = addDemandReaction(model, 'thr_L[csf]');
        model.A = model.S;
        BiomarkerRxns = {
            'DM_gly[bc]'	'Increased (CSF/blood)'
            'DM_thr_L[bc]'	'Increased (CSF/blood)'
            'DM_gly[csf]'	'Increased (CSF/blood)'
            'DM_thr_L[csf]'	'Increased (CSF/blood)'
            % 'BBB_GLY[CSF]exp'	'Increased (CSF)'
            % 'BBB_THR_L[CSF]exp'	'Increased (CSF)'
            };
    else
        BiomarkerRxns = {
            'EX_gly[u]'	'Increased (CSF/blood)'
            'EX_thr_L[u]'	'Increased (CSF/blood)'
            %  'BBB_GLY[CSF]exp'	'Increased (CSF)'
            %  'BBB_THR_L[CSF]exp'	'Increased (CSF)'
            };
    end
    [IEMSol_PLPE] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '1757.1 SARCO Sarcosinemia
if 0
    % not such reaction of exchange in hh
    model = modelO;
    
    R = {'_SARDHm'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'sarcs[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'DM_sarcs[bc]'	'Increased (blood/urine)'  % not in urine
            };
    else
        
        BiomarkerRxns = {
            'EX_sarcs[u]'	'Increased (blood/urine)'
            };
    end
    [IEMSol_SARCO] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '1717.1 SLOS Smith-Lemli-Opitz Syndrome
if 0 % ko is infeasible
    model = modelO;
    
    R = {'_DHCR71r';'_DHCR72r';'_RE2410N';'_HMR_1565'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'chsterol[bc]');
        model = addDemandReaction(model, '7dhchsterol[bc]');
        model = addDemandReaction(model, 'CE1297[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'DM_chsterol[bc]'	'Decreased (blood)'
            'DM_7dhchsterol[bc]'	'Increased (blood)'
            'DM_CE1297[bc]'	'Increased (blood)'
            %   'EX_CE5068[u]'	'Decreased (urine)' % decrease??
            };
    else
        BiomarkerRxns = {
            'EX_chsterol[u]'	'Decreased (blood)'
            'EX_7dhchsterol[u]'	'Increased (blood)'
            %'EX_CE1297[u]'	'Increased (blood)' % not in Recon?
            %  'EX_CE5068[u]'	'Decreased (urine)' % decrease??
            };
    end
    
    [IEMSol_SLOS] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '8803.1 SUCLA Succinate-Coenzyme A (Coa) Ligase Deficiency/Lactic Acidosis, Fatal Infantile
model = modelO;

R = {'_ITCOALm';'_MECOALm';'_SUCOASm';'_ITCOAL1m';'_MECOAS1m';'_SUCOAS1m'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'lac_L[bc]');
    model = addDemandReaction(model, 'pyr[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'DM_lac_L[bc]'	'Increased (blood)'
        'DM_pyr[bc]'	'Increased (blood)'
        };
else
    BiomarkerRxns = {
        'EX_lac_L[u]'	'Increased (blood)'
        'EX_pyr[u]'	'Increased (blood)'
        };
end
[IEMSol_SUCLA] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '7915.1 SSADHD Succinic Semialdehyde Dehydrogenase Deficiency
model = modelO;

R = {'_r0178'};
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'gly[bc]');
    model = addDemandReaction(model, '4hdxbutn[bc]');
    model = addDemandReaction(model, 'sucsal[bc]');
    model = addDemandReaction(model, '4abut[csf]');
    model.A = model.S;
    BiomarkerRxns = {
        'EX_gly[u]'	'Increased (urine/blood)'
        %  'EX_4hdxbutn[u]'	'Increased (urine/blood)'%
        'EX_sucsal[u]'	'Increased (urine/blood)'
        'DM_gly[bc]'	'Increased (urine/blood)'
        %'DM_4hdxbutn[bc]'	'Increased (urine/blood)'
        'DM_sucsal[bc]'	'Increased (urine/blood)'
        %'BBB_4ABUT[CSF]exp'	'Increased (CSF)'
        'DM_4abut[csf]'	'Increased (CSF)'
        };
else
    BiomarkerRxns = {
        'EX_gly[u]'	'Increased (urine/blood)'
        %'EX_4hdxbutn[u]'	'Increased (urine/blood)'
        'EX_sucsal[u]'	'Increased (urine/blood)'
        %   'BBB_4ABUT[CSF]exp'	'Increased (CSF)'
        'EX_4abut[u]'	'Increased (CSF)'
        };
end
[IEMSol_SSADHD] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '8803.1 SUCLA2 Sucla2-Related Mitochondrial Dna Depletion Syndrome, Encephalomyopathic Form, With Mild Methylmalonic Aciduria
if 0
    model = modelO;
    
    R = {'_ITCOALm';'_MECOALm';'_SUCOASm'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'lac_L[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'DM_lac_L[bc]'	'Increased (blood)'
            };
    else
        BiomarkerRxns = {
            'EX_lac_L[u]'	'Increased (blood)'
            };
    end
    [IEMSol_SUCLA2] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '2643.1 TETB Tetrahydrobiopterin Deficiency
%  is a naturally occurring essential cofactor of the three aromatic amino
%  acid hydroxylase enzymes, used in the degradation of amino acid
%  phenylalanine and in the biosynthesis of the neurotransmitters serotonin
%  (5-hydroxytryptamine, 5-HT), melatonin, dopamine,...
model = modelO;

R = {'_GTPCIn';'_r0120';'_r0121';'_r0708';'_r0775';'_r0777';'_GTPCI';...
    '_TYR3MO2';'_PHETHPTOX2';'_Tetrahydrobiopterin'
    };
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);
% model.ub(strmatch('Muscle_sink_phe_L(c)',model.rxns)) = 0;
% model.ub(strmatch('Muscle_sink_tyr_L(c)',model.rxns)) = 0;
% model.ub(strmatch('Muscle_sink_trp_L(c)',model.rxns)) = 0;
if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'phe_L[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'DM_phe_L[bc]'	'Increased (blood)'
        };
else
    BiomarkerRxns = {
        'EX_phe_L[u]'	'Increased (blood)'
        };
end
[IEMSol_TETB] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '6888.1 TALD Transaldolase Deficiency
if 0
    model = modelO;
    
    R = {'_TALA'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'rbt[bc]');
        model = addDemandReaction(model, 'abt[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'EX_rbt[u]'	'Increased (urine/blood)'
            'EX_abt[u]'	'Increased (urine/blood)'
            'DM_rbt[bc]'	'Increased (urine/blood)'
            'DM_abt[bc]'	'Increased (urine/blood)'
            %   'EX_M03165[u]'	'Increased (urine)' % not in HH
            };
    else
        BiomarkerRxns = {
            'EX_rbt[u]'	'Increased (urine/blood)'
            'EX_abt[u]'	'Increased (urine/blood)'
            %  'EX_M03165[u]'	'Increased (urine)' %not in Recon3D?
            };
    end
    [IEMSol_TALD] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '9380.1 HOXA2 Type 2 Primary Hyperoxaluria
% from VMH The low prevalence of PH2 does not allow genotype-phenotype correlations at the present time.
% hence I exclude it
if 0
    model = modelO;
    
    R = {'_GLYCLTDy';'_HPYRRy';'_HMR_8501'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    BiomarkerRxns = {
        'EX_oxa[u]'	'Increased (not specified)'
        'EX_glyc_R[u]'	'Increased (not specified)'
        };
    [IEMSol_HOXA2] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '445.1 CIT1 Type I Citrullinemia
model = modelO;

R = {'_ARGSS' };
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'citr_L[bc]');
    model = addDemandReaction(model, 'gly[bc]');
    model = addDemandReaction(model, 'nh4[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'DM_citr_L[bc]'	'Increased (urine/blood)'
        'DM_gly[bc]'	'Increased (urine/blood)'
        'DM_nh4[bc]'	'Increased (blood)'
        'EX_orot[u]'	'Increased (urine)'
        'EX_citr_L[u]'	'Increased (urine/blood)'
        'EX_gly[u]'	'Increased (urine/blood)'
        };
else
    
    BiomarkerRxns = {
        'EX_citr_L[u]'	'Increased (urine/blood)'
        'EX_gly[u]'	'Increased (urine/blood)'
        'EX_nh4[u]'	'Increased (blood)'
        'EX_orot[u]'	'Increased (urine)'
        };
end
[IEMSol_CIT1] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '2184.1 TYR1 Tyrosinemia Type I
model = modelO;

R = {'_FUMAC' };
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);

if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'met_L[bc]');
    model = addDemandReaction(model, 'tyr_L[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'DM_met_L[bc]'	'Increased (blood)'
        'DM_tyr_L[bc]'	'Increased (blood)'
        'EX_34hpl[u]'	'Increased (urine)'
        %'EX_3hphac[u]'	'Increased (urine)'
        'EX_34hpp[u]'	'Increased (urine)'
        };
else
    
    BiomarkerRxns = {
        'EX_met_L[u]'	'Increased (blood)'
        'EX_tyr_L[u]'	'Increased (blood)'
        'EX_34hpl[u]'	'Increased (urine)'
        %'EX_3hphac[u]'	'Increased (urine)'
        'EX_34hpp[u]'	'Increased (urine)'
        };
end
[IEMSol_TYR1] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '3242.1 TYR3 Tyrosinemia Type III
model = modelO;

R = {'_34HPPOR';'_PPOR' };
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);
if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'tyr_L[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'DM_tyr_L[bc]'	'Increased (blood)'
        'EX_34hpl[u]'	'Increased (urine)'
        % 'EX_3hphac[u]'	'Increased (urine)'
        'EX_34hpp[u]'	'Increased (urine)'
        };
else
    BiomarkerRxns = {
        'EX_tyr_L[u]'	'Increased (blood)'
        'EX_34hpl[u]'	'Increased (urine)'
        % 'EX_3hphac[u]'	'Increased (urine)'
        'EX_34hpp[u]'	'Increased (urine)'
        };
end
[IEMSol_TYR3] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '3242.1 VP Variegate Porphyria
if 0
    model = modelO;
    
    R = {'_HMR_4757';'_PPPGOm' };
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    BiomarkerRxns = {
        'EX_na1[u]'	'Decreased (blood)'
        'EX_5aop[u]'	'Increased (urine)'
        };
    [IEMSol_VP] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end
%% '3242.1 XAN1 Xanthinuria Type 1
model = modelO;

R = {'_r0395';'_XANDp';'_XAO2x';'_XAOx';'_r0394';'_r0502';'_r0504' };
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);
if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'xan[bc]');
    model = addDemandReaction(model, 'urate[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'EX_hxan[u]'	'Increased (urine)'
        'EX_xan[u]'	'Increased (blood/urine)'
        'EX_urate[u]'	'Decreased (blood/urine)'
        'DM_xan[bc]'	'Increased (blood/urine)'
        'DM_urate[bc]'	'Decreased (blood/urine)'
        };
else
    BiomarkerRxns = {
        'EX_hxan[u]'	'Increased (urine)'
        'EX_xan[u]'	'Increased (blood/urine)'
        'EX_urate[u]'	'Decreased (blood/urine)'
        };
end
[IEMSol_XAN1] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);


%% '3145.1 AIP Acute Intermittent Porphyria
if 0
    
    % based on VMH - unclear genotype phenotype relationship
    model = modelO;
    
    R = {'_HMBS' };
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model.A = model.S;
        BiomarkerRxns = {
            'EX_5aop[u]'	'Increased (urine)'
            };
    else
        BiomarkerRxns = {
            'EX_5aop[u]'	'Increased (urine)'
            };
    end
    [IEMSol_AIP] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
    
end
%% '210.1 ALAD Acute Intermittent Porphyria
if 0
    model = modelO;
    
    R = {'_PPBNGS' };
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    R2 = {'_r0517'};
    RxnsAll2 = '';
    for i = 1: length(R2)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R2{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    X = unique(RxnsAll2);
    model.lb(find(ismember(model.rxns,X))) = 0;
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model.A = model.S;
        BiomarkerRxns = {
            'EX_5aop[u]'	'Increased (urine)'
            };
    else
        BiomarkerRxns = {
            'EX_5aop[u]'	'Increased (urine)'
            };
    end
    [IEMSol_ALAD] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
    
end
%% '4967.1 AKGD Alpha-Ketoglutarate Dehydrogenase Deficiency
model = modelO;

R = {'_AKGDm';'_2OXOADOXm';'_r0163';'_r0384';'_r0451';'_r0620' };
RxnsAll2 = '';
for i = 1: length(R)
    RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
    RxnsAll2 =[RxnsAll2;RxnsAll];
end
IEMRxns = unique(RxnsAll2);
RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
IEMRxns = setdiff(IEMRxns,RxnMic);
if ~strcmp(gender,'Recon3D')
    % add demand reactions to blood compartment for those biomarkers reported for blood
    model = addDemandReaction(model, 'lac_L[bc]');
    model = addDemandReaction(model, 'glu_L[bc]');
    model = addDemandReaction(model, 'gln_L[bc]');
    model.A = model.S;
    BiomarkerRxns = {
        'EX_akg[u]'	'Increased (urine)'
        'EX_lac_L[u]'	'Increased (blood/urine)'
        'DM_lac_L[bc]'	'Increased (blood/urine)'
        'DM_glu_L[bc]'	'Increased (blood)'
        'DM_gln_L[bc]'	'Increased (blood)'
        };
else
    BiomarkerRxns = {
        'EX_akg[u]'	'Increased (urine)'
        'EX_lac_L[u]'	'Increased (blood/urine)'
        'EX_glu_L[u]'	'Increased (blood)'
        'EX_gln_L[u]'	'Increased (blood)'
        };
end
[IEMSol_AKGD] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);

%% '4967.1 ADSL Adenylosuccinase Deficiency
if 0
    model = modelO;
    
    R = {'_ADSL1';'_ADSL2'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'Brain_25aics[c]');
        model.A = model.S;
        BiomarkerRxns = {
            % 'EX_25aics[u]'	'Increased (urine/csf)' % not in HH
            'DM_Brain_25aics[c]'	'Increased (urine/csf)' % cannot be produced by HH
            };
    else
        BiomarkerRxns = {
            'EX_25aics[u]'	'Increased (urine/csf)'
            };
    end
    [IEMSol_ADSL] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end


%% 443.1 CD Canavan Disease - only milder forms of this disease have been reported (there is an isozyme in Recon -- due to mild form report I included this IEM anyway)
if 0
    model = modelO;
    
    R = {'_NACASPAH'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'Nacasp[bc]');
        model = addDemandReaction(model, 'Nacasp[csf]');
        model.A = model.S;
        BiomarkerRxns = {
            % 'EX_25aics[u]'	'Increased (urine/csf)' % not in HH
            'EX_Nacasp[u]'	'Increased (urine/csf/blood)' % cannot be produced by HH
            'DM_Nacasp[bc]'	'Increased (urine/csf/blood)'
            'DM_Nacasp[csf]'	'Increased (urine/csf/blood)'
            };
    else
        BiomarkerRxns = {
            'EX_Nacasp[u]'	'Increased (urine/csf/blood)'
            };
    end
    [IEMSol_DC] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end

%% 51181.1 EP Essential Pentosuria
if 1
    model = modelO;
    
    R = {'_XYLUR'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    model.lb(find(ismember(model.rxns,IEMRxns))) = 0;
    
    R2 = {'_r0784'};
    RxnsAll2 = '';
    for i = 1: length(R2)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R2{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    X = unique(RxnsAll2);
            RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
X = setdiff(X,RxnMic);
    model.lb(find(ismember(model.rxns,X))) = 0;
    model.ub(find(ismember(model.rxns,X))) = 0;
    
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        
        model.A = model.S;
        BiomarkerRxns = {
            'EX_xylu_L[u]'	'Increased (urine)'
            };
    else
        BiomarkerRxns = {
            'EX_xylu_L[u]'	'Increased (urine)'
            };
    end
    [IEMSol_EP] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end

%% 443.1 HPC Hereditary Coproporphyria
if 0 %Rxn obj is 0
    model = modelO;
    
    R = {'_CPPPGO'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'C05770[bc]');
        model = addDemandReaction(model, 'C05770[csf]');
        model.A = model.S;
        BiomarkerRxns = {
            % 'EX_25aics[u]'	'Increased (urine/csf)' % not in HH
            'EX_C05770[u]'	'Increased (urine/csf/blood)' % cannot be produced by HH
            'DM_C05770[bc]'	'Increased (urine/csf/blood)'
            'DM_C05770[csf]'	'Increased (urine/csf/blood)'
            };
    else
        BiomarkerRxns = {
            'EX_C05770[u]'	'Increased (urine/csf/blood)'
            };
    end
    [IEMSol_HPC] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end


%% 191.1 HMET Hypermethioninemia
if 0  % I just cannot get the acc of hcys and met with current constraints
    model = modelO;
    
    R = {'_GNMT'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'hcys_L[bc]');
        model = addDemandReaction(model, 'met_L[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'EX_met_L[u]'	'Increased (urine/blood)' %
            'DM_hcys_L[bc]'	'Increased (urine/blood)'
            'DM_met_L[bc]'	'Increased (urine/blood)'
            };
    else
        BiomarkerRxns = {
            'EX_met_L[u]'	'Increased (urine/blood)'
            'EX_hcys_L[u]'	'Increased (urine/blood)'
            };
    end
    [IEMSol_HMET] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end

%% 1718.1 DESMO Desmosterolosis
if 0
    model = modelO;
    
    R = {'_DHCR241r';'_DHCR243r';'_r0783';'_r1380';'_DSREDUCr';'_HMR_1526';'_RE3129N'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    R2 = {'_RE2410C';'_RE2410N'};
    RxnsAll2 = '';
    for i = 1: length(R2)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R2{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    X = unique(RxnsAll2);
            RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
X = setdiff(X,RxnMic);
    model.lb(find(ismember(model.rxns,X))) = 0;
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'dsmsterol[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'DM_dsmsterol[bc]'	'Increased (blood)'
            };
    else
        BiomarkerRxns = {
            'EX_dsmsterol[u]'	'Increased (blood)'
            };
    end
    [IEMSol_DESMO] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end

%% 587.1 HYPVLI Hypervalinemia And Hyperleucine-Isoleucinemia
if 1
    model = modelO;
    
    R = {'_ILETAm';'_LEUTAm';'_VALTAm'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        model = addDemandReaction(model, 'val_L[bc]');
        model = addDemandReaction(model, 'leu_L[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'DM_val_L[bc]'	'Increased (blood/urine)'
            'EX_val_L[u]'	'Increased (blood/urine)'
            'EX_leu_L[u]'	'Increased (blood/urine)'
            };
    else
        BiomarkerRxns = {
            'EX_val_L[u]'	'Increased (blood/urine)'
            'EX_leu_L[u]'	'Increased (blood/urine)'
            };
    end
    [IEMSol_HYPVLI] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end


%% 440.1 ASNSD Asparagine Synthetase Deficiency
if 1
    model = modelO;
    
    R = {'_ASNS1'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    if ~strcmp(gender,'Recon3D') %&& ~strcmp(gender,'male') %somehow it gets stuck here
        % add demand reactions to blood compartment for those biomarkers reported for blood
        % biomarker based on https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4486270/
        model = addDemandReaction(model, 'asn_L[bc]');
        model = addDemandReaction(model, 'asn_L[csf]');
        model = addDemandReaction(model, 'gln_L[bc]');
        model = addDemandReaction(model, 'gln_L[csf]');
        model.A = model.S;
        BiomarkerRxns = {
            'DM_asn_L[bc]'	'Decreased (blood/csf)'
            'DM_asn_L[csf]'	'Decreased (blood/csf)'
            'DM_gln_L[bc]'	'Increased (blood/csf)'
            'DM_gln_L[csf]'	'Normal to Increased (blood/csf)'
            };
    else
        BiomarkerRxns = {
            'EX_asn_L[u]'	'Decreased (blood/urine)'
            'EX_gln_L[u]'	'Increased (blood/urine)'
            };
    end
    [IEMSol_ASNSD] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end


%% 89874.1 2OAA 2-Oxoadipate Acidemia
if 0 % not well studied - inconsistent biomarkers between reports
    model = modelO;
    
    R = {'_2OXOADPTm';'_2AMADPTm';'_r0879'};
    RxnsAll2 = '';
    for i = 1: length(R)
        RxnsAll = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,R{i}))));
        RxnsAll2 =[RxnsAll2;RxnsAll];
    end
    IEMRxns = unique(RxnsAll2);
    RxnMic = model.rxns(find(~cellfun(@isempty,strfind(model.rxns,'Micro_')))) ;;
    IEMRxns = setdiff(IEMRxns,RxnMic);
    
    if ~strcmp(gender,'Recon3D')
        % add demand reactions to blood compartment for those biomarkers reported for blood
        % biomarker based on https://www.omim.org/entry/204750
        model = addDemandReaction(model, 'L2aadp[bc]');
        model.A = model.S;
        BiomarkerRxns = {
            'DM_L2aadp[bc]'	'Increased (blood)'
            'EX_2oxoadp[u]'	'Increased (urine)'
            'EX_adpoh[u]'	'Increased (urine)'
            };
    else
        BiomarkerRxns = {
            'EX_2oxoadp[u]'	'Increased (urine)'
            'EX_adpoh[u]'	'Increased (urine)'
            };
    end
    [IEMSol_2OAA] = testIEM_WBM(model,IEMRxns, BiomarkerRxns,minRxnsFluxHealthy);
end




%% Parse IEM results

vars = who;
vars_IEM = strmatch('IEMSol_',vars);
% count results (in vivo vs in silico
UpUp =0;
DoDo = 0;
UpDo = 0;
DoUp = 0;
UpUn = 0; %up in vivo, unchanged in silico
DoUn = 0; %down in vivo, unchanged in silico
UnUp = 0; %unchanged in vivo, up in silico
UnDo = 0; %unchanged in vivo, down in silico
UnUn =0;
cnt = 1;

clear Table_IEM
for i = 1 : length(vars_IEM)
    % read in IEM solutions
    clear IEM
    IEM = evalin('base',vars{vars_IEM(i)});
    % get change of direction
    for j = 5 : 2 : size(IEM,1)
        H_D = str2num(char(IEM(j,2))) -  str2num(char(IEM(j+1,2))); % healthy minus disease
        if H_D < -1e-6 %Increased
            H_D_in_sil =1;
        elseif  H_D > 1e-6 %Increased
            H_D_in_sil =-1;
        else % unchanged
            H_D_in_sil =0;
        end
        % is the marker Increased or decreased in vivo?
        if ~isempty(strfind(IEM{j,3},'Incre'))
            H_D_in_vivo = 1;
        elseif  ~isempty(strfind(IEM{j,3},'Decre'))
            H_D_in_vivo = -1;
        else % unchanged
            H_D_in_vivo = 0;
        end
        % create new table with all results
        Table_IEM{cnt,1} = regexprep(vars{vars_IEM(i)},'IEMSol_',''); % IEM abbr
        Table_IEM{cnt,2} = regexprep(IEM{j,1},'Healthy:','') % biomaker
        Table_IEM{cnt,3} = (IEM(j,2)); % healthy original values
        Table_IEM{cnt,4} = (IEM(j+1,2)); % disease original values
        Table_IEM{cnt,5} = num2str(H_D_in_sil); % in silico
        Table_IEM{cnt,6} = num2str(H_D_in_vivo); % in vivo
        Table_IEM{cnt,7} = IEM{j,3}; % original in vivo message (for biofluid info)
        Table_IEM{cnt,8} = (IEM(1,2));
        cnt = cnt +1;
        if H_D_in_vivo == 1 && H_D_in_sil == 1
            UpUp =  UpUp + 1;
        elseif H_D_in_vivo == -1 && H_D_in_sil == -1
            DoDo = DoDo + 1;
        elseif H_D_in_vivo == 1 && H_D_in_sil == -1
            UpDo =  UpDo +1;
         elseif H_D_in_vivo == -1 && H_D_in_sil == 1
            DoUp = DoUp + 1;
        elseif H_D_in_vivo == 0 && H_D_in_sil == 1
            UnUp = UnUp + 1;
        elseif H_D_in_vivo == 1 && H_D_in_sil == 0
            UpUn = UpUn + 1;
        elseif H_D_in_vivo == -1 && H_D_in_sil == 0
            DoUn = DoUn + 1;
         elseif H_D_in_vivo == 0 && H_D_in_sil == -1
            UnDo = UnDo + 1;
      elseif H_D_in_vivo == 0 && H_D_in_sil == 0
            UnUn = UnUn + 1;
         end
    end
end

clear Table_IEM_Grid
Diseases = unique(Table_IEM(:,1));
BioMU = unique(Table_IEM(find(~cellfun(@isempty,strfind(Table_IEM(:,2),'[u]'))),2));
BioMCSF = unique(Table_IEM(find(~cellfun(@isempty,strfind(Table_IEM(:,2),'[csf]'))),2));
BioMBC = unique(Table_IEM(find(~cellfun(@isempty,strfind(Table_IEM(:,2),'[bc]'))),2));
BioM = [BioMBC; BioMU; BioMCSF];

Table_IEM_Grid(2:length(BioM)+1,1) = BioM;
Table_IEM_Grid(1,2:length(Diseases)+1) = Diseases;
cnt=1;
for i = 1 : length(vars_IEM)
    % read in IEM solutions
    clear IEM
    IEM = evalin('base',vars{vars_IEM(i)});
    % get change of direction
    for j = 5 : 2 : size(IEM,1)
        H_D = str2num(char(IEM(j,2))) -  str2num(char(IEM(j+1,2))); % healthy minus disease
        if H_D < -1e-6 %Increased
            H_D_in_sil =1;
        elseif  H_D > 1e-6 %Increased
            H_D_in_sil =-1;
        else % unchanged
            H_D_in_sil =0;
        end
        % is the marker Increased or decreased in vivo?
        if ~isempty(strfind(IEM{j,3},'Incre'))
            H_D_in_vivo = 1;
        elseif  ~isempty(strfind(IEM{j,3},'Decre'))
            H_D_in_vivo = -1;
        else % unchanged
            H_D_in_vivo = 0;
        end
        if H_D_in_vivo == 1 && H_D_in_sil == 1
            Table_IEM_Grid{strmatch(Table_IEM(cnt,2),char(Table_IEM_Grid{:,1}),'exact'),strmatch(Table_IEM(cnt,1),char(Table_IEM_Grid{1,:}),'exact')}='UpUp';
        elseif H_D_in_vivo == -1 && H_D_in_sil == -1
            Table_IEM_Grid{strmatch(Table_IEM(cnt,2),char(Table_IEM_Grid{:,1}),'exact'),strmatch(Table_IEM(cnt,1),char(Table_IEM_Grid{1,:}),'exact')}='DoDO';
        elseif H_D_in_vivo == 1 && H_D_in_sil == -1
            Table_IEM_Grid{strmatch(Table_IEM(cnt,2),char(Table_IEM_Grid{:,1}),'exact'),strmatch(Table_IEM(cnt,1),char(Table_IEM_Grid{1,:}),'exact')}='UpDo';
        elseif H_D_in_vivo == -1 && H_D_in_sil == 1
            Table_IEM_Grid{strmatch(Table_IEM(cnt,2),char(Table_IEM_Grid{:,1}),'exact'),strmatch(Table_IEM(cnt,1),char(Table_IEM_Grid{1,:}),'exact')}='DoUp';
        elseif H_D_in_vivo == 0 && H_D_in_sil == 1
            Table_IEM_Grid{strmatch(Table_IEM(cnt,2),char(Table_IEM_Grid{:,1}),'exact'),strmatch(Table_IEM(cnt,1),char(Table_IEM_Grid{1,:}),'exact')}='UnUp';
        elseif H_D_in_vivo == 1 && H_D_in_sil == 0
            Table_IEM_Grid{strmatch(Table_IEM(cnt,2),char(Table_IEM_Grid{:,1}),'exact'),strmatch(Table_IEM(cnt,1),char(Table_IEM_Grid{1,:}),'exact')}='UpUn';
        elseif H_D_in_vivo == -1 && H_D_in_sil == 0
            Table_IEM_Grid{strmatch(Table_IEM(cnt,2),char(Table_IEM_Grid{:,1}),'exact'),strmatch(Table_IEM(cnt,1),char(Table_IEM_Grid{1,:}),'exact')}='DoUn';
        elseif H_D_in_vivo == 0 && H_D_in_sil == -1
            Table_IEM_Grid{strmatch(Table_IEM(cnt,2),char(Table_IEM_Grid{:,1}),'exact'),strmatch(Table_IEM(cnt,1),char(Table_IEM_Grid{1,:}),'exact')}='UnDo';
        elseif H_D_in_vivo == 0 && H_D_in_sil == 0
            Table_IEM_Grid{strmatch(Table_IEM(cnt,2),char(Table_IEM_Grid{:,1}),'exact'),strmatch(Table_IEM(cnt,1),char(Table_IEM_Grid{1,:}),'exact')}='UnUn';
        end
        
        cnt = cnt +1;
    end
end


% make Table with overall results
Table_sum_results{1,2} = 'up';
Table_sum_results{1,3} = 'un';
Table_sum_results{1,4} = 'down';
Table_sum_results{2,1} = 'up';
Table_sum_results{3,1} = 'un';
Table_sum_results{4,1} = 'down';
Table_sum_results{2,2} = num2str(UpUp);
Table_sum_results{2,3} = num2str(UnUp);
Table_sum_results{2,4} = num2str(DoUp);
Table_sum_results{3,2} = num2str(UpUn);
Table_sum_results{3,3} = num2str(UnUn);
Table_sum_results{3,4} = num2str(DoUn);
Table_sum_results{4,2} = num2str(UpDo);
Table_sum_results{4,3} = num2str(UnDo);
Table_sum_results{4,4} = num2str(DoDo);


NumDiseases = length(unique(Table_IEM(:,1)))
NumBiomarkers = length(unique(Table_IEM(:,2)))



clear Bio* Do* H_* IEM IEMRxns R R2 RxnsA* Un* Up* X cnt i j minR* model vars*

if strcmp(gender,'male')
    % load  Harvey1_0
    if  microbiome == 1
    save  2018_09_23_Results_IEM_Harvey_1_01_Mic
    else
    save  2018_09_23_Results_IEM_Harvey_1_01
    end
    
elseif strcmp(gender,'female')
    % load  Harvetta1_0
    if  microbiome == 1
    save  2018_09_23_Results_IEM_Harvetta_1_01_Mic
    else
    save  2018_09_23_Results_IEM_Harvetta_1_01
    end
elseif strcmp(gender,'Recon3D')
    save  2018_09_23_Results_IEM_Recon3D_Harvey_Used_in_Script_120502
end
