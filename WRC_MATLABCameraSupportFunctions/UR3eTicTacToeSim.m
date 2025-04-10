classdef UR3eTicTacToeSim < TicTacToeSim % Handle
    % UR3eTicTacToeSim handle class creating a simulation/visualization of 
    % the EW450 Tic Tac Toe board and pieces with a UR3e for context.
    %
    %   obj = UR3eTicTacToeSim
    %
    %   M. Kutzer, 10Apr2025, USNA

    % Update(s)

    % --------------------------------------------------------------------
    % General properties
    % --------------------------------------------------------------------
    properties(GetAccess='public', SetAccess='public')
        H_c2o
        q 
    end

    properties(GetAccess='public', SetAccess='private')
        hg_c2o
        simUR
    end

    % --------------------------------------------------------------------
    % Constructor/Destructor
    % --------------------------------------------------------------------
    methods(Access='public')
        function obj = UR3eTicTacToeSim(varargin)

            simUR = URsim;
            simUR.Initialize('UR3');
            hideTriad(simUR.hFrameE);
            hideTriad(simUR.hFrameT);
            for j = 0:6
                hideTriad(simUR.( sprintf('hFrame%d',j) ));
            end

            hg_c2o = hgtransform('Parent',simUR.hFrame0);

            obj = obj@TicTacToeSim(hg_c2o);
            obj.hg_c2o = hg_c2o;
            obj.simUR = simUR;

        end

    end
end


