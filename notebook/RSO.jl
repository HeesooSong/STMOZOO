### A Pluto.jl notebook ###
# v0.17.3

using Markdown
using InteractiveUtils

# ╔═╡ 0150a3e2-f98e-4412-9e96-1a2db5a9421e
using Combinatorics, Plots, Statistics, Distributions, MLDatasets, Flux, CUDA, Test

# ╔═╡ 352a4a75-8136-474e-a80a-9d65baabd195
using Flux: Data.DataLoader

# ╔═╡ 79d4c2f0-bc6e-43f1-b877-a63226f8aadc
using Flux: onehotbatch, onecold, crossentropy

# ╔═╡ de52e90b-cdee-4221-b502-8a4d128bcc79
using Flux: @epochs

# ╔═╡ 261dd1eb-3158-4c20-aec7-01c4dfeab897
using Base: @kwdef

# ╔═╡ 4372356d-92f6-45f0-97c0-f28b2299a5a8
using Flux.Losses: logitcrossentropy

# ╔═╡ 936344da-213a-11ec-3e68-05f0f85cf2f3
md"""
# RSO: Fitting a neural network by optimizing one weight at a time

*STMO*

**Heesoo SONG**
"""

# ╔═╡ 8c3625c6-4537-4a32-9a8d-ea33cf5ee7df
md"**IMPORTANT!! Install MLDatasets packages first:\
Pkg.add(\"MLDatasets\")**"

# ╔═╡ 62c4926d-0350-4088-8729-0ee5afb306be
md"""
## 0. Introduction

### Research Goal

> **(1)** Propose RSO (random search optimization), a new weight update scheme for training deep neural networks, and **(2)** compare its accuracy to backpropagation.

\

### RSO: Random Search Optimization

RSO is a new weight update algorithm for training deep neural networks which explores the region around the initialization point by sampling weight changes to minimize the objective function. The idea is based on the assumption that the initial set of weights is already close to the final solution, as deep neural networks are heavily over-parametrized. Unlike traditional backpropagation in training deep neural networks that involves estimation of gradient at a given point, **RSO is a gradient-free method that searches for the update one weight at a time with random sampling**. The formal expression of the RSO update rule is as following:

$$w_{i+1}=\Bigg\{ \begin{align*}
&wᵢ,\qquad \qquad f(x, wᵢ)\leq f(s,wᵢ+\Delta wᵢ)\\
&wᵢ+\Delta wᵢ,\quad f(x, wᵢ)>f(s,wᵢ+\Delta wᵢ)
\end{align*}$$
, where $\Delta wᵢ$ is the weight change hypothesis.

According to the paper, there are some **advantages** in using RSO over using backpropagation(SGD). 
- RSO gives very close classification accuracy to SGD in a very few rounds of updates.
- RSO requires fewer weight updates compared to SGD to find good minimizers for deep neural networks.
- RSO can make aggressive weight updates in each step as there is no concept of learning rate.
- The weight update step for individual layers is not coupled with the magnitude of the loss.
- As a new optimization method in training deep neural networks, RSO potentially lead to a different class of training architectures.

However, RSO also has a **drawback** in terms of computational cost. Since it requires updates which are proportional to the number of network parameters, it can be very computationally expensive. The author of the paper however suggests that this issue can be solved and could be a viable alternative to back-propagation if the number of trainable parameters are reduced drastically as in [3].

In the following sections, we will reproduce the RSO function and compare its classification accuracy to the classical backpropagation method (SGD). In addition, we will have a look how the RSO algorithm performs in different models and batch sizes. To save your time, we used a simple model with one convolutional layer rather than the original model from the paper which was comprised of 6 convolutional layers.
"""

# ╔═╡ 98e7978d-2355-407c-b87f-c0bd64b430aa


# ╔═╡ 8cd1b08a-644e-4cdb-87ab-6f7270a29681
md"## 1. Construct RSO function"

# ╔═╡ 9bb4e28e-dd24-451c-9e95-205ba2e084ef
md"""### 1-1. Parameters 
RSO function is constructed by following the pseudocode provided in the paper. The variables used in the pseudocode are explained below:

![Notation4Variables.png](https://github.com/HeesooSong/STMOZOO/blob/master/notebook/Figures/Notation4Variables.png?raw=true)

>\- $$W = \{W_1,...,W_d,...,W_D\}$$ = Weight set of layers \
>\- $$W_d = \{w_1,...,w_{i_d},...,w_{n_d}\}$$ = Weight tensors of layer d that generates an activation set $$A_d = \{a_1,...,a_{i_d},...,a_{n_d}\}$$\
>\- $$w_{i_d}$$ = a weight tensor that generates an activation $a_{i_d}$\
>\- $$w_j$$ = a weight in wid
"""

# ╔═╡ 198f91c6-46dc-46dc-a013-c3064a7348cd
md"### 1-2. Pseudocode

![Pseudocode.png](https://github.com/HeesooSong/STMOZOO/blob/master/notebook/Figures/Pseudocode.png?raw=true)
"

# ╔═╡ 5e51a853-8736-4f92-b7f4-216ff4ab0b90
md"First, the weights are initialized by following the Gaussian distribution $$N(0, \sqrt{2/|w_{i_d}|})$$ assuming that the initial weights of convolutional neural network is already close to the final solution. $$|w_{i_d}|$$ means the number of parameters in the weight set $$w_{i_d}$$. Then compute standard deviation of all elements in the weight tensor $$W_d$$.

Next, weight update is performed. The weights of the layer closest to the labels 
are updated first and then sequentially move closer to the input. For each weight, the change is randomly sampled from Gaussian distribution $$N(0, \sigma_d)$$, in which the standard deviation computed in the initialization step. Then losses are computed for three different weight change scenario $$(W+\Delta W_j, W, W-\Delta W_j)$$ and compared. The weight set that gives minimum loss value is taken. 

To note again, this update is perfomed on one weight at a time for every weights. Through C number of rounds (epochs) of these updates, model can be improved further."

# ╔═╡ bc0e3c51-16e1-47d1-8372-268debce32fa
md"### 1-3. RSO function"

# ╔═╡ 75f178d4-85d5-4591-89f7-a4e359a04f0b


# ╔═╡ 11872972-0526-4c07-902b-0b8f3ac0553f
md"## 2. Experiment - compare RSO & SGD
Here we will use MNIST dataset for the training. MNIST dataset is consists of 60,000 training images and 10,000 test images of handwritten digits. Each image is a 28x28 pixel gray-scale image. Based on this dataset, we will compare the classification accuracy of RSO and SGD. The box below is the training variables that can be changed.
"

# ╔═╡ 5b844fba-dae3-4945-a57e-d76caf8ee0df
md"### 2-1. SGD (Backpropagation)

For OneConv_model with 32 batch size, it takes around 100 seconds to compute 10 epochs."

# ╔═╡ 0f00bfef-32fe-489d-93e7-669c89af6eff
md"### 2-2. RSO

For OneConv_model with 32 batch size, it takes around 200 seconds to compute 10 epochs."

# ╔═╡ 94c436d1-d4c1-4eb1-8940-e8b12e608b30
md"### 2-3. Result"

# ╔═╡ 82f5a6d7-c15d-4350-b5fd-8aaa16229740
md"""
##### 1) RSO performance summary:

|                   |    Round   |    batch    |   time(s) |    loss    |   acc   |
|:------------------|------------|-------------|-----------|------------|---------|
| **Original model**|    1       |      256    |   5240    |   -        |   -     |
|                   |    1       |    1000     |  73042    |     -      |    -    |
|                   |            |             |           |            |         |
|                   |            |             |           |            |         |
| **TwoConv model** |    10      |    32       |   1457    | 0.5126024  | 0.8504  |
|                   |    10      |   512       |  19186    | 0.19334497 | 0.9397  |
|                   |    10      |  1000       |  36464    | 0.12634973 | 0.9604  |
|                   |            |             |           |            |         |
|                   |            |             |           |            |         |
| **OneConv model** |    10      |    32       |   212     | 0.6316686  | 0.8075  |
|                   |    10      |    64       |   345     | 0.55254054 | 0.8353  |
|                   |    10      |    256      |   1641    | 0.37202972 | 0.8929  |
|                   |    10      |    512      |   2834    | 0.29727805 | 0.9152  |
|                   |    10      |    1024     |   5046    | 0.3011675  | 0.9148  |

**This table is generated by myself through several experiments to show the performance of RSO in different conditions.** Please note that these experiments could not be generated user-interactively since the running time was insanely long for certain experiments. Different models are explained in `3-1.2) Model Structures`. The loss and accuracy are not recorded in original model since it took immensive amount of time in training with original model even for 1 round (epoch). In both simpler models, it can be observed that the loss and accuracy improves as the batch size increases. This is because the loss calculation for weight updates were based on larger samples which lead to more precise reflection of the model (line 63, 68, 73 in RSO function). Furthermore, the generall loss and accuracy was better in TwoConv model than OneConv model.
"""

# ╔═╡ 27df401a-709d-4c73-bd4c-5333572ab233
md"##### 2) Accuracy Comparison"

# ╔═╡ 0082e604-f8bf-4e89-a3b3-f168c6e04efa
md"Although it seems that RSO is lagging behind SGD in this plot, we have to consider that it was not the best model that can be applied due to practical reasons. As shown above in `1) RSO performance summary`, the accuracy can peak 96.04% even with a little bit of more complexity in the model with larger batch size. According to the paper, RSO can perform 99.12% of accuracy after 50 cycles of updates with MNIST dataset, while the SGD gives 99.27% of accuracy after 50 epochs. Thus, one may consider using random sampling method than back-propagation methods for training neural networks as proposed and demonstrated in the paper."

# ╔═╡ 6d9fa03d-cd79-416a-b686-d244afdba854


# ╔═╡ 5afd91f6-9e0d-4774-a954-3f00b71dd2e7
md"## 3. Appendix (Source code)"

# ╔═╡ f7c0cb4b-c98a-404d-96f6-7a20f167d11d
md"### 3-1. CNN training functions

The baseline of the training structure is referred from FluxML/model-zoo tutorial notebook [2].

##### 1) Create mini-batch iterators (DataLoaders)
Prepare dataset for training. This involves loading data, adding channel layer, encoding, and creating DataLoader object."

# ╔═╡ f6a38e02-f53f-440d-934b-4ed1f00d1827
function getdata(args, device)
	ENV["DATADEPS_ALWAYS_ACCEPT"] = "true"
	
	# load data
	if args.dataset == "MNIST"
		x_train, y_train = MNIST.traindata(Float32)
		x_test, y_test = MNIST.testdata(Float32)
	elseif args.dataset == "CIFAR10"
		x_train, y_train = CIFAR10.traindata(Float32)
		x_test, y_test = CIFAR10.testdata(Float32)
	end
	
	# Add channel layer
	# The unsqueeze() function helps image data to be in order of (width, height, #channels, batch size)
	x_train = Flux.unsqueeze(x_train, 3)
	x_test = Flux.unsqueeze(x_test, 3)
	
	# Encode labels
	y_train = onehotbatch(y_train, 0:9)
	y_test = onehotbatch(y_test, 0:9)

	# Create DataLoaders (mini-batch iterators)
	train_loader = DataLoader((x_train, y_train), batchsize=args.batchsize, shuffle=true)
	test_loader = DataLoader((x_test, y_test), batchsize=args.batchsize)
	
	return train_loader, test_loader
end

# ╔═╡ 85f193d7-7382-445d-8213-870aba58af71
md"##### 2) Model structures
- **Original model:** Original model is the model described in the paper. It is comprised of 6 convolutional layers with mean pooling layer in every two convolutional layers.
- **TwoConv model:** Simplified model for algorithm test. It contains two convolutional layers.
- **OneConv model:** Further simplified model for algorithm test. It contains only one convolutional layer."

# ╔═╡ 965d6f22-5522-416f-ab1e-e66623262e90
function original_model(; imgsize=(28, 28, 1), nclasses=10)
	# This is the model described in the paper
	return Chain(
	# input 28x28x1
	Conv((3,3), 1=>16, pad=1), BatchNorm(16, relu), 	 # 28x28x16
	Conv((3,3), 16=>16, pad=1), BatchNorm(16, relu), 	 # 28x28x16
	MeanPool((2, 2)), 								 	 # 14x14x16
	Conv((3,3), 16=>16, pad=1), BatchNorm(16, relu), 	 # 14x14x16
	Conv((3,3), 16=>16, pad=1), BatchNorm(16, relu), 	 # 14x14x16
	MeanPool((2, 2)), 								 	 # 7x7x16
	Conv((3,3), 16=>16, pad=1), BatchNorm(16, relu), 	 # 7x7x16
	Conv((3,3), 16=>16, pad=1), BatchNorm(16, relu), 	 # 7x7x16

	# Average pooling on each width x height feature map
	GlobalMeanPool(),
	# Remove 1x1 dimensions (singletons)
	flatten,
	
	Dense(16, nclasses),
	softmax)
end

# ╔═╡ 399f02e7-81ef-4f06-9df3-a3857532654a
function TwoConv_model(; imgsize=(28, 28, 1), nclasses=10)
	# Simpler model to test algorithm
	cnn_output_size = Int.(floor.([imgsize[1]/4,imgsize[2]/4,16]))
	
	return Chain(
	# input 28x28x1
	Conv((3,3), 1=>16, pad=1, relu), 	#14x14x16
	MaxPool((2,2)),
	Conv((3,3), 16=>16, pad=1, relu), 	#7x7x16
	MaxPool((2,2)),
	
	flatten,
	
    Dense(prod(cnn_output_size), nclasses))
end

# ╔═╡ f8d655ea-db55-4fd5-b324-25987b9d200d
function OneConv_model(; imgsize=(28, 28, 1), nclasses=10)
	# Simpler model to test algorithm
	cnn_output_size = Int.(floor.([imgsize[1]/2,imgsize[2]/2,4]))
	
	return Chain(
	# input 28x28x1
	Conv((3,3), 1=>4, pad=1, relu), 	#14x14x16
	MaxPool((2,2)),
	
	flatten,
	
    Dense(prod(cnn_output_size), nclasses))
end

# ╔═╡ f51a102a-bb79-47b5-b1dd-d04992bf2ba0
md"##### 3) Loss and accuracy"

# ╔═╡ 0d7b525d-3f30-44fc-b771-1665d3f2e045
function loss_and_accuracy(data_loader, model, device)
	acc = 0
	ls = 0.0f0
	num = 0
	for (x, y) in data_loader
		x, y = device(x), device(y)
		ŷ = model(x)
		ls += logitcrossentropy(ŷ, y, agg=sum)
		acc += sum(onecold(ŷ) .== onecold(y))
		num += size(x)[end]
	end
	return ls/num, acc/num
end

# ╔═╡ 28a8be56-c56b-49db-b57d-0a676d7f7f47
md"##### 4) Training main body"

# ╔═╡ 796aa432-e28f-4243-92c0-934f4e4f022f
md"### 3-2. Tracker

These tracker functions are brought directly from the lecture notebook `searching_methods.jl`. A tracker is a data structure to keep track of the training loss during the run of the algorithm."

# ╔═╡ f622af0a-033b-48c5-aedb-e86926b731a4
abstract type Tracker end

# ╔═╡ 86ced829-524f-4948-9df9-6812762c8fa3
struct NoTracking <: Tracker end

# ╔═╡ 07e1abb3-dcf9-4632-bf07-ce128296dfd5
notrack = NoTracking()

# ╔═╡ 72482d89-c3f1-479c-b06c-da73259f68b0
@kwdef mutable struct Args
	tracker::Tracker=notrack    # track loss or accuracy
	use_cuda::Bool = false      # use gpu (if gpu available - not tested)
	ŋ::Float64 = 0.01    	    # learning rate
	batchsize::Int = 256 	    # batch size
	epochs::Int = 1 	 	    # number of epochs
	dataset::String = "MNIST"   # MNIST or CIFAR10
	optimiser::String = "SGD"   # SGD or RSO
	model::String = "OneConv"   # Original or TwoConv or OneConv
end

# ╔═╡ 08eb9335-3ba7-4f18-bd7f-dc841b716cfb
struct TrackObj{T} <: Tracker
	objectives::Vector{T}
	TrackObj(T::Type=Float32) = new{T}([])
end

# ╔═╡ 3d873be9-796c-487d-b1ba-5b35455656f1
track!(::NoTracking, loss_acc) = nothing

# ╔═╡ c3ca3de8-7af9-48f7-9311-25d5ac8f39c3
track!(tracker::TrackObj, loss_acc) = push!(tracker.objectives, loss_acc)

# ╔═╡ 703ef56f-1045-4572-ae2a-170a48945e84
function RSO(train_loader, test_loader, C,model, batch_size, device, args)
	"""
	model = convolutional model structure
	C = Number of rounds to update parameters (epochs)
	batch_size = size of the mini batch that will be used to calculate loss
	device = CPU or GPU
	"""

	# Evaluate initial weight
	test_loss, test_acc = loss_and_accuracy(test_loader, model, device)
	println("Initial Weight:")
	println("   test_loss = $test_loss, test_accuracy = $test_acc")

	random_batch = []
	for (x, l) in train_loader
		push!(random_batch, (x,l))
	end
	
	# Initialize weights
	std_prep = []
	σ_d = Float64[]
	D = 0
	for layer in model
		D += 1
		Wd = Flux.params(layer)
		# Initialize the weights of the network with Gaussian distribution
		for id in Wd
			if typeof(id) == Array{Float32, 4}
				wj = convert(Array{Float32, 4}, rand(Normal(0, sqrt(2/length(id))), size(id)))
			elseif typeof(id) == Vector{Float32}
				wj = convert(Vector{Float32}, rand(Normal(0, sqrt(2/length(id))), length(id)))
			elseif typeof(id) == Matrix{Float32}
				wj = convert(Matrix{Float32}, rand(Normal(0, sqrt(2/length(id))), size(id)))
			end
			id = wj
			append!(std_prep, vec(wj))
		end
		# Compute std of all elements in the weight tensor Wd
		push!(σ_d, std(std_prep))
	end

	# Weight update
	for c in 1:C
		d = D
		# First update the weights of the layer closest to the labels 
		# and then sequentially move closer to the input
		while d > 0
			Wd = Flux.params(model[d])
			for id in Wd
				# Randomly sample change in weights from Gaussian distribution
				for j in 1:length(id)
					# Randomly sample mini-batch
					(x, y) = rand(random_batch, 1)[1]
					x, y = device(x), device(y)
					
					# Sample a weight from normal distribution
					ΔWj = rand(Normal(0, σ_d[d]), 1)[1]

					# Weight update with three scenario
					## F(x,l, W+ΔWj)
					id[j] = id[j]+ΔWj
					ŷ = model(x)
					ls_pos = logitcrossentropy(ŷ, y, agg=sum) / size(x)[end]

					## F(x,l,W)
					id[j] = id[j]-ΔWj
					ŷ = model(x)
					ls_org = logitcrossentropy(ŷ, y, agg=sum) / size(x)[end]

					## F(x,l, W-ΔWj)
					id[j] = id[j]-ΔWj
					ŷ = model(x)
					ls_neg = logitcrossentropy(ŷ, y, agg=sum) / size(x)[end]

					# Check weight update that gives minimum loss
					min_loss = argmin([ls_org, ls_pos, ls_neg])

					# Save weight update with minimum loss
					if min_loss == 1
						id[j] = id[j] + ΔWj
					elseif min_loss == 2
						id[j] = id[j] + 2*ΔWj
					elseif min_loss == 3
						id[j] = id[j]
					end
		
				end
			end
			d -= 1
		end

		train_loss, train_acc = loss_and_accuracy(train_loader, model, device)
		test_loss, test_acc = loss_and_accuracy(test_loader, model, device)

		track!(args.tracker, test_acc)

		println("RSO Round=$c")
		println("   train_loss = $train_loss, train_accuracy = $train_acc")
		println("   test_loss = $test_loss, test_accuracy = $test_acc")
	
	end
	
	return Flux.params(model)
end

# ╔═╡ 3ca0aed1-1d31-41c7-80b8-cfb3ce79d1f5
function train(; kws...)
	args = Args(; kws...) # collect options in a stuct for convinience

	# Choose device
	## WARNING: GPU not tested
	if CUDA.functional() && args.use_cuda
		@info "Training on CUDA GPU"
		CUDA.allowscalar(false)
		device = gpu
	else
		@info "Training on CPU"
		device = cpu
	end

	# Prepare datasets
	train_loader, test_loader = getdata(args, device)
	
	# Construct model
	if args.model == "original"
		model = original_model() |> device
	elseif args.model == "TwoConv"
		model = TwoConv_model() |> device
	elseif args.model == "OneConv"
		model = OneConv_model() |> device
	end
	
	ps = Flux.params(model) # model's trainable parameters

	best_param = ps
	
	## Training
	if args.optimiser == "SGD"
		## Optimizer
		opt = Descent(args.ŋ)
		
		best_loss = 10
		best_acc = 0
		for epoch in 1:args.epochs
			for (x, y) in train_loader
				x, y = device(x), device(y) # transfer data to device
				# compute gradient
				gs = gradient(() -> logitcrossentropy(model(x), y), ps) 
				Flux.Optimise.update!(opt, ps, gs) # update parameters
			end
	
			# Report on train and test
			train_loss, train_acc = loss_and_accuracy(train_loader, model, device)
			test_loss, test_acc = loss_and_accuracy(test_loader, model, device)

			# track accuracy of the model
			track!(args.tracker, test_acc)

			# Save the best model
			if test_loss < best_loss
				best_param = ps
				best_loss = test_loss
				best_acc = test_acc
			end
			
			println("Epoch=$epoch")
			println("   train_loss = $train_loss, train_accuracy = $train_acc")
			println("   test_loss = $test_loss, test_accuracy = $test_acc")
		end


	elseif args.optimiser == "RSO"
		# Run RSO function and update ps
		best_param = RSO(train_loader, test_loader, args.epochs, model,
						args.batchsize, device, args)
		best_loss, best_acc = loss_and_accuracy(test_loader, model, device)
	end
	

	println("Best test loss = $best_loss, Best test accuracy = $best_acc")
end

# ╔═╡ 184ac4ea-4d5b-4041-b37e-7f9fc154d863
begin
	acc_tracker_SGD = TrackObj(Float32)
	train(epochs=10, tracker=acc_tracker_SGD, batchsize=32)
end

# ╔═╡ 2edab904-37a6-4c2e-949d-d0868e36b688
begin
	acc_tracker_RSO = TrackObj(Float32)
	train(epochs=10, optimiser="RSO", tracker=acc_tracker_RSO, batchsize=32)
end

# ╔═╡ 59398ae6-5c42-4fbf-a2b9-3c33e9b2a246
begin
	combine = hcat(acc_tracker_SGD.objectives, acc_tracker_RSO.objectives)
	
	plot(combine, title="RSO vs. SGD", label=["SGD_MNIST" "RSO_MNIST"], xlabel="epochs", ylabel="Accuracy", lw=2, legend=:bottomright)
end

# ╔═╡ fde5a843-5767-4fc7-a381-eb2ecc1fe801
begin
	myblue = "#304da5"
	mygreen = "#2a9d8f"
	myyellow = "#e9c46a"
	myorange = "#f4a261"
	myred = "#e76f51"
	myblack = "#50514F"

	mycolors = [myblue, myred, mygreen, myorange, myyellow]
end;

# ╔═╡ 39f1690d-3003-45be-94a8-aa5c025594e5
md"## 4. Unit test"

# ╔═╡ 1cd39002-70c6-4bb8-a05a-96ff3416e654
@testset "Unit test" begin
	args = Args(;)
	train_loader, test_loader = getdata(args, cpu)
	model = OneConv_model() |> cpu

	@test typeof(MNIST.traindata(Float32, 1)) == Tuple{Matrix{Float32}, Int64}
	@test [getdata(args, cpu)] != []
	@test typeof(loss_and_accuracy(train_loader, model, cpu)) == Tuple{Float32, Float64}

end

# ╔═╡ 8e79b955-7d69-4974-aa93-fdcb8498c4bf


# ╔═╡ e3e29321-c698-407b-9f59-ec1ac30c5f87
md"## References
[1] Tripathi, R., & Singh, B. (2020). RSO: A Gradient Free Sampling Based Approach For Training Deep Neural Networks. arXiv preprint arXiv:2005.05955. [Link to paper](https://arxiv.org/abs/2005.05955)

[2] [FluxML/model-zoo/vision/mlp\_mnist/mlp\_mnist.jl](https://github.com/FluxML/model-zoo/blob/master/vision/mlp_mnist/mlp_mnist.jl)

[3] J. Frankle, D. J. Schwab, and A. S. Morcos. Training batchnorm and only batchnorm: On the expressive
power of random features in cnns. arXiv preprint arXiv:2003.00152, 2020."

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CUDA = "052768ef-5323-5732-b1bb-66c8b64840ba"
Combinatorics = "861a8166-3701-5b0c-9a16-15d98fcdc6aa"
Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
Flux = "587475ba-b771-5e3f-ad9e-33799f191a9c"
MLDatasets = "eb30cadb-4394-5ae3-aed4-317e484a6458"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[compat]
CUDA = "~3.7.0"
Combinatorics = "~1.0.2"
Distributions = "~0.25.41"
Flux = "~0.12.8"
MLDatasets = "~0.5.14"
Plots = "~1.25.6"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[AbstractFFTs]]
deps = ["ChainRulesCore", "LinearAlgebra"]
git-tree-sha1 = "6f1d9bc1c08f9f4a8fa92e3ea3cb50153a1b40d4"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.1.0"

[[AbstractTrees]]
git-tree-sha1 = "03e0550477d86222521d254b741d470ba17ea0b5"
uuid = "1520ce14-60c1-5f80-bbc7-55ef81b5835c"
version = "0.3.4"

[[Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "af92965fb30777147966f58acb05da51c5616b5f"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.3"

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[ArrayInterface]]
deps = ["Compat", "IfElse", "LinearAlgebra", "Requires", "SparseArrays", "Static"]
git-tree-sha1 = "1ee88c4c76caa995a885dc2f22a5d548dfbbc0ba"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "3.2.2"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[BFloat16s]]
deps = ["LinearAlgebra", "Printf", "Random", "Test"]
git-tree-sha1 = "a598ecb0d717092b5539dbbe890c98bac842b072"
uuid = "ab4f0b2a-ad5b-11e8-123f-65d77653426b"
version = "0.2.0"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[BinDeps]]
deps = ["Libdl", "Pkg", "SHA", "URIParser", "Unicode"]
git-tree-sha1 = "1289b57e8cf019aede076edab0587eb9644175bd"
uuid = "9e28174c-4ba2-5203-b857-d8d62c4213ee"
version = "1.0.2"

[[BinaryProvider]]
deps = ["Libdl", "Logging", "SHA"]
git-tree-sha1 = "ecdec412a9abc8db54c0efc5548c64dfce072058"
uuid = "b99e7846-7c00-51b0-8f62-c81ae34c0232"
version = "0.5.10"

[[Blosc]]
deps = ["Blosc_jll"]
git-tree-sha1 = "575bdd70552dd9a7eaeba08ef2533226cdc50779"
uuid = "a74b3585-a348-5f62-a45c-50e91977d574"
version = "0.7.2"

[[Blosc_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Lz4_jll", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "91d6baa911283650df649d0aea7c28639273ae7b"
uuid = "0b7ba130-8d10-5ba8-a3d6-c5182647fed9"
version = "1.21.1+0"

[[BufferedStreams]]
deps = ["Compat", "Test"]
git-tree-sha1 = "5d55b9486590fdda5905c275bb21ce1f0754020f"
uuid = "e1450e63-4bb3-523b-b2a4-4ffa8c0fd77d"
version = "1.0.0"

[[Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[CEnum]]
git-tree-sha1 = "215a9aa4a1f23fbd05b92769fdd62559488d70e9"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.1"

[[CUDA]]
deps = ["AbstractFFTs", "Adapt", "BFloat16s", "CEnum", "CompilerSupportLibraries_jll", "ExprTools", "GPUArrays", "GPUCompiler", "LLVM", "LazyArtifacts", "Libdl", "LinearAlgebra", "Logging", "Printf", "Random", "Random123", "RandomNumbers", "Reexport", "Requires", "SparseArrays", "SpecialFunctions", "TimerOutputs"]
git-tree-sha1 = "e2d995efe0e223773a74778ce539e60025b09e52"
uuid = "052768ef-5323-5732-b1bb-66c8b64840ba"
version = "3.7.0"

[[Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4b859a208b2397a7a623a03449e4636bdb17bcf2"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+1"

[[ChainRules]]
deps = ["ChainRulesCore", "Compat", "IrrationalConstants", "LinearAlgebra", "Random", "RealDot", "Statistics"]
git-tree-sha1 = "e659ddd9b3d67b236c750805e0176217f26d70a9"
uuid = "082447d4-558c-5d27-93f4-14fc19e9eca2"
version = "1.23.0"

[[ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "54fc4400de6e5c3e27be6047da2ef6ba355511f8"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.11.6"

[[ChangesOfVariables]]
deps = ["ChainRulesCore", "LinearAlgebra", "Test"]
git-tree-sha1 = "bf98fa45a0a4cee295de98d4c1462be26345b9a1"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.2"

[[CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "ded953804d019afa9a3f98981d99b33e3db7b6da"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.0"

[[ColorSchemes]]
deps = ["ColorTypes", "Colors", "FixedPointNumbers", "Random"]
git-tree-sha1 = "6b6f04f93710c71550ec7e16b650c1b9a612d0b6"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.16.0"

[[ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[Combinatorics]]
git-tree-sha1 = "08c8b6831dc00bfea825826be0bc8336fc369860"
uuid = "861a8166-3701-5b0c-9a16-15d98fcdc6aa"
version = "1.0.2"

[[CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "44c37b4636bc54afac5c574d2d02b625349d6582"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.41.0"

[[CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[DataDeps]]
deps = ["BinaryProvider", "HTTP", "Libdl", "Reexport", "SHA", "p7zip_jll"]
git-tree-sha1 = "4f0e41ff461d42cfc62ff0de4f1cd44c6e6b3771"
uuid = "124859b0-ceae-595e-8997-d05f6a7a8dfe"
version = "0.7.7"

[[DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "3daef5523dd2e769dad2365274f760ff5f282c7d"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.11"

[[DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[DensityInterface]]
deps = ["InverseFunctions", "Test"]
git-tree-sha1 = "80c3e8639e3353e5d2912fb3a1916b8455e2494b"
uuid = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
version = "0.4.0"

[[DiffResults]]
deps = ["StaticArrays"]
git-tree-sha1 = "c18e98cba888c6c25d1c3b048e4b3380ca956805"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.0.3"

[[DiffRules]]
deps = ["LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "9bc5dac3c8b6706b58ad5ce24cffd9861f07c94f"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.9.0"

[[Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[Distributions]]
deps = ["ChainRulesCore", "DensityInterface", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Test"]
git-tree-sha1 = "5863b0b10512ed4add2b5ec07e335dc6121065a5"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.41"

[[DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "b19534d1895d702889b219c382a6e18010797f0b"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.6"

[[Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3f3a2501fa7236e9b911e0f7a588c657e822bb6d"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.3+0"

[[Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b3bfd02e98aedfa5cf885665493c5598c350cd2f"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.2.10+0"

[[ExprTools]]
git-tree-sha1 = "56559bbef6ca5ea0c0818fa5c90320398a6fbf8d"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.8"

[[FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "Pkg", "Zlib_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "d8a578692e3077ac998b50c0217dfd67f21d1e5f"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.0+0"

[[FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "8756f9935b7ccc9064c6eef0bff0ad643df733a3"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.12.7"

[[FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[Flux]]
deps = ["AbstractTrees", "Adapt", "ArrayInterface", "CUDA", "CodecZlib", "Colors", "DelimitedFiles", "Functors", "Juno", "LinearAlgebra", "MacroTools", "NNlib", "NNlibCUDA", "Pkg", "Printf", "Random", "Reexport", "SHA", "SparseArrays", "Statistics", "StatsBase", "Test", "ZipFile", "Zygote"]
git-tree-sha1 = "e8b37bb43c01eed0418821d1f9d20eca5ba6ab21"
uuid = "587475ba-b771-5e3f-ad9e-33799f191a9c"
version = "0.12.8"

[[Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "1bd6fc0c344fc0cbee1f42f8d2e7ec8253dda2d2"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.25"

[[FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[Functors]]
git-tree-sha1 = "e4768c3b7f597d5a352afa09874d16e3c3f6ead2"
uuid = "d9f16b24-f501-4c13-a1f2-28368ffc5196"
version = "0.2.7"

[[GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "0c603255764a1fa0b61752d2bec14cfbd18f7fe8"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.5+1"

[[GPUArrays]]
deps = ["Adapt", "LinearAlgebra", "Printf", "Random", "Serialization", "Statistics"]
git-tree-sha1 = "d9681e61fbce7dde48684b40bdb1a319c4083be7"
uuid = "0c68f7d7-f131-5f86-a1c3-88cf8149b2d7"
version = "8.1.3"

[[GPUCompiler]]
deps = ["ExprTools", "InteractiveUtils", "LLVM", "Libdl", "Logging", "TimerOutputs", "UUIDs"]
git-tree-sha1 = "abd824e1f2ecd18d33811629c781441e94a24e81"
uuid = "61eb1bfa-7361-4325-ad38-22787b887f55"
version = "0.13.11"

[[GR]]
deps = ["Base64", "DelimitedFiles", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Printf", "Random", "RelocatableFolders", "Serialization", "Sockets", "Test", "UUIDs"]
git-tree-sha1 = "4a740db447aae0fbeb3ee730de1afbb14ac798a1"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.63.1"

[[GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "aa22e1ee9e722f1da183eb33370df4c1aeb6c2cd"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.63.1+0"

[[GZip]]
deps = ["Libdl"]
git-tree-sha1 = "039be665faf0b8ae36e089cd694233f5dee3f7d6"
uuid = "92fee26a-97fe-5a0c-ad85-20a5f3185b63"
version = "0.5.1"

[[GeometryBasics]]
deps = ["EarCut_jll", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "58bcdf5ebc057b085e58d95c138725628dd7453c"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.1"

[[Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "a32d672ac2c967f3deb8a81d828afc739c838a06"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.68.3+2"

[[Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[HDF5]]
deps = ["Blosc", "Compat", "HDF5_jll", "Libdl", "Mmap", "Random", "Requires"]
git-tree-sha1 = "698c099c6613d7b7f151832868728f426abe698b"
uuid = "f67ccb44-e63f-5c2f-98bd-6dc0ccc4ba2f"
version = "0.15.7"

[[HDF5_jll]]
deps = ["Artifacts", "JLLWrappers", "LibCURL_jll", "Libdl", "OpenSSL_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "bab67c0d1c4662d2c4be8c6007751b0b6111de5c"
uuid = "0234f1f7-429e-5d53-9886-15a909be8d59"
version = "1.12.1+0"

[[HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "0fa77022fe4b511826b39c894c90daf5fce3334a"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.17"

[[HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[IRTools]]
deps = ["InteractiveUtils", "MacroTools", "Test"]
git-tree-sha1 = "006127162a51f0effbdfaab5ac0c83f8eb7ea8f3"
uuid = "7869d1d1-7146-5819-86e3-90919afe41df"
version = "0.4.4"

[[IfElse]]
git-tree-sha1 = "debdd00ffef04665ccbb3e150747a77560e8fad1"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.1"

[[IniFile]]
deps = ["Test"]
git-tree-sha1 = "098e4d2c533924c921f9f9847274f2ad89e018b8"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.0"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[InternedStrings]]
deps = ["Random", "Test"]
git-tree-sha1 = "eb05b5625bc5d821b8075a77e4c421933e20c76b"
uuid = "7d512f48-7fb1-5a58-b986-67e6dc259f01"
version = "0.7.0"

[[InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "a7254c0acd8e62f1ac75ad24d5db43f5f19f3c65"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.2"

[[IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[IterTools]]
git-tree-sha1 = "fa6287a4469f5e048d763df38279ee729fbd44e5"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.4.0"

[[IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "22df5b96feef82434b07327e2d3c770a9b21e023"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.0"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "8076680b162ada2a031f707ac7b4953e30667a37"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.2"

[[JSON3]]
deps = ["Dates", "Mmap", "Parsers", "StructTypes", "UUIDs"]
git-tree-sha1 = "7d58534ffb62cd947950b3aa9b993e63307a6125"
uuid = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
version = "1.9.2"

[[JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d735490ac75c5cb9f1b00d8b5509c11984dc6943"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.0+0"

[[Juno]]
deps = ["Base64", "Logging", "Media", "Profile"]
git-tree-sha1 = "07cb43290a840908a771552911a6274bc6c072c7"
uuid = "e5e0dc1b-0480-54bc-9374-aad01c23163d"
version = "0.8.4"

[[LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[LLVM]]
deps = ["CEnum", "LLVMExtra_jll", "Libdl", "Printf", "Unicode"]
git-tree-sha1 = "f8dcd7adfda0dddaf944e62476d823164cccc217"
uuid = "929cbde3-209d-540e-8aea-75f648917ca0"
version = "4.7.1"

[[LLVMExtra_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "62115afed394c016c2d3096c5b85c407b48be96b"
uuid = "dad2f222-ce93-54a1-a47d-0025e8a3acab"
version = "0.0.13+1"

[[LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "Printf", "Requires"]
git-tree-sha1 = "a8f4f279b6fa3c3c4f1adadd78a621b13a506bce"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.9"

[[LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "7739f837d6447403596a75d19ed01fd08d6f56bf"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.3.0+3"

[[Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "42b62845d70a619f063a7da093d995ec8e15e778"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+1"

[[Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "340e257aada13f95f98ee352d316c3bed37c8ab9"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.3.0+0"

[[Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[LinearAlgebra]]
deps = ["Libdl"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "e5718a00af0ab9756305a0392832c8952c7426c1"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.6"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[Lz4_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "5d494bc6e85c4c9b626ee0cab05daa4085486ab1"
uuid = "5ced341a-0733-55b8-9ab6-a4889d929147"
version = "1.9.3+0"

[[MAT]]
deps = ["BufferedStreams", "CodecZlib", "HDF5", "SparseArrays"]
git-tree-sha1 = "37d418e2f20f0fcdc78214f763f1066b74ca1e1b"
uuid = "23992714-dd62-5051-b70f-ba57cb901cac"
version = "0.10.2"

[[MLDatasets]]
deps = ["BinDeps", "ColorTypes", "DataDeps", "DelimitedFiles", "FixedPointNumbers", "GZip", "JSON3", "MAT", "Pickle", "Requires", "SparseArrays"]
git-tree-sha1 = "a456fdf6f33a9e63a8aca76ed6feb13c2999f166"
uuid = "eb30cadb-4394-5ae3-aed4-317e484a6458"
version = "0.5.14"

[[MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[Measures]]
git-tree-sha1 = "e498ddeee6f9fdb4551ce855a46f54dbd900245f"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.1"

[[Media]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "75a54abd10709c01f1b86b84ec225d26e840ed58"
uuid = "e89f7d12-3494-54d1-8411-f7d8b9ae1f27"
version = "0.5.0"

[[Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[NNlib]]
deps = ["Adapt", "ChainRulesCore", "Compat", "LinearAlgebra", "Pkg", "Requires", "Statistics"]
git-tree-sha1 = "3a8dfd0cfb5bb3b82d09949e14423409b9334acb"
uuid = "872c559c-99b0-510c-b3b7-b6c96a88d5cd"
version = "0.7.34"

[[NNlibCUDA]]
deps = ["CUDA", "LinearAlgebra", "NNlib", "Random", "Statistics"]
git-tree-sha1 = "a2dc748c9f6615197b6b97c10bcce829830574c9"
uuid = "a00861dc-f156-4864-bf3c-e6376f28a68d"
version = "0.1.11"

[[NaNMath]]
git-tree-sha1 = "f755f36b19a5116bb580de457cda0c140153f283"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.6"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"

[[OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "648107615c15d4e09f7eca16307bc821c1f718d8"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.13+0"

[[OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[PCRE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b2a7af664e098055a7529ad1a900ded962bca488"
uuid = "2f80f16e-611a-54ab-bc61-aa92de5b98fc"
version = "8.44.0+0"

[[PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "ee26b350276c51697c9c2d88a072b339f9f03d73"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.5"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "92f91ba9e5941fc781fecf5494ac1da87bdac775"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.2.0"

[[Pickle]]
deps = ["DataStructures", "InternedStrings", "Serialization", "SparseArrays", "Strided", "ZipFile"]
git-tree-sha1 = "b4054944f1bfb956fb38fb54ee760e33c5507d35"
uuid = "fbb45041-c46e-462f-888f-7c521cafbc2c"
version = "0.2.10"

[[Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[PlotThemes]]
deps = ["PlotUtils", "Requires", "Statistics"]
git-tree-sha1 = "a3a964ce9dc7898193536002a6dd892b1b5a6f1d"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "2.0.1"

[[PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "6f1b25e8ea06279b5689263cc538f51331d7ca17"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.1.3"

[[Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "GeometryBasics", "JSON", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "PlotThemes", "PlotUtils", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs", "UnicodeFun", "Unzip"]
git-tree-sha1 = "db7393a80d0e5bef70f2b518990835541917a544"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.25.6"

[[Preferences]]
deps = ["TOML"]
git-tree-sha1 = "2cf929d64681236a2e074ffafb8d568733d2e6af"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.3"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[Profile]]
deps = ["Printf"]
uuid = "9abbd945-dff8-562f-b5e8-e1ebf5ef1b79"

[[Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "ad368663a5e20dbb8d6dc2fddeefe4dae0781ae8"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+0"

[[QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "78aadffb3efd2155af139781b8a8df1ef279ea39"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.4.2"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[Random123]]
deps = ["Libdl", "Random", "RandomNumbers"]
git-tree-sha1 = "0e8b146557ad1c6deb1367655e052276690e71a3"
uuid = "74087812-796a-5b5d-8853-05524746bad3"
version = "1.4.2"

[[RandomNumbers]]
deps = ["Random", "Requires"]
git-tree-sha1 = "043da614cc7e95c703498a491e2c21f58a2b8111"
uuid = "e6cf234a-135c-5ec9-84dd-332b85af5143"
version = "1.5.3"

[[RealDot]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "9f0a1b71baaf7650f4fa8a1d168c7fb6ee41f0c9"
uuid = "c1ae055f-0cd5-4b69-90a6-9a35b1a98df9"
version = "0.1.0"

[[RecipesBase]]
git-tree-sha1 = "6bf3f380ff52ce0832ddd3a2a7b9538ed1bcca7d"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.2.1"

[[RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase"]
git-tree-sha1 = "37c1631cb3cc36a535105e6d5557864c82cd8c2b"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.5.0"

[[Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "cdbd3b1338c72ce29d9584fdbe9e9b70eeb5adca"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "0.1.3"

[[Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "bf3188feca147ce108c76ad82c2792c57abe7b1f"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.0"

[[Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "68db32dff12bb6127bac73c209881191bf0efbb7"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.3.0+0"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[Scratch]]
deps = ["Dates"]
git-tree-sha1 = "0b4b7f1393cff97c33891da2a0bf69c6ed241fda"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.0"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "e08890d19787ec25029113e88c34ec20cac1c91e"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.0.0"

[[Static]]
deps = ["IfElse"]
git-tree-sha1 = "7f5a513baec6f122401abfc8e9c074fdac54f6c1"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "0.4.1"

[[StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "2884859916598f974858ff01df7dfc6c708dd895"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.3.3"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[StatsAPI]]
git-tree-sha1 = "d88665adc9bcf45903013af0982e2fd05ae3d0a6"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.2.0"

[[StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "51383f2d367eb3b444c961d485c565e4c0cf4ba0"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.14"

[[StatsFuns]]
deps = ["ChainRulesCore", "InverseFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "bedb3e17cc1d94ce0e6e66d3afa47157978ba404"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "0.9.14"

[[Strided]]
deps = ["LinearAlgebra", "TupleTools"]
git-tree-sha1 = "4d581938087ca90eab9bd4bb6d270edaefd70dcd"
uuid = "5e0ebb24-38b0-5f93-81fe-25c709ecae67"
version = "1.1.2"

[[StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArrays", "Tables"]
git-tree-sha1 = "d21f2c564b21a202f4677c0fba5b5ee431058544"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.4"

[[StructTypes]]
deps = ["Dates", "UUIDs"]
git-tree-sha1 = "d24a825a95a6d98c385001212dc9020d609f2d4f"
uuid = "856f2bd8-1eba-4b0a-8007-ebc267875bd4"
version = "1.8.1"

[[SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "TableTraits", "Test"]
git-tree-sha1 = "bb1064c9a84c52e277f1096cf41434b675cd368b"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.6.1"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[TimerOutputs]]
deps = ["ExprTools", "Printf"]
git-tree-sha1 = "97e999be94a7147d0609d0b9fc9feca4bf24d76b"
uuid = "a759f4b9-e2f1-59dc-863e-4aeb61b1ea8f"
version = "0.5.15"

[[TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "216b95ea110b5972db65aa90f88d8d89dcb8851c"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.6"

[[TupleTools]]
git-tree-sha1 = "3c712976c47707ff893cf6ba4354aa14db1d8938"
uuid = "9d95972d-f1c8-5527-a6e0-b4b365fa01f6"
version = "1.3.0"

[[URIParser]]
deps = ["Unicode"]
git-tree-sha1 = "53a9f49546b8d2dd2e688d216421d050c9a31d0d"
uuid = "30578b45-9adc-5946-b283-645ec420af67"
version = "0.4.1"

[[URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[Unzip]]
git-tree-sha1 = "34db80951901073501137bdbc3d5a8e7bbd06670"
uuid = "41fe7b60-77ed-43a1-b4f0-825fd5a5650d"
version = "0.1.2"

[[Wayland_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "3e61f0b86f90dacb0bc0e73a0c5a83f6a8636e23"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.19.0+0"

[[Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "66d72dc6fcc86352f01676e8f0f698562e60510f"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.23.0+0"

[[XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "1acf5bdf07aa0907e0a37d3718bb88d4b687b74a"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.12+0"

[[XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[ZipFile]]
deps = ["Libdl", "Printf", "Zlib_jll"]
git-tree-sha1 = "3593e69e469d2111389a9bd06bac1f3d730ac6de"
uuid = "a5390f91-8eb1-5f08-bee0-b1d1ffed6cea"
version = "0.9.4"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "cc4bf3fdde8b7e3e9fa0351bdeedba1cf3b7f6e6"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.0+0"

[[Zygote]]
deps = ["AbstractFFTs", "ChainRules", "ChainRulesCore", "DiffRules", "Distributed", "FillArrays", "ForwardDiff", "IRTools", "InteractiveUtils", "LinearAlgebra", "MacroTools", "NaNMath", "Random", "Requires", "SpecialFunctions", "Statistics", "ZygoteRules"]
git-tree-sha1 = "88a4d79f4e389456d5a90d79d53d1738860ef0a5"
uuid = "e88e6eb3-aa80-5325-afca-941959d7151f"
version = "0.6.34"

[[ZygoteRules]]
deps = ["MacroTools"]
git-tree-sha1 = "8c1a8e4dfacb1fd631745552c8db35d0deb09ea0"
uuid = "700de1a5-db45-46bc-99cf-38207098b444"
version = "0.2.2"

[[libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "b910cb81ef3fe6e78bf6acee440bda86fd6ae00c"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+1"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"

[[x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "ece2350174195bb31de1a63bea3a41ae1aa593b6"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "0.9.1+5"
"""

# ╔═╡ Cell order:
# ╟─936344da-213a-11ec-3e68-05f0f85cf2f3
# ╟─8c3625c6-4537-4a32-9a8d-ea33cf5ee7df
# ╠═0150a3e2-f98e-4412-9e96-1a2db5a9421e
# ╠═352a4a75-8136-474e-a80a-9d65baabd195
# ╠═79d4c2f0-bc6e-43f1-b877-a63226f8aadc
# ╠═de52e90b-cdee-4221-b502-8a4d128bcc79
# ╠═261dd1eb-3158-4c20-aec7-01c4dfeab897
# ╠═4372356d-92f6-45f0-97c0-f28b2299a5a8
# ╟─62c4926d-0350-4088-8729-0ee5afb306be
# ╟─98e7978d-2355-407c-b87f-c0bd64b430aa
# ╟─8cd1b08a-644e-4cdb-87ab-6f7270a29681
# ╟─9bb4e28e-dd24-451c-9e95-205ba2e084ef
# ╟─198f91c6-46dc-46dc-a013-c3064a7348cd
# ╟─5e51a853-8736-4f92-b7f4-216ff4ab0b90
# ╟─bc0e3c51-16e1-47d1-8372-268debce32fa
# ╠═703ef56f-1045-4572-ae2a-170a48945e84
# ╟─75f178d4-85d5-4591-89f7-a4e359a04f0b
# ╟─11872972-0526-4c07-902b-0b8f3ac0553f
# ╠═72482d89-c3f1-479c-b06c-da73259f68b0
# ╟─5b844fba-dae3-4945-a57e-d76caf8ee0df
# ╠═184ac4ea-4d5b-4041-b37e-7f9fc154d863
# ╟─0f00bfef-32fe-489d-93e7-669c89af6eff
# ╠═2edab904-37a6-4c2e-949d-d0868e36b688
# ╟─94c436d1-d4c1-4eb1-8940-e8b12e608b30
# ╟─82f5a6d7-c15d-4350-b5fd-8aaa16229740
# ╟─27df401a-709d-4c73-bd4c-5333572ab233
# ╟─59398ae6-5c42-4fbf-a2b9-3c33e9b2a246
# ╟─0082e604-f8bf-4e89-a3b3-f168c6e04efa
# ╟─6d9fa03d-cd79-416a-b686-d244afdba854
# ╟─5afd91f6-9e0d-4774-a954-3f00b71dd2e7
# ╟─f7c0cb4b-c98a-404d-96f6-7a20f167d11d
# ╠═f6a38e02-f53f-440d-934b-4ed1f00d1827
# ╟─85f193d7-7382-445d-8213-870aba58af71
# ╠═965d6f22-5522-416f-ab1e-e66623262e90
# ╠═399f02e7-81ef-4f06-9df3-a3857532654a
# ╠═f8d655ea-db55-4fd5-b324-25987b9d200d
# ╟─f51a102a-bb79-47b5-b1dd-d04992bf2ba0
# ╠═0d7b525d-3f30-44fc-b771-1665d3f2e045
# ╟─28a8be56-c56b-49db-b57d-0a676d7f7f47
# ╠═3ca0aed1-1d31-41c7-80b8-cfb3ce79d1f5
# ╟─796aa432-e28f-4243-92c0-934f4e4f022f
# ╠═f622af0a-033b-48c5-aedb-e86926b731a4
# ╠═86ced829-524f-4948-9df9-6812762c8fa3
# ╠═07e1abb3-dcf9-4632-bf07-ce128296dfd5
# ╠═08eb9335-3ba7-4f18-bd7f-dc841b716cfb
# ╠═3d873be9-796c-487d-b1ba-5b35455656f1
# ╠═c3ca3de8-7af9-48f7-9311-25d5ac8f39c3
# ╟─fde5a843-5767-4fc7-a381-eb2ecc1fe801
# ╟─39f1690d-3003-45be-94a8-aa5c025594e5
# ╟─1cd39002-70c6-4bb8-a05a-96ff3416e654
# ╟─8e79b955-7d69-4974-aa93-fdcb8498c4bf
# ╟─e3e29321-c698-407b-9f59-ec1ac30c5f87
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
