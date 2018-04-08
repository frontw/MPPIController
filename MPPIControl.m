function [t_, states_history, u_opt] = MPPIControl(DynamicModel, param, running_cost, terminal_cost)

	states_history = [];
	% to generate uncertainty in 'u'
	v = zeros(param.N-1, size(param.u,2));

	% optimal input
	u_opt = zeros(1,size(param.u,2));

	for loop = 0:1:param.iterations

		% update costs for all trajectories
		S = zeros(1,param.K-1);
		noise = normrnd(0,param.sigma,[size(param.u,2),param.N,param.K-1]);

		for k=1:1:param.K-1

			% initialize x
			x_0 = param.x_t0(end,:);
			t_0 = param.t0(end,:);

			x_ = x_0;
			t_ = t_0;
			% cost of individual trajectories
			for n = 2:1:param.N-1

				% adding noise to 'u'
				if k < (1 - param.alpha)*param.K   
	                v(n-1,:) = param.u(n-1,:) + noise(:,n-1,k)';            
	            else
	                v(n-1,:) = noise(:,n-1,k)';     
	            end

	            % bound on 'u'
	            for i=1:1:size(param.u,2)
	                if  v(n-1,i) > param.u_UB(i)
	                    v(n-1,i) = param.u_UB(i); 
	                elseif v(n-1,i) < param.u_LB(i)
	                    v(n-1,i) = param.u_LB(i); 
	                end
	            end

				dW = normrnd(0,param.sigma*ones(1,size(param.x_t0,2)),[1,size(param.x_t0,2)]);
				x_ = x_ + DynamicModel(t_0, x_0 ,v(n-1,:), dW)*param.dT;
				t_ = t_ + param.dT;

				% Calculate the cost
	            [cost error] = running_cost(x_,param.x_desired);

	            S(k) = S(k) + cost + param.gamma*param.u(n-1,:)*inv(diag(ones(1, size(param.u,2)))*param.sigma)*v(n-1,:)';

			end
	        S(k) = S(k) + terminal_cost(x_0,param.x_desired);

			states_history = [states_history,x_];
	        disp(['Sample: ', num2str(k), ' iteration: ', num2str(loop)...
	            , ' x: ' num2str(x_(1)), ' m',...
	            ' x_dot: ' num2str(x_(2)),...
	             ' phi: ' num2str(x_(3)), ' degrees', ...  % ' phi: ' num2str(rad2deg(x_(3))), ' degrees', ...           
	           ' phi_dot: ' num2str(x_(4)),...
	            ' Last Input: ', num2str(u_opt(end,:)), ' Sample Cost: ' num2str(S(k))])
		end

		% calculate the weights
	    weights = calculate_weights(S,param.lambda,param.K);

	    % Push the control distibution to the optimal one
	    weights_vector = zeros(param.N,1);
	    for n=1:1:param.N
	  
	        weights_sum = zeros(1,size(param.u,2));
	  
	        for k=1:1:param.K-1
	            weights_sum = weights_sum + (weights(k)*noise(:,n,k))';
	        end
	        
	        weights_vector(n,:) = weights_sum;
	    end

	    for n=1:1:param.N
	        param.u(n,:) = param.u(n,:) + weights_vector(n,:);

	        % applying bounds on 'u'
	        for i = 1:1:size(param.u,2)
	            if(param.u(n,i) < param.u_LB(i))
	                param.u(n,i) = param.u_LB(i);
	            elseif (param.u(n,i) > param.u_UB(i))
	                param.u(n,i) = param.u_UB(i);
	            end
	        end
	    end

	    if mod(loop,1) == 0
	    	u_opt = [u_opt; param.u(1,:)];

	    	dW = normrnd(0,param.sigma*ones(1,size(param.x_t0,2)),[1,size(param.x_t0,2)]);
			x_next = x_0 + DynamicModel(t_0, x_0 ,param.u(1,:), dW)*param.dT;
			t_next = t_0 + param.dT;

			param.x_t0 = x_next;
			param.t_0  = t_next;

	    	for n = 1:1:param.N-1
	            param.u(n,:) = param.u(n+1,:);
	        end
	        
	        %     Initialize the new last input with a zero
	        param.u(param.N,:) = 0;
	    end
	end
end

function weights = calculate_weights(S,lambda,samples)

    % Calculate weights
    n = 0;
    weights = zeros(1,samples);
    beta = min(S);
    for k=1:1:samples-1
        n = n + exp(-(1/lambda)*(S(k) - beta));
    end
    for k=1:1:samples-1
        weights(k) = (exp(-(1/lambda)*(S(k)-beta)))/n;
    end

end