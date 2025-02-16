-include .env

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

test :; forge test 

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast
SEPOLIA_NETWORK_ARGS := --rpc-url ${SEPOLIA_RPC_URL} --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

deploy:
	@forge script script/NFTdeploy.s.sol:NFTdeploy $(NETWORK_ARGS)

deploy-sepolia:
	@forge script script/NFTdeploy.s.sol:NFTdeploy $(SEPOLIA_NETWORK_ARGS)