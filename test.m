% Funky diffusion code, that solves
% du/dt = D*(d^2u/dx^2) using the forward Euler method.
% MAKING D AN ARRAY NOW RATHER THAN A VARIABLE

% PLOT VALUES
Nx = 300; % Number of grid points in our simulation model
D = ones(1,Nx); % Diffusion coefficient
D_branch = 1.0;
first_cell = 171;
last_cell = 175;
for ix = 50:300  %  exit pathway
    if (ix>=first_cell) && (ix <= last_cell)
        D(ix) = 0.025;
%     elseif (ix<123) % right exit pathway
%         D(ix) = 0.85;
%     else % left exit pathway
%         D(ix) = 0.801;
    else % rest of exit pathway
         D(ix) = 0.806;
    end
end
Dx = 0.1; % Spacing between grid points in our model, larger # makes larger system length
Dt = 0.1*(Dx*Dx)/max(D); % Timestep size (choose to be numerically stable)
Nt = 100000; % Number of timesteps to run
itplot = 100; % Plot every itplot timesteps
x = (0:(Nx-1))*Dx; % Define the coordinates of the gridpoints on the spatial grid
u = 0.01*rand(1,Nx);

% PARAMETERS and ARRAY ALLOCATION
u_new = zeros(1,Nx);
v_new = zeros(1,Nx);
epsilon = 1/50;
magnify = 1/epsilon; % makes firing term large enough
a = 0.8;
b_val = 0.05;
v = zeros(1, Nx); 
b = zeros(1,Nx); % define b for each cell 
for ix = 1:Nx 
    % if we change this value to be smaller, we may not have enough mass to
    % generate a pulse and push it out of sinus node region
    if (ix<50) % if the cell is in the left region, composed of 49 cells
        b(ix) = -0.25; % set the value of b in this cell to avoid neg number
    else % right region
        b(ix) = b_val; % otherwise, set b in this cell to previous value 0.05
    end
end

N_branches = 9; % number of branches in fan-out used to model atrium
Nx_branch = 300; % number of cells in each branch
i_branch_plot = 1; % which branch to plot
b_branch = 0.05; % b_value for branches
x_branch = (Nx:(Nx + Nx_branch - 1)) * Dx; % extend coordinate system
% define arrays to keep track of u and v in each cell of each branch
u_branch = 0.01 * rand(N_branches, Nx_branch);
v_branch = zeros(N_branches, Nx_branch);
u_branch_new = zeros(N_branches, Nx_branch);
v_branch_new = zeros(N_branches, Nx_branch);
% history plots 
v_branch_point_hist = nan(1,Nt);
u_branch_point_hist = nan(1,Nt);
v_branch_point_hist2 = nan(1,Nt);
u_branch_point_hist2 = nan(1,Nt);
cell_val = 122; % which cell are we evaluating for history plots
cell_val2 = 123;
v_branch_point_hist3 = nan(1,Nt);
u_branch_point_hist3 = nan(1,Nt);
v_branch_point_hist4 = nan(1,Nt);
u_branch_point_hist4 = nan(1,Nt);
cell_val3 = Nx;
cell_val4 = Nx + 1;
% for Brian hansen traces
v_traces = nan(Nx_branch+Nx,Nt);
u_traces = nan(Nx_branch+Nx,Nt);
coupl = zeros(Nx_branch+Nx,Nt); % make a plot

% % To make video
% vidObj = VideoWriter('traces.avi');
% open(vidObj);

% Timestep loop:
for it = 1:Nt
    for ix = 2:(Nx-1) % for all the interior points of the grid...
        % Advance the value of u to the next timestep, u_new, using
        % the forward Euler method in time to represent du/dt,
        % and centered differencing in space, to represent d^2/dx^2:
        threshold = (v(ix) + b(ix)) / a; % cell fires when u > threshold
        term_excite = magnify * u(ix) * (1 - u(ix)) * (u(ix) - threshold);
        % Should be D(ix - 0.5) but we cant do non-integrer indecies
        left = D(ix) * (u(ix-1) - u(ix)) / Dx^2;
        % Should be D(ix + 0.5) but we cant do non-integrer indecies
        right = D(ix+1) * (u(ix+1) - u(ix)) / Dx^2;
        term_couple = left + right;
        u_new(ix) = u(ix) + Dt*(term_couple + term_excite);
        coupl(ix,it) = term_couple;
    end
    for ix = 1:Nx
        v_new(ix) = v(ix) + Dt*(u(ix)-v(ix));
    end
    
    % Enforce Neumann boundary conditions (du/dx=0) on the ends
    % of the system:
    thresh = (v(1) + b(1)) / a; 
    texcite = magnify * u(1) * (1 - u(1)) * (u(1) - thresh);
    right_current = D(2) * (u(2) - u(1)) / Dx^2;
    term_couple_val = right_current;
    u_new(1) = u(1) + Dt*(term_couple_val + texcite);
    coupl(1,it) = term_couple_val;
    
    % only for cell Nx
    u_new(Nx) = u(Nx) + Dt * D(Nx) * (u(Nx-1) - u(Nx))/Dx^2;
    coupl(Nx,it) = D(Nx) * (u(Nx-1) - u(Nx))/Dx^2;
    for i_branch = 1:N_branches
        u_new(Nx) = u_new(Nx) + Dt*D_branch*(u_branch(i_branch,1) - u(Nx))/Dx^2;
        coupl(Nx,it) = coupl(Nx,it) + D_branch*(u_branch(i_branch,1) - u(Nx))/Dx^2;
    end
    threshold2 = (v(Nx) + b(Nx)) / a;
    u_new(Nx) = u_new(Nx) + Dt*magnify*u(Nx)*(1 - u(Nx))*(u(Nx) - threshold2);
    
    % update each branch
    for i_branch = 1:N_branches
        % first cell of every branch
        curr_L = D_branch*(u(Nx)-u_branch(i_branch,1))/Dx^2;
        curr_R = D_branch*(u_branch(i_branch,2)-u_branch(i_branch,1))/Dx^2;
        excite_cell = magnify*u_branch(i_branch,1)*(1-u_branch(i_branch,1))...
            *(u_branch(i_branch,1)-(v_branch(i_branch,1)+b_branch)/a);
        u_branch_new(i_branch,1) = u_branch(i_branch,1)+Dt*(curr_L+curr_R+excite_cell);
        if (i_branch == 1)
            coupl(1 + Nx_branch,it) = curr_L + curr_R;
        end
        % interior cells
        for ix = 2:(Nx_branch - 1)
            term_1 = D_branch*(u_branch(i_branch,ix-1)-2*u_branch(i_branch,ix)+u_branch(i_branch,ix+1))/Dx^2;
            excite = magnify*u_branch(i_branch,ix)*(1-u_branch(i_branch,ix))...
                *(u_branch(i_branch,ix)-(v_branch(i_branch,ix)+b_branch)/a);
            u_branch_new(i_branch,ix)=u_branch(i_branch,ix)+Dt*(term_1+excite);
            if (i_branch == 1)
                coupl(ix + Nx_branch,it) = term_1;
            end
        end
        % last cell of branch
        curr_L = D_branch*(u_branch(i_branch,Nx_branch - 1)-u_branch(i_branch,Nx_branch))/Dx^2;
        excite_cell = magnify*u_branch(i_branch,Nx_branch)*(1-u_branch(i_branch,Nx_branch))...
            *(u_branch(i_branch,Nx_branch)-(v_branch(i_branch,Nx_branch)+b_branch)/a);
        u_branch_new(i_branch,Nx_branch) = u_branch(i_branch,Nx_branch)+Dt*(curr_L+excite_cell);
        for ix = 1:Nx_branch
            v_branch_new(i_branch,ix)=v_branch(i_branch,ix)+Dt*(u_branch(i_branch,ix)-v_branch(i_branch,ix));
        end
    end
    
    % Update for the next timestep:
    u = u_new;
    v = v_new;
    u_branch = u_branch_new;
    v_branch = v_branch_new;
    
    v_branch_point_hist(it) = v(cell_val-3)';
    u_branch_point_hist(it) = u(cell_val-3)';
    v_branch_point_hist2(it) = v(cell_val2+3)';
    u_branch_point_hist2(it) = u(cell_val2+3)';
    cell_val3 = Nx - 10;
    v_branch_point_hist3(it) = v(cell_val3)';
    u_branch_point_hist3(it) = u(cell_val3)';
    cell_val4 = 311;
    v_branch_point_hist4(it) = v_branch(1,10)';
    u_branch_point_hist4(it) = u_branch(1,10)';
    
    v_traces(1:Nx,it) = v;
    v_traces((Nx+1):end,it) = v_branch(1,:)';
    u_traces(1:Nx,it) = u;
    u_traces((Nx+1):end,it) = u_branch(1,:)';
    
%     % Plot every so often:
%     if (mod(it,itplot)==0)
%         figure(1);
%         x_plot = [x, x_branch];
%         u_plot = [u, u_branch(i_branch_plot,:)];
%         v_plot = [v, v_branch(i_branch_plot,:)];
%         plot(x_plot,u_plot,'b','LineWidth',2); hold on;
%         plot(x_plot,v_plot,'r','LineWidth',2); hold off;
%         axis([x_plot(1),x_plot(end),0,1]); % define the plot axes
%         title(sprintf('u and v vs. x at time %f',it*Dt));
%         xlabel('x'); ylabel('u and v');
%         drawnow;
%         % % Writing each fram to the file
%         % currFrame = getframe(gcf);
%         % writeVideo(vidObj, currFrame);
%     end
end
% close(vidObj);

%% ************ History plots **********************

% figure(2);
% plot((0:(Nt-1))*Dt,u_branch_point_hist,'r','LineWidth',2); hold on;
% plot((0:(Nt-1))*Dt,u_branch_point_hist2,'g','LineWidth',2); hold on;
% %plot((0:(Nt-1))*Dt,v_branch_point_hist,'b','LineWidth',2); hold on;
% %plot((0:(Nt-1))*Dt,v_branch_point_hist2,'k','LineWidth',2);
% %legend('u cell 1', 'v cell 1', 'u cell 2', 'v cell 2');
% legend('u cell 1', 'u cell 2');
% str = sprintf('u & v at cell 1 = %i and cell 2 = %i',cell_val,cell_val2);
% title(str);
% hold off;
% xlabel('Time'); 
% set(gca,'FontSize',16);

% % Branch point
% figure(3);
% plot((0:(Nt-1))*Dt,u_branch_point_hist3,'r','LineWidth',2); hold on;
% plot((0:(Nt-1))*Dt,u_branch_point_hist4,'g','LineWidth',2); hold on;
% %plot((0:(Nt-1))*Dt,v_branch_point_hist3,'b','LineWidth',2); hold on;
% %plot((0:(Nt-1))*Dt,v_branch_point_hist4,'k','LineWidth',2);
% %legend('u cell 1', 'v cell 1', 'u cell 2', 'v cell 2');
% legend('u cell 1', 'u cell 2');
% str = sprintf('u & v at cell 1 = %i and cell 2 = %i',cell_val3,cell_val4);
% title(str);
% hold off;
% xlabel('Time'); 
% set(gca,'FontSize',16);

%% ********** Brain Hansen Stuff // Traces **********

figure(4); %Time histories of u(x,t) & v(x,t) vs. t, number of
for ix = 1:10:(Nx+Nx_branch)
%for ix = (Nx-10):(Nx+10)
    plot((0:(Nt-1))*Dt,u_traces(ix,:)-ix*0.05,'b','LineWidth',2); hold on;
    plot((0:(Nt-1))*Dt,v_traces(ix,:)-ix*0.05,'r','LineWidth',2); hold on;
end
hold off;
xlabel('Time','FontSize',20);ylabel('x','FontSize',20);
str = sprintf('u & v for number of branches = %i, b = %f',N_branches,b(1));
title(str,'FontSize',20);
set(gca,'FontSize',16);

%% ***************** Velocity graphs *************

% use linear interpolation
num_wave = 4;
time_arr = zeros(num_wave,Nx+Nx_branch-2);
velocity = zeros(num_wave,Nx+Nx_branch-2);
refract = zeros(num_wave,Nx+Nx_branch-2);
ix_range = 51:Nx+Nx_branch-2; % includes all but sinus node
% ix_range = [70:155,205:290,350:570]; % only includes cells where D is constant for a while
ix_length = length(ix_range);
for ix = ix_range
    lower_bound = 0.1;
    it_right = zeros(1,num_wave);
    it_left = zeros(1,num_wave);
    
    for it = 34000:52000 % wave 1 full
        if (u_traces(ix,it) > lower_bound)
            it_right(1) = it;
            it_left(1) = it - 1;
            break;
        end
    end

    if (ix < first_cell) % beginning of exit pathway
        for it = 40000:48000 % wave 2
            if (u_traces(ix,it) > lower_bound)
                it_right(2) = it;
                it_left(2) = it - 1;
                break;
            end
        end
        for it = 47000:54000 % wave 3
            if (u_traces(ix,it) > lower_bound)
                it_right(3) = it;
                it_left(3) = it - 1;
                break;
            end
        end
        for it = 54000:62000 % wave 4
            if (u_traces(ix,it) > lower_bound)
                it_right(4) = it;
                it_left(4) = it - 1;
                break;
            end
        end
    
    elseif (ix >= first_cell) && (ix <= 300) % rest of exit pathway
        for it = 43800:52000 % wave 2
            if (u_traces(ix,it) > lower_bound)
                it_right(2) = it;
                it_left(2) = it - 1;
                break;
            end
        end

        for it = 57500:60000 % wave 3
            if (u_traces(ix,it) > lower_bound)
                it_right(3) = it;
                it_left(3) = it - 1;
                break;
            end
        end
    end
    
    for k = 1:num_wave
        if (it_left(k) > 0) && (it_right(k) > 0)
            if (u_traces(ix,it_left(k)) <= lower_bound) && (u_traces(ix,it_right(k)) >= lower_bound)
                big_term = (lower_bound - u_traces(ix,it_left(k))) / (u_traces(ix,it_right(k)) - lower_bound);
                alpha = big_term / (1 + big_term);
                if (alpha > 1) || (alpha < 0)
                    count = count +1;
                end
                time_arr(k,ix) = it_left(k) + alpha;
                beta = 1 - alpha;
                v_left = v_traces(ix,it_left(k));
                v_right = v_traces(ix,it_right(k));
                refract(k,ix) = (alpha*v_right + beta*v_left);
                % should be velocity (ix + 1/2) but we can only use integer indicies
                % velcoity is change in dist ( = 1) / change in time 
                velocity(k,ix) = abs(1/(time_arr(k,ix) - time_arr(k,ix-1)));
            end
        end
    end
end

figure(5); % Gradient Plot of One Wave (Vel vs. Pos)
for k = 1:ix_length
    plot(ix_range(k)*Dx,velocity(1,ix_range(k)),'o','LineWidth',2,...
        'MarkerFaceColor',[1-(ix_range(k)/600),0,(ix_range(k)/600)],...
        'MarkerEdgeColor',[1-(ix_range(k)/600),0,(ix_range(k)/600)]); hold on;
end
str = sprintf('Velocity of Action Potential');
title(str);
hold off;
xlabel('Position'); ylabel('Velocity'); 
set(gca,'FontSize',16);

figure (6); % Comparison Plot of Multiple Waves (Vel vs. Pos)
% Broken code below
% for j = 1:num_wave
%     for k = 1:ix_length
%         plot(ix_range(k)*Dx,velocity(j,ix_range(k)),'r','LineWidth',2); hold on;
%     end
% end
plot((0:(Nx+Nx_branch-3))*Dx,velocity(1,:),'r*','LineWidth',2); hold on;
plot((0:(Nx+Nx_branch-3))*Dx,velocity(2,:),'b*','LineWidth',2); hold on;
plot((0:(Nx+Nx_branch-3))*Dx,velocity(3,:),'k*','LineWidth',2); hold on;
plot((0:(Nx+Nx_branch-3))*Dx,velocity(4,:),'g*','LineWidth',2); hold on;
legend('wave 6', 'wave 7', 'wave 8', 'wave 9');
str = sprintf('Velocity of Action Potential');
title(str);
hold off;
xlabel('Position'); ylabel('Velocity'); 
set(gca,'FontSize',16);

figure(7); % Gradient Plot of One Wave (Vel vs. Ref)
for k = 1:ix_length
    plot(refract(1,ix_range(k)),velocity(1,ix_range(k)),'o','LineWidth',2,...
        'MarkerFaceColor',[1-(ix_range(k)/600),0,(ix_range(k)/600)],...
        'MarkerEdgeColor',[1-(ix_range(k)/600),0,(ix_range(k)/600)]); hold on;
end
str = sprintf('Velocity of Action Potential vs. Refractoriness');
title(str);
hold off;
xlabel('Refractoriness'); ylabel('Velocity'); 
set(gca,'FontSize',16);

figure(8); % Gradient plot of one wave (Ref vs. Pos)
for k = 1:ix_length
    plot(ix_range(k)*Dx,refract(1,ix_range(k)),'o','LineWidth',2,...
        'MarkerFaceColor',[1-(ix_range(k)/600),0,(ix_range(k)/600)],...
        'MarkerEdgeColor',[1-(ix_range(k)/600),0,(ix_range(k)/600)]); hold on;
end
str = sprintf('Refractoriness vs. Position');
title(str);
hold off;
xlabel('Position'); ylabel('Refractoriness'); 
set(gca,'FontSize',16);

figure(9); % Comparison Plot of Multiple Waves (Ref vs. Pos)
% Broken code below
% for k = 1:ix_length
%     for j = 1:1
%         plot(ix_range(k)*Dx,refract(j,ix_range(k)),'r','LineWidth',2); hold on;
%     end
% end
plot((0:(Nx+Nx_branch-3))*Dx,refract(1,:),'r*','LineWidth',2); hold on;
plot((0:(Nx+Nx_branch-3))*Dx,refract(2,:),'b*','LineWidth',2); hold on;
plot((0:(Nx+Nx_branch-3))*Dx,refract(3,:),'k*','LineWidth',2); hold on;
plot((0:(Nx+Nx_branch-3))*Dx,refract(4,:),'g*','LineWidth',2); hold on;
legend('wave 6', 'wave 7', 'wave 8', 'wave 9');
str = sprintf('Refractoriness vs. Position');
title(str);
hold off;
xlabel('Position'); ylabel('Refractoriness'); 
set(gca,'FontSize',16);

