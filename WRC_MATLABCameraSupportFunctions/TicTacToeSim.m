classdef TicTacToeSim < matlab.mixin.SetGet % Handle
    % TicTacToeSim handle class creating a simulation/visualization of the
    % EW450 Tic Tac Toe board and pieces.
    %
    %   obj = TicTacToeSim creates a simulation object for the tic tac toe
    %       board and pieces
    %
    % TicTacToeSim Methods
    %   Update  - Update visualization given pose information
    %   get     - Query properties of the object
    %   set     - Update properties of the object
    %   delete  - Delete the object and all attributes
    %
    % TicTacToeSim Properties
    % -Figure and Axes
    %   hg_c2x      - parent of the tic tac toe simulation. 
    %
    % -Transformations
    %   H_ao2c - 2-element cell array containing rigid body transformations 
    %            defining the pose of the visible board AprilTags relative
    %            to the camera frame
    %       H_ao2c{1} - pose of Tag ID 450 relative to the camera frame
    %       H_ao2c{2} - pose of Tag ID 460 relative to the camera frame
    %           * If a tag is not visible, H_ao2c{i} = []
    %
    %   H_ab2c - 5-element cell array containing rigid body transformations 
    %            defining the pose of the visible "blue/O piece" AprilTags 
    %            relative to the camera frame
    %       H_ab2c{1} - pose of Tag ID 451 relative to the camera frame
    %       H_ab2c{2} - pose of Tag ID 452 relative to the camera frame
    %           ...
    %       H_ab2c{5} - pose of Tag ID 455 relative to the camera frame
    %           * If a tag is not visible, H_ab2c{i} = []
    %
    %   H_ar2c - 5-element cell array containing rigid body transformations 
    %            defining the pose of the visible "red/X piece" AprilTags 
    %            relative to the camera frame
    %       H_ar2c{1} - pose of Tag ID 461 relative to the camera frame
    %       H_ar2c{2} - pose of Tag ID 462 relative to the camera frame
    %           ...
    %       H_ar2c{5} - pose of Tag ID 465 relative to the camera frame
    %           * If a tag is not visible, H_abrc{i} = []
    %
    %   M. Kutzer, 10Apr2025, USNA

    % Update(s)

    % --------------------------------------------------------------------
    % General properties
    % --------------------------------------------------------------------
    properties(GetAccess='public', SetAccess='public')
        H_ao2c
        H_ab2c
        H_ar2c
        hg_c2x % parent of the tic tac toe simulation. 
    end

    properties(GetAccess='public', SetAccess='private')
        % scalar hgtransform object defining the AprilTag "a450" frame 
        % relative to a known parent frame (e.g., the camera frame).
        hg_a2c 
        

        hg_ab2c
        % 1x5 hgtransform object defining the AprilTag "a451", "a451", 
        % "a451", "a451", and "a455" frames 
        % relative to a known parent frame (e.g. the camera frame).

        hg_ar2c
        %ptc_ao
        %ptc_ab
        %ptc_ar
    end
    
    % --------------------------------------------------------------------
    % Constructor/Destructor
    % --------------------------------------------------------------------
    methods(Access='public')
        function obj = TicTacToeSim(varargin)
            % Create TicTacToeSim object
            %   obj = TicTacToeSim
            %   obj = TicTacToeSim(mom)
            %   obj = TicTacToeSim(H_ao2c,H_ab2c,H_ar2c)
            %   obj = TicTacToeSim(mom,H_ao2c,H_ab2c,H_ar2c)
            %
            %   Input(s)
            %       mom    - [OPTIONAL] parent object for board simulation
            %       H_ao2c - [OPTIONAL] 2-element cell array containing 
            %                rigid body transformations defining the pose 
            %                of the visible board AprilTags relative to the
            %                camera frame
            %       H_ab2c - [OPTIONAL] 5-element cell array containing 
            %                rigid body transformations defining the pose 
            %                of the visible "blue/O piece" AprilTags 
            %                relative to the camera frame
            %       H_ar2c - [OPTIONAL] 5-element cell array containing 
            %                rigid body transformations defining the pose 
            %                of the visible "red/X piece" AprilTags 
            %                relative to the camera frame
            %
            %   Output(s)
            %       obj - TicTacToeSim object
            %
            %   M. Kutzer, 10Apr2025, USNA

            % Check input(s)
            narginchk(0,4);
            mom = [];
            H_ao2c = [];
            H_ab2c = [];
            H_ar2c = [];
            switch nargin
                case 0
                    % Known case
                case 1
                    mom = varargin{1};
                case 3
                    H_ao2c = varargin{1};
                    H_ab2c = varargin{2};
                    H_ar2c = varargin{3};
                case 4
                    mom    = varargin{1};
                    H_ao2c = varargin{2};
                    H_ab2c = varargin{3};
                    H_ar2c = varargin{4};
                otherwise
                    error('Incorrect syntax.')
            end
            
            % TODO - check inputs! 
            
            % Set defaults
            % -> Create default figure/parent 
            if isempty(mom)
                fig = figure('Name','Tic Tac Toe Simulation',...
                    'Tag','TicTacToeSim','NumberTitle','off');
                axs = axes('Parent',fig,'NextPlot','add',...
                    'DataAspectRatio',[1 1 1],'Tag','TicTacToeSim');
                view(axs,3);
                axis(axs,'tight');
                mom = hgtransform('Parent',axs,'Matrix',Ry(pi));
            end
            % -> Create default transform(s)
            if isempty(H_ao2c)
                H_ao2c = repmat({[]},1,2);
            end
            if isempty(H_ab2c)
                H_ab2c = repmat({[]},1,5);
            end
            if isempty(H_ar2c)
                H_ar2c = repmat({[]},1,5);
            end
            
            % Initialize visualization parent
            obj.hg_c2x = mom;

            % Initialize board and pieces 
            % -> Board
            obj.hg_a2c  = plotTicTacToeBoard(mom);
            set(obj.hg_a2c,'Visible','off');
            % -> Pieces
            obj.hg_ab2c = plotTicTacToePiece(mom,451:455);
            obj.hg_ar2c = plotTicTacToePiece(mom,461:465);
            set(obj.hg_ab2c,'Visible','off');
            set(obj.hg_ar2c,'Visible','off');
            % -> Hide triad text objects
            txt = findobj([obj.hg_a2c,obj.hg_ab2c,obj.hg_ar2c],...
                'Type','Text');
            set(txt,'Visible','off');

            % Add camera to visualization
            sc = 60;
            figTMP = figure('Visible','off');
            axsTMP = axes('Parent',figTMP);
            camTMP = plotCamera('Parent',axsTMP,'Size',sc/2,'Color',[0,0,1]);
            hScale = get(axsTMP,'Children');
            set(hScale,'Parent',obj.hg_c2x);
            delete(figTMP);

            % Update transforms
            obj.H_ao2c = H_ao2c;
            obj.H_ab2c = H_ab2c;
            obj.H_ar2c = H_ar2c;

            % Update plot
            obj.Update;
        end

        function delete(obj)
            % Object destructor
            fig = ancestor(obj.hg_c2x,'figure');
            delete( obj.hg_c2x );
            if isempty(fig) || ~ishandle(fig)
                return
            end
            tag = get(fig,'Tag');
            if matches(tag,'TicTacToeSim')
                delete(fig);
            end
        end

    end

    % --------------------------------------------------------------------
    % General Use
    % --------------------------------------------------------------------
    methods(Access='public')

        function Update(obj)
            % UPDATE updates the visualization given new transformation
            % information
            %   obj.Update
            
            % Update board visualization
            if isempty(obj.H_ao2c{1}) && isempty(obj.H_ao2c{2})
                set(obj.hg_a2c,'Visible','off');
            else
                set(obj.hg_a2c,'Visible','on');
            end
            if ~isempty(obj.H_ao2c{1})
                H_a2ao = eye(4); % H_{a_{450}}^{a_{450}}
                H_a2c = obj.H_ao2c{1}*H_a2ao;
                set(obj.hg_a2c,'Matrix',H_a2c);
            elseif ~isempty(obj.H_ao2c{2})
                H_a2ao = Tx(-150); % H_{a_{450}}^{a_{460}}
                H_a2c = obj.H_ao2c{1}*H_a2ao;
                set(obj.hg_a2c,'Matrix',H_a2c);
            end

            % Update blue pieces
            for i = 1:numel(obj.H_ab2c)
                if isempty(obj.H_ab2c{i})
                    set(obj.hg_ab2c(i),'Visible','off');
                else
                    set(obj.hg_ab2c(i),'Visible','on',...
                        'Matrix',obj.H_ab2c{i});
                end
            end

            % Update red pieces
            for i = 1:numel(obj.H_ar2c)
                if isempty(obj.H_ar2c{i})
                    set(obj.hg_ar2c(i),'Visible','off');
                else
                    set(obj.hg_ar2c(i),'Visible','on',...
                        'Matrix',obj.H_ar2c{i});
                end
            end
            
            % Allow MATLAB to update
            drawnow;
        end

    end

    % --------------------------------------------------------------------
    % Getters/Setters
    % --------------------------------------------------------------------
    methods
        % GetAccess & SetAccess ------------------------------------------

        function set.H_ao2c(obj,H_in)
            % Set H_ao2c

            % Initial value
            if isempty(obj.H_ao2c)
                obj.H_ao2c = H_in;
                return
            end

            n = 2;
            if ~iscell(H_in)
                error('H_ao2c must be a 1x%d cell array.',n);
            end
            if numel(H_in) < n
                H_in{n} = [];
            end
            obj.H_ao2c = H_in;

            % Update visualization
            obj.Update;
        end

        function set.H_ab2c(obj,H_in)
            % Set H_ab2c

            % Initial value
            if isempty(obj.H_ab2c)
                obj.H_ab2c = H_in;
                return
            end

            n = 5;
            if ~iscell(H_in)
                error('H_ab2c must be a 1x%d cell array.',n);
            end
            if numel(H_in) < n
                H_in{n} = [];
            end
            obj.H_ab2c = H_in;

            % Update visualization
            obj.Update;
        end

        function set.H_ar2c(obj,H_in)
            % Set H_ar2c

            % Initial value
            if isempty(obj.H_ar2c)
                obj.H_ar2c = H_in;
                return
            end

            n = 5;
            if ~iscell(H_in)
                error('H_ar2c must be a 1x%d cell array.',n);
            end
            if numel(H_in) < n
                H_in{n} = [];
            end
            obj.H_ar2c = H_in;

            % Update visualization
            obj.Update;
        end

        function set.hg_c2x(obj,mom)
            % Set hg_c2x (simulation parent)

            % Initial value
            if isempty(obj.hg_c2x)
                obj.hg_c2x = mom;
                return
            end

            figTMP = ancestor(obj.hg_c2x,'figure');
            kids = get(obj.hg_c2x,'Children');
            try
                set(kids,'Parent',mom);
            catch ME
                error('Specified parent is not valid.');
            end
            obj.hg_c2x = mom;
            delete(figTMP);
        end

    end

end