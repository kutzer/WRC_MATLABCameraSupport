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
        % H_c2o - 4x4 array defining the camera pose relative to the UR3e
        %         base frame
        H_c2o

        % q - 6x1 array defining the UR3e joint configuration.
        q 
    end

    properties(GetAccess='public', SetAccess='private')
        % hg_c2o - scalar hgtransform object defining the camera frame 
        %          relative to the UR3e base frame).
        hg_c2o

        % simUR - UR simulation object.
        simUR
    end

    % --------------------------------------------------------------------
    % Constructor/Destructor
    % --------------------------------------------------------------------
    methods(Access='public')
        function obj = UR3eTicTacToeSim(varargin)
            % Create UR3eTicTacToeSim object
            %   obj = UR3eTicTacToeSim
            %
            %   Input(s)
            %       [NONE]
            %
            %   Output(s)
            %       [NONE]
            %
            %   M. Kutzer, 10Apr2025, USNA

            % Check input(s)
            narginchk(0,4);

            % Initialize UR object
            simUR = URsim;
            simUR.Initialize('UR3');
            hideTriad(simUR.hFrameE);
            hideTriad(simUR.hFrameT);
            for j = 0:6
                hideTriad(simUR.( sprintf('hFrame%d',j) ));
            end
            axis(simUR.Axes,'Tight');
            
            % Initialize camera frame
            hg_c2o = hgtransform('Parent',simUR.hFrame0);
            
            % Inherit tic tac toe simulation properties 
            obj = obj@TicTacToeSim(hg_c2o);

            % Set new properties 
            obj.hg_c2o = hg_c2o;
            obj.simUR = simUR;

            % Update
            obj.UpdateUR;
        end

    end

    % --------------------------------------------------------------------
    % General Use
    % --------------------------------------------------------------------
    methods(Access='public')

        function UpdateUR(obj)
            % UPDATE updates the visualization given new transformation
            % information
            %   obj.Update

            % Update camera pose
            if isempty(obj.H_c2o)
                set(obj.hg_c2o,'Visible','off');
            else
                set(obj.hg_c2o,'Visible','on','Matrix',obj.H_c2o);
            end

            % Update robot configuration
            if isempty(obj.q)
                sim = obj.simUR;
                sim.Home;
            else
                sim = obj.simUR;
                sim.Joints = obj.q;
            end
        end

    end

    % --------------------------------------------------------------------
    % Getters/Setters
    % --------------------------------------------------------------------
    methods
        % GetAccess & SetAccess ------------------------------------------

        function set.H_c2o(obj,H_in)
            % Set H_c2o

            if ~isSE(H_in,1e-8) && ~isempty(H_in)
                error('H_c2o must be a valid element of SE(3)');
            end

            obj.H_c2o = H_in;

            % Update visualization
            obj.UpdateUR;
        end

        function set.q(obj,q_in)
            % Set q

            if numel(q_in) ~= 6
                error('q must be a 6x1 array.');
            end

            obj.q = q_in;
            
            % Update visualization
            obj.UpdateUR;
        end
    end

end


