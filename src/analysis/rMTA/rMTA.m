function [TSscore, deletedGenes, Vres] = rMTA(model, rxnFBS, Vref, varargin)
% Calculate robust Metabolic Transformation Analysis (rMTA) using the
% solver CPLEX.
% Code was prepared to be able to be stopped and be launched again by using
% a temporally file called 'temp_rMTA.mat'.
%
% USAGE:
%
%    [TSscore,deletedGenes,Vout] = rMTA(model, rxnFBS, Vref,...
%                                       alpha, epsilon, varargin)
%
% INPUTS:
%    model:           Metabolic model structure (COBRA Toolbox format).
%    rxnFBS:          Array that contains the desired change: Forward,
%                     Backward and Unchanged (+1;0;-1). This is calculated
%                     from the rules and differential expression analysis.
%    Vref:            Reference flux of the source state.
%
% OPTIONAL INPUT:
%    alpha:           Numeric value or array. Parameter of the quadratic
%                     problem (default = 0.66)
%    epsilon:         Numeric value or array. Minimun perturbation for each
%                     reaction (default = 0)
% 
% OPTIONAL INPUT (name-value pair):
%    rxnKO            Binary value. Calculate knock outs at reaction level 
%                     instead of gene level. (default = false)
%    timelimit        Time limit for the calculation of each knockout.
%                     (default = inf)
%    SeparateTranscript - Character used to separate
%                         different transcripts of a gene. (default = '')
%                         Example: SeparateTranscript = ''
%                                   gene 10005.1    ==>    gene 10005.1
%                                   gene 10005.2    ==>    gene 10005.2
%                                   gene 10005.3    ==>    gene 10005.3
%                                  SeparateTranscript = '.'
%                                   gene 10005.1
%                                   gene 10005.2    ==>    gene 10005
%                                   gene 10005.3
%    numWorkers        Integer: is the maximun number of workers
%                      used by the solver. 0 = automatic, 1 = sequential,
%                         >1 = parallel. (default = 0)
%    printLevel        Integer. 1 if the process is wanted to be shown
%                      on the screen, 0 otherwise. (default = 1)
%
% OUTPUTS:
%    Outputs are cell array for each alpha (one simulation by alpha). It
%    there is only one alpha, content of cell will be returned
%    TSscore:         Transformation score by each transformation
%    deletedGenes:    The list of genes/reactions removed in each knock-out
%    Vref:            Matrix of resulting fluxes
%
% .. Authors:
%       - Luis V. Valcarcel, 03/06/2015, University of Navarra, CIMA & TECNUN School of Engineering.
% .. Revisions:
%       - Luis V. Valcarcel, 26/10/2018, University of Navarra, CIMA & TECNUN School of Engineering.
%       - Francisco J. Planes, 26/10/2018, University of Navarra, TECNUN School of Engineering.


%% Check the input information
p = inputParser;
% check requiered arguments
addRequired(p, 'model');
addRequired(p, 'rxnFBS');
addRequired(p, 'Vref');
% Check optional arguments
addOptional(p, 'alpha', 0.66);
addOptional(p, 'epsilon', 0);
% Add optional name-value pair argument
addParameter(p, 'rxnKO', false);
addParameter(p, 'timelimit', inf);
addParameter(p, 'SeparateTranscript', '');
addParameter(p, 'numWorkers', 0);
addParameter(p, 'printLevel', 1);
% extract variables from parser
parse(p);
alpha = p.Results.alpha;
epsilon = p.Results.epsilon;
rxnKO = p.Results.rxnKO;
timelimit = p.Results.timelimit;
SeparateTranscript = p.Results.SeparateTranscript;
numWorkers = p.Results.numWorkers;
printLevel = p.Results.printLevel;


if printLevel >0
    fprintf('===================================\n');
    fprintf('========  rMTA algorithm  =========\n');
    fprintf('===================================\n');
    fprintf('Step 0: preprocessing: \n');
end


%% Initialize variables or load previously ones
%  Check if there are any temporary files with the rMTA information

num_alphas = numel(alpha);

% Calculate perturbation matrix
if rxnKO
    geneKO.genes = model.rxns;
    geneKO.rxns = model.rxns;
    geneKO.rxns = speye(numel(model.rxns));
else
    geneKO = calculateGeneKOMatrix(model, SeparateTranscript, printLevel);
end

% Reduce the size of the problem;
geneKO2 = geneKO;
[geneKO.matrix,geneKO.IA,geneKO.IC ] = unique(geneKO.matrix','rows');
geneKO.matrix = geneKO.matrix';
geneKO.genes = num2cell((1:length(geneKO.IA))');


if ~exist('temp_rMTA.mat','file')
    % Boolean variable for each case
    best = false;
    moma = false;
    worst = false;
    % counters
    i = 0;          % counter for best scenario
    i_alpha = 0;    % counter for best scenario alphas
    j = 0;          % counter for moma scenario
    k = 0;          % counter for worst scenario
    k_alpha = 0;    % counter for worst scenario alphas
    % scores
    score_best = zeros(numel(geneKO.genes),num_alphas);
    score_moma = zeros(numel(geneKO.genes),1);
    score_worst = zeros(numel(geneKO.genes),num_alphas);
    % fluxes
    Vres = struct();
    Vres.bMTA = cell(num_alphas,1);
    Vres.bMTA(:) = {zeros(numel(model.rxns),numel(geneKO.genes))};
    Vres.mMTA = zeros(numel(model.rxns),numel(geneKO.genes));
    Vres.wMTA = cell(num_alphas,1);
    Vres.wMTA(:) = {zeros(numel(model.rxns),numel(geneKO.genes))};
else
    load('temp_rMTA.mat');
    i_alpha = max(i_alpha-1,0);
    i = max(i-100,0);
    k_alpha = max(k_alpha-1,0);
    k = max(k-100,0);
end

if printLevel >0
    fprintf('-------------------\n');
end

%% ---- STEP 1 : The best scenario: bMTA ----

if printLevel >0
    fprintf('Step 1 in progress: the best scenario \n');
end
timerVal = tic;

% treat rxnFBS to remove impossible changes
rxnFBS_best = rxnFBS;
rxnFBS_best(rxnFBS_best==-1 & abs(Vref)<1e-6 & model.lb==0) = 0;
clear v_res

if best
    if printLevel >0
        fprintf('\tAll MIQP for all alphas performed\n');
    end
else
    while i_alpha < num_alphas
        i_alpha = i_alpha + 1;
        if printLevel >0
            fprintf('\tStart rMTA best scenario case for alpha = %1.2f \n',alpha(i_alpha));
        end
        
        % Create the CPLEX model
        CplexModelBest = MTA_model (model, rxnFBS_best, Vref, alpha(i_alpha), epsilon);
        if printLevel >0
            fprintf('\tcplex model for MTA built\n');
        end
        
        % perform the MIQP problem for each rxn's knock-out
        if printLevel >0
            showprogress(0, '    MIQP Iterations for bMTA');
        end
        while i < length(geneKO.genes)
            for w = 1:100
                i = i+1;
                KOrxn = find(geneKO.matrix(:,i));
                v_res = MTA_MIQP (CplexModelBest, KOrxn, numWorkers, timelimit, printLevel);
                Vres.bMTA{i_alpha}(:,i) = v_res;
                if ~isempty(KOrxn) && norm(v_res)>1
                    score_best(i,i_alpha) = MTA_TS(v_res,Vref,rxnFBS_best);
                else
                    % if we knock off the system, invalid solution
                    % remove perturbations with no effect score
                    score_best(i,i_alpha) = -Inf;
                end
                if printLevel >0
                    showprogress(i/length(geneKO.genes), '    MIQP Iterations for bMTA');
                end
                % Condition to exit the for loop
                if i == length(geneKO.genes)
                    break;
                end
            end
            try save('temp_rMTA.mat', 'i','j','k','i_alpha','k_alpha','best','moma','worst','score_best','score_moma','score_worst','Vres'); end
        end
        clear cplex_model
        if printLevel >0
            fprintf('\n\tAll MIQP problems performed\n');
        end
        i = 0;
    end
    best = true;
end

time_best = toc(timerVal);
if printLevel >0
    fprintf('\tStep 1 time: %4.2f seconds = %4.2f minutes\n',time_best,time_best/60);
end
try save('temp_rMTA.mat', 'i','j','k','i_alpha','k_alpha','best','moma','worst','score_best','score_moma','score_worst','Vres'); end
fprintf('-------------------\n');


%% ---- STEP 2 : MOMA ----
% MOMA is the most robust result

fprintf('Step 2 in progress: MOMA\n');
timerVal = tic;

% Create the CPLEX model
% variables
v = 1:length(model.rxns);
ctype(v) = 'C';
n_var = v(end);

% Objective fuction
% linear part
c(v) = -2*Vref;
% quadratic part
Q = 2*eye(n_var);

cplex_model_moma.A = model.S;
cplex_model_moma.lb = model.lb;
cplex_model_moma.ub = model.ub;
cplex_model_moma.lhs = zeros(size(model.mets));
cplex_model_moma.rhs = zeros(size(model.mets));
cplex_model_moma.obj = c;
cplex_model_moma.Q = Q;
cplex_model_moma.sense = 'minimize';
cplex_model_moma.ctype = ctype;
fprintf('\tcplex model for MOMA built\n');

% perform the MOMA problem for each rxn's knock-out
clear v_res success unsuccess

if moma
    if printLevel >0
        fprintf('\tAll MOMA problems performed\n');
    end
else
    if printLevel >0
        showprogress(0, '    QP Iterations for MTA');
    end
    while j < length(geneKO.genes)
        for w = 1:100
            j = j+1;
            KOrxn = find(geneKO.matrix(:,j));
            clear cplex_moma
            cplex_moma = Cplex('MOMA');
            cplex_moma.Model = cplex_model_moma;
            cplex_moma.DisplayFunc = [];
            cplex_moma.Model.ub(KOrxn) = 0;
            cplex_moma.Model.lb(KOrxn) = 0;
            cplex_moma.solve();
            % if we knock off the system, invalid solution
            if cplex_moma.Solution.status==101 ||cplex_moma.Solution.status==1
                v_res = cplex_moma.Solution.x;
                Vres.mMTA(:,j) = v_res;
                if ~isempty(KOrxn) && norm(v_res)<1    % the norm(Vref) ~= 1e4
                    score_moma(j) = -Inf;
                else
                    % remove inactive reactions score
                    score_moma(j) = MTA_TS(v_res,Vref,rxnFBS_best);
                end
            else
                Vres.mMTA(:,j) = 0;
                score_moma(j) = -Inf;
            end
            clear v_aux success
            if printLevel >0
                showprogress(j/length(geneKO.genes), '    QP Iterations for MTA');
            end
            % Condition to exit the for loop
            if j == length(geneKO.genes)
                break;
            end
        end
        try save('temp_rMTA.mat', 'i','j','k','i_alpha','k_alpha','best','moma','worst','score_best','score_moma','score_worst','Vres'); end
    end
    clear cplex_model cplex_moma
    if printLevel >0
        fprintf('\n\tAll MOMA problems performed\n');
    end
    moma = true;
end

time_moma = toc(timerVal);
if printLevel >0
    fprintf('\tStep 2 time: %4.2f seconds = %4.2f minutes\n',time_moma,time_moma/60);
end
try save('temp_rMTA.mat', 'i','j','k','best','moma','worst','score_best','score_moma','score_worst','Vres'); end
fprintf('-------------------\n');


%% ---- STEP 3 : The worst scenario ----
% Worst scenario is MTA but maximizing the changes in the wrong
% sense

if printLevel >0
    fprintf('Step 3 in progress: the worst scenario \n');
end
timerVal = tic;

%generate the worst rxnFBS
rxnFBS_worst = -rxnFBS;
rxnFBS_worst(rxnFBS_worst==-1 & abs(Vref)<1e-6 & model.lb==0) = 0;
clear v_res

if worst
    if printLevel >0
        fprintf('\tAll MIQP problems performed\n');
    end
else
    while k_alpha < num_alphas
        k_alpha = k_alpha + 1;
        if printLevel >0
            fprintf('\tStart rMTA worst scenario case for alpha = %1.2f \n',alpha(k_alpha));
        end
        
        CplexModelWorst = MTA_model(model, rxnFBS_worst, Vref,  alpha(k_alpha), epsilon);
        if printLevel >0
            fprintf('\tcplex model for MTA built\n');
        end
        
        if printLevel >0
            showprogress(0, '    MIQP Iterations for wMTA');
        end
        while k < length(geneKO.genes)
            for w = 1:100
                k = k+1;
                KOrxn = find(geneKO.matrix(:,k));
                v_res = MTA_MIQP (CplexModelWorst, KOrxn, numWorkers, timelimit, printLevel);
                Vres.wMTA{k_alpha}(:,k) = v_res;
                if ~isempty(KOrxn) && norm(v_res)>1
                    score_worst(k,k_alpha) = MTA_TS(v_res,Vref,rxnFBS_worst);
                else
                    % if we knock off the system, invalid solution
                    % remove perturbations with no effect score
                    score_worst(k, k_alpha) = -Inf;
                end
                if printLevel >0
                    showprogress(k/length(geneKO.genes), '    MIQP Iterations for wMTA');
                end
                % Condition to exit the for loop
                if k == length(geneKO.genes)
                    break;
                end
            end
            try save('temp_rMTA.mat', 'i','j','k','i_alpha','k_alpha','best','moma','worst','score_best','score_moma','score_worst','Vres'); end
        end
        clear cplex_model
        fprintf('\n\tAll MIQP problems performed\n');
        k = 0;
    end
    worst = true;
end

time_worst = toc(timerVal);
if printLevel >0
    fprintf('\tStep 3 time: %4.2f seconds = %4.2f minutes\n',time_worst,time_worst/60);
end
try save('temp_rMTA.mat', 'i','j','k','i_alpha','k_alpha','best','moma','worst','score_best','score_moma','score_worst','Vres'); end
fprintf('-------------------\n');


%% ---- STEP 4 : Return to gene size ----

aux = geneKO;
geneKO = geneKO2;

% scores
score_best = score_best(aux.IC,:);
score_moma = score_moma(aux.IC,:);
score_worst = score_worst(aux.IC,:);
% fluxes
for i = 1:num_alphas
    Vres.bMTA{i} = Vres.bMTA{i}(:,aux.IC);
    Vres.wMTA{i} = Vres.wMTA{i}(:,aux.IC);
end
Vres.mMTA = Vres.mMTA(:,aux.IC);

% Define one of the outputs
deletedGenes = geneKO.genes;

%% ---- STEP 5 : Calculate the rMTA TS score ----

score_rMTA = zeros(numel(geneKO.genes),num_alphas);

for i = 1:num_alphas
    T = table(geneKO.genes, score_best(:,i), score_moma, score_worst(:,i));
    T.Properties.VariableNames = {'gene_ID','score_best','score_moma','score_worst'};
    
    % if wTS or bTS are infinite, delete the solution
    T.score_moma(T.score_best<-1e30) = -inf;
    T.score_moma(T.score_worst<-1e30) = -inf;
    
    % rMTA score
    score_aux = T.score_best - T.score_worst;
    score_aux = score_aux .* T.score_moma;
    idx = (T.score_best<0 & T.score_moma<0 & score_aux>0);
    score_aux(idx) = -score_aux(idx);
    idx = (T.score_best<0 & score_aux>0);
    score_aux(idx) = -score_aux(idx);
    idx = (T.score_best<T.score_worst & score_aux>0);
    score_aux(idx) = -score_aux(idx);
    
    % store
    score_rMTA(:,i) = score_aux;
end

% save results
TSscore = struct();
TSscore.bTS = score_best;
TSscore.mTS = score_moma;
TSscore.wTS = score_worst;
TSscore.rTS = score_rMTA;

delete('temp_rMTA.mat')
end

